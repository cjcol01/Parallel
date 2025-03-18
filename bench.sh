#!/bin/bash

# Configuration
EXECUTABLE="./cwk2"  # Your executable
RUNS_PER_TEST=10     # Number of runs for each configuration
PROCESS_COUNTS=(1 2 4 8 16 32)  # Process counts to test

# Check if executable exists
if [ ! -f "$EXECUTABLE" ]; then
    echo "Error: Executable '$EXECUTABLE' not found."
    echo "Make sure you've compiled your program first."
    exit 1
fi

# Print header
echo "===== MPI Performance Test Results ====="
echo "Running each test $RUNS_PER_TEST times and calculating average"
echo ""
echo "Process Count | Average Time (s) | Standard Deviation | Speedup"
echo "-------------|------------------|-------------------|--------"

# Store results for speedup calculation
SEQ_TIME=0

# Loop through each process count
for np in "${PROCESS_COUNTS[@]}"; do
    echo -n "Testing with $np processes... "
    
    # Arrays to store results
    times=()
    
    # Run the program multiple times
    for (( i=1; i<=$RUNS_PER_TEST; i++ )); do
        # Create temporary file for output
        output_file=$(mktemp)
        
        # Run the program and capture output
        mpirun --oversubscribe -n $np $EXECUTABLE > "$output_file" 2>&1
        
        # Extract timing information
        time_value=$(grep "Total time taken:" "$output_file" | awk '{print $4}')
        
        # Skip if empty or invalid
        if [[ -n "$time_value" && "$time_value" != "0" ]]; then
            times+=($time_value)
            echo -n "."
        else
            echo -n "x"  # Indicate error or zero timing
        fi
        
        # Clean up
        rm "$output_file"
    done
    
    echo " Done."
    
    # Calculate statistics if we have valid timings
    if [ ${#times[@]} -gt 0 ]; then
        # Calculate sum
        sum=0
        for t in "${times[@]}"; do
            sum=$(echo "$sum + $t" | bc -l)
        done
        
        # Calculate average
        avg=$(echo "scale=6; $sum / ${#times[@]}" | bc -l)
        
        # Calculate standard deviation
        if [ ${#times[@]} -gt 1 ]; then
            sum_squared_diff=0
            for t in "${times[@]}"; do
                diff=$(echo "$t - $avg" | bc -l)
                squared_diff=$(echo "$diff * $diff" | bc -l)
                sum_squared_diff=$(echo "$sum_squared_diff + $squared_diff" | bc -l)
            done
            variance=$(echo "scale=6; $sum_squared_diff / (${#times[@]} - 1)" | bc -l)
            stddev=$(echo "scale=6; sqrt($variance)" | bc -l)
        else
            stddev="N/A"
        fi
        
        # Store sequential time for speedup calculation
        if [ $np -eq 1 ]; then
            SEQ_TIME=$avg
            speedup="1.00"
        else
            # Calculate speedup
            speedup=$(echo "scale=2; $SEQ_TIME / $avg" | bc -l)
        fi
        
        # Format output
        printf "%-13s | %-17s | %-19s | %-7s\n" "$np" "$avg" "$stddev" "$speedup"
    else
        printf "%-13s | %-17s | %-19s | %-7s\n" "$np" "No valid data" "N/A" "N/A"
    fi
done

echo ""
echo "===== Raw Data for Report ====="
echo "Copy the following table into your readme.txt:"
echo ""

# Print raw data for report
echo "| Number of processes | Time (s) | Speedup | Efficiency |"
echo "|--------------------|----------|---------|------------|"

for np in "${PROCESS_COUNTS[@]}"; do
    # Find the average time for this process count
    found=false
    
    # Create temporary file for re-running if needed
    output_file=$(mktemp)
    
    # Run once more to ensure we have data
    mpirun --oversubscribe -n $np $EXECUTABLE > "$output_file" 2>&1
    time_value=$(grep "Total time taken:" "$output_file" | awk '{print $4}')
    
    if [[ -n "$time_value" && "$time_value" != "0" ]]; then
        found=true
        avg_time=$time_value
    fi
    
    rm "$output_file"
    
    # If we still don't have data, try one more approach
    if [ "$found" = false ]; then
        # Run with timing command
        time_output=$(mktemp)
        { time mpirun --oversubscribe -n $np $EXECUTABLE > /dev/null; } 2> "$time_output"
        
        # Extract real time
        real_time=$(grep "real" "$time_output" | awk '{print $2}')
        
        # Convert time format (e.g., 0m0.123s) to seconds
        if [[ -n "$real_time" ]]; then
            minutes=$(echo "$real_time" | cut -d'm' -f1)
            seconds=$(echo "$real_time" | cut -d'm' -f2 | sed 's/s//')
            avg_time=$(echo "scale=6; $minutes * 60 + $seconds" | bc -l)
            found=true
        fi
        
        rm "$time_output"
    fi
    
    # Calculate statistics
    if [ "$found" = true ]; then
        if [ $np -eq 1 ]; then
            SEQ_TIME=$avg_time
            speedup="1.00"
        else
            # Calculate speedup
            speedup=$(echo "scale=2; $SEQ_TIME / $avg_time" | bc -l)
        fi
        
        # Calculate efficiency
        efficiency=$(echo "scale=2; 100 * $speedup / $np" | bc -l)
        
        # Format for readme
        printf "| %-19d | %-8s | %-7s | %-10s |\n" $np $avg_time $speedup "${efficiency}%"
    else
        printf "| %-19d | %-8s | %-7s | %-10s |\n" $np "N/A" "N/A" "N/A"
    fi
done

echo ""
echo "Note: If timings are too small or inconsistent, consider running with a larger dataset."