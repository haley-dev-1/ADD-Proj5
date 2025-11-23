0 li x4,-1
1 li x5,2
2 beq x4,x5,target3 # not taken
3 bne x4,x5,target3 # taken
4 target1: blt x4,x5,target4 # taken
5 jal target5
6 j exit
7 target2: nop
8 target3: jal x1,target1
9 target4: jalr x1
10 target5: bge x4,x5,target1 # not taken
11 bgeu x4,x5,target6 # taken
12 beq x0,x0,target1 # not executed
13 target6: bltu x4,x4,target1 # not taken
14 exit:

// check with rars and timing
// assemble
// dump to hex

// --------------------- The below is from help from TA... lab 6 single branch instruction ------------------------------------------------------ 
// "A really simplified version of the assembly language program for a single branch instruction might look like this:"
/* 
start:
    addi s0, zero, 0 # the first operand for our branch comparison
    addi s1, zero, 2 # the second operand for our branch comparison
    addi s2, zero, 5 # the arbitrary (but unique) number we want to output before the branch
    addi s3, zero, 10 # the arbitrary number we want to output after the branch if it's not taken
    addi s4, zero, 15 # the arbitrary number we want to output if the branch is taken

    csrrw zero, f02, s2 # output our first state
    bne s0, s1, done # do the branch, this one should be taken (you should include both taken and untaken branches)
    csrrw zero, f02, s3 # this should never execute, if it does and we see it in the testbench, then the stall logic is broken

done:
    csrrw zero, f02, s4 # output our final state after the branch was 
*/    
// The ablove is from help from TA
// -----------------------------------------------------------------------------------------------------------------
