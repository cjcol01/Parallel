#
# Simple makefile for Coursework 2. Normaly you would not upload a makefile
# for this assignment, but if you do, ensure (a) the executable name is unchanged,
# and (b) it works on the Gradescope autograder.
#
EXE = cwk2
CC = mpicc
CCFLAGS = -Wall -lm -std=c99

# Default target - compile cwk2.c
all: original

# Target to compile original cwk2.c
original:
	$(CC) $(CCFLAGS) -o $(EXE) cwk2.c

# Target to compile cwk2_new.c and new.c
new:
	$(CC) $(CCFLAGS) -o $(EXE) cwk2_new.c

# Clean target to remove executable
clean:
	rm -f $(EXE)
