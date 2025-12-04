# csce611 Haley Lind Michael Stewart 
# bin2dec -> sqrt program (binary search implementation)    

.text
.globl main

main:
    csrrw   x8,  0xf00, x0      # x8  = CSR[0xf00] (switch input)
    slli    x8,  x8, 14         # fixed-point scale: value << 14
    add     x10, x0,  x8        # a0 = input (for sqrt)

    jal     x1,  sqrt           # call sqrt(a0) → a0

    lui     x5,  0x18           # x5 = 0x18_000
    addi    x5,  x5, 1696       # x5 = 0x18_6a0 = 100000 (magic constant)
    mul     x6,  x10, x5        # x6 = a0 * 100000
    srli    x9,  x6, 14         # x9 = (a0 * 100000) >> 14
    mulhu   x18, x5,  x10       # high part of a0*100000
    slli    x18, x18, 18        # shift high part
    or      x8,  x18, x9        # x8 = combined fixed-point result

    jal     x1,  bin_to_bcd     # bin_to_bcd(x8) → x12

    csrrw   x0,  0xf02, x12     # write BCD to display CSR 0xf02

    jal     x0,  main           # j main (infinite loop)

# square root program below with loop to iteratively go with binary search to convert
sqrt:
    add     x8,  x0,  x10       # x8  = input value
    addi    x9,  x0,  0         # x9  = 0 (initial guess)
    addi    x18, x0,  1         # x18 = 1
    slli    x18, x18, 22        # x18 = 1 << 22 (initial step size)

sqrt_loop:
    beq     x18, x0,  sqrt_exit # if step == 0 → done

    add     x19, x9,  x18       # trial = guess + step
    mul     x5,  x19, x19       # low  part of trial^2
    mulhu   x6,  x19, x19       # high part of trial^2

    slli    x7,  x8,  14        # some scaled version of input
    srli    x28, x8,  18        # another scaled version of input

    bltu    x28, x6,  sqrt_step # if x28 < high(trial^2) → don't accept trial
    bltu    x6,  x28, sqrt_accept
                                # else if high(trial^2) < x28 → accept trial
    bltu    x7,  x5,  sqrt_step # else if scaled input < low(trial^2) → don't accept

sqrt_accept:
    add     x9,  x0,  x19       # guess = trial

sqrt_step:
    srli    x18, x18, 1         # step >>= 1
    jal     x0,  sqrt_loop      # j sqrt_loop

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
    addi    x10, x10, -1638     # x10 = 0x19999999 (magic /10 constant)
    addi    x11, x0,  10        # x11 = 10
    addi    x12, x0,  0         # x12 = 0 (BCD accumulator)

    # Digit 0 (no shift)
    mul     x5,  x8,  x10       # temp = x8 * magic
    mulhu   x8,  x8,  x10       # x8  = quotient ≈ x8/10
    mulhu   x5,  x5,  x11       # x5  = (temp high) * 10? (digit-ish)
    slli    x5,  x5,  0         # << 0
    or      x12, x12, x5        # place digit 0

    # Digit 1 (shift by 4)
    mul     x5,  x8,  x10
    mulhu   x8,  x8,  x10
    mulhu   x5,  x5,  x11
    slli    x5,  x5,  4         # << 4
    or      x12, x12, x5

    # Digit 2 (shift by 8)
    mul     x5,  x8,  x10
    mulhu   x8,  x8,  x10
    mulhu   x5,  x5,  x11
    slli    x5,  x5,  8         # << 8
    or      x12, x12, x5

    # Digit 3 (shift by 12)
    mul     x5,  x8,  x10
    mulhu   x8,  x8,  x10
    mulhu   x5,  x5,  x11
    slli    x5,  x5,  12        # << 12
    or      x12, x12, x5

    # Digit 4 (shift by 16)
    mul     x5,  x8,  x10
    mulhu   x8,  x8,  x10
    mulhu   x5,  x5,  x11
    slli    x5,  x5,  16        # << 16
    or      x12, x12, x5

    # Digit 5 (shift by 20)
    mul     x5,  x8,  x10
    mulhu   x8,  x8,  x10
    mulhu   x5,  x5,  x11
    slli    x5,  x5,  20        # << 20
    or      x12, x12, x5

    # Digit 6 (shift by 24)
    mul     x5,  x8,  x10
    mulhu   x8,  x8,  x10
    mulhu   x5,  x5,  x11
    slli    x5,  x5,  24        # << 24
    or      x12, x12, x5

    # Digit 7 (shift by 28)
    mul     x5,  x8,  x10
    mulhu   x8,  x8,  x10
    mulhu   x5,  x5,  x11
    slli    x5,  x5,  28        # << 28
    or      x12, x12, x5
    
    ret
