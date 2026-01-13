# csce611 Haley Lind
# bin2dec -> sqrt program (binary search implementation)    

# Notes (project 5)
# With no op on each line, the program will line
# Next: loop for opoprtunities to move an instructio nwith a trailing no-op into a position of a no-op of another instruction
# Doing this once eliminates 2 no-ops, allowing 2 instructions to be executed in the same cycle instead of just 1. 
# You can't move branch/jump instructions or uses a value computed by previous instruction. 

# *I'm not sure what makes instructions combinable. How do you know when to combine instructions? Something about elminiating no-ops and dependencies...*

.text
.globl main

# even: [63:32] # first in cycle
# odd:  [31:0]  # second in cycle

main:
    csrrw   x8,  0xf00, x0      # x8  = CSR[0xf00] (switch input)
    addi    x0,  x0,  0
    
    slli    x8,  x8, 14         # fixed-point scale: value << 14
    addi    x0,  x0,  0
    
    add     x10, x0,  x8        # a0 = input (for sqrt)
    addi    x0,  x0,  0

    jal     x1,  sqrt           # call sqrt
    addi    x0, x0, 0 
    
    lui     x5,  0x18           # x5 = 0x18_000 # This still gets executed after the jump b/c VLIW!!
    addi    x0,  x0,  0

    addi    x5,  x5, 1696       # x5 = 0x18_6a0 = 100000 (magic constant)
    addi    x0,  x0,  0

    mul     x6,  x10, x5        # x6 = a0 * 100000
    addi    x0,  x0,  0

    srli    x9,  x6, 14         # x9 = (a0 * 100000) >> 14
    mulhu   x18, x5,  x10       # high part of a0*100000

    slli    x18, x18, 18        # shift high part
    addi    x0,  x0,  0

    or      x8,  x18, x9        # x8 = combined fixed-point result
    addi    x0,  x0,  0

    jal     x1,  bin_to_bcd     # bin_to_bcd(x8) → x12
    addi    x0,  x0,  0

    csrrw   x0,  0xf02, x12     # write BCD to display CSR 0xf02
    addi    x0,  x0,  0

    jal     x0,  main           # j main (infinite loop)
    addi    x0,  x0,  0

# square root program below with loop to iteratively go with binary search to convert
sqrt:
    add     x8,  x0,  x10       # x8  = input value
    addi    x9,  x0,  0         # x9  = 0 (initial guess)

    addi    x18, x0,  1         # x18 = 1
    addi    x0,  x0,  0

    slli    x18, x18, 22        # x18 = 1 << 22 (initial step size)
    addi    x0,  x0,  0

sqrt_loop:
    beq     x18, x0,  sqrt_exit # if step == 0 → done
    addi    x0,  x0,  0

    add     x19, x9,  x18       # trial = guess + step
    addi    x0,  x0,  0
    
    mul     x5,  x19, x19       # low  part of trial^2
    mulhu   x6,  x19, x19       # high part of trial^2

    ############################################
    # i wonder if i can combine these: 
    slli    x7,  x8,  14        # some scaled version of input
    srli    x28, x8,  18        # another scaled version of input

    bltu    x28, x6,  sqrt_step # if x28 < high(trial^2) → don't accept trial
    addi    x0,  x0,  0

    bltu    x6,  x28, sqrt_accept
    addi    x0,  x0,  0
    #############################################
                                # else if high(trial^2) < x28 → accept trial
    bltu    x7,  x5,  sqrt_step # else if scaled input < low(trial^2) → don't accept
    addi    x0,  x0,  0

sqrt_accept:
    add     x9,  x0,  x19       # guess = trial
    addi    x0,  x0,  0

sqrt_step:
    srli    x18, x18, 1         # step >>= 1
    addi    x0,  x0,  0

    jal     x0,  sqrt_loop      # j sqrt_loop
    addi    x0,  x0,  0

sqrt_exit:
    add     x10, x0,  x9        # a0 = guess
    ret                         


# - - - - - - -- - - - -- - - - - - - - - -- - - - - -- - - -- -- - - - - - -
# bin_to_bcd: convert x8 (binary) → packed BCD in x12
# Input:  x8  = value
# Output: x12 = packed 8 BCD digits
# - - - - - - - - - - -- - - - - -- - - - - - -- - - - -- - - - - -- - - - -

bin_to_bcd:
    lui     x10, 0x1999a        # x10 = 0x1999a000
    addi    x11, x0,  10        # x11 = 10
    
    addi    x10, x10, -1638     # x10 = 0x19999999 (magic /10 constant)
    addi    x12, x0,  0         # x12 = 0 (BCD accumulator)

    # Digit 0 (no shift)
    mul     x5,  x8,  x10       # temp = x8 * magic
    mulhu   x8,  x8,  x10       # x8  = quotient ≈ x8/10

    mulhu   x5,  x5,  x11       # x5  = (temp high) * 10? (digit-ish)
    addi    x0,  x0,  0

    or      x12, x12, x5        # place digit 0
    mul x5, x8, x10             # temp1

    mulhu   x8,  x8,  x10       # Digit 1 (shift by 4)
    mulhu   x5,  x5,  x11

    slli    x5,  x5,  4         # << 4
    or      x12, x12, x5
    
    mul     x5,  x8,  x10       # Digit 2 (shift by 8)
    mulhu   x8,  x8,  x10

    mulhu   x5,  x5,  x11
    addi    x0,  x0,  0

    slli    x5,  x5,  8         # << 8
    addi    x0,  x0,  0

    or      x12, x12, x5
    mul     x5,  x8,  x10       # Digit 3 (shift by 12)

    mulhu   x8,  x8,  x10
    addi    x0,  x0,  0

    mulhu   x5,  x5,  x11
    addi    x0,  x0,  0

    slli    x5,  x5,  12        # << 12
    addi    x0,  x0,  0

    or      x12, x12, x5        # Digit 4 (shift by 16)
    mul     x5,  x8,  x10

    mulhu   x8,  x8,  x10
    addi    x0,  x0,  0

    mulhu   x5,  x5,  x11
    addi    x0,  x0,  0

    slli    x5,  x5,  16        # << 16
    addi    x0,  x0,  0

    or      x12, x12, x5    # # Digit 5 (shift by 20)
    mul     x5,  x8,  x10

    mulhu   x8,  x8,  x10
    addi    x0,  x0,  0

    mulhu   x5,  x5,  x11
    addi    x0,  x0,  0

    slli    x5,  x5,  20        # << 20
    addi    x0,  x0,  0

    or      x12, x12, x5    # Digit 6 (shift by 24)
    mul     x5,  x8,  x10

    mulhu   x8,  x8,  x10
    addi    x0,  x0,  0

    mulhu   x5,  x5,  x11
    addi    x0,  x0,  0

    slli    x5,  x5,  24        # << 24
    addi    x0,  x0,  0

    or      x12, x12, x5        
    mul     x5,  x8,  x10       # Digit 7 (shift by 28)

    mulhu   x8,  x8,  x10
    addi    x0,  x0,  0

    mulhu   x5,  x5,  x11
    addi    x0,  x0,  0

    slli    x5,  x5,  28        # << 28
    addi    x0,  x0,  0

    or      x12, x12, x5
    addi    x0,  x0,  0
    
    ret
