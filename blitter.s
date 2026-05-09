# BLiT (BLock Image Transfer) operations.
#
# Uses macros heavily to avoid repeated blocks when I add all the various operations.
# These obviously expand in the assembled code for zero runtime overhead.
#

# calculate offsets, which is used for moving along pixels
# the display is rotated, so the origin is at the bottom left
# of the physical display that the user sees. that means the
# origin from the user's view is (0, height).
# to move right, add column size * 4 (4bpp), and to move down, add -4.
#
# result of this block is
#  out_base = framebuffer address of (x, y),
#  out_offset = offset needed to add to move between columns
#  t0 gets clobbered

.macro calc_origin base, w, h, x, y, out_base, out_offset
    # screen is rotated -90 degrees, so the origin point is essentially the
    # start of the last row of words in the framebuffer

    slli    \out_offset, \w, 2          # column offset (width * 4 bytes)

    # calculate origin
    slli    t0, \w, 2
    addi    t0, t0, -4
    add     \out_base, \base, t0        # origin = base addr + (width-1) * 4

    mul     t0, \x, \out_offset
    add     \out_base, \out_base, t0    # add x * column offset

    slli    t0, \y, 2
    sub     \out_base, \out_base, t0    # subtract y * 4 bytes
.endm

# the body of the blitter loops.
# uses t5 & t6 as counters
.macro blit_loop w, h, stash, innerop, advance
    mv      t6, \w
1337:
    mv      t5, \h     # rotated so we loop w * h
    \stash             # stash state needed for later advance
1338:
    \innerop           # inner blit operation goes here
    addi    t5, t5, -1
    bnez    t5, 1338b

    \advance           # advance based on previously stashed state
    addi    t6, t6, -1
    bnez    t6, 1337b
.endm

.macro op_fill
    sw      a7, 0(t1)
    add     t1, t1, t2
.endm

# fill(dst_buffer=a0, dst_width=a1, dst_height=a2, dst_x=a3, dst_y=a4, dst_w=a5, dst_h=a6, colour=a7)
.global fill
fill:
    # t1 = frame buffer origin
    # t2 = x position increment value
    # we don't need to calc y incrementer since we just move -4 bytes because this is a portrait display rotated
    calc_origin a0, a1, a2, a3, a4, t1, t2

    # run the blit loop, we only need to copy t1 as we are only writing to one frame buffer
    blit_loop a5, a6, "mv t3, t1", op_fill, "addi t1, t3, -4"
    ret

# wipe(fbuffer=a0, fbwidth=a1, fbheight=a2, frame=a3)
.global wipe
wipe:
    li      t0, 65
    blt     a3, t0, .draw
    li      a0, -1
    j       .done

.draw:
    srli    t3, a1, 1     # half the width as we are running two blits

    la      t1, sin_lut
    add     t1, t1, a3

    li      t2, 127

    lb      t0, 64(t1)
    sub     t0, t2, t0    # 127 - sin[64+0]
    mul     t0, t0, t3
    srli    t0, t0, 7     # (w * (127 - sin[0])) / 128

    lb      t1, 65(t1)
    sub     t1, t2, t1    # 127 - sin[64+1]
    mul     t1, t1, t3
    srli    t1, t1, 7     # (w * (127 - sin[1])) / 128

    sub     t1, t1, t0    # sin[2] - sin[1]
    bnez    t1, .blt
    li      t1, 1         # min 1 row

.blt:
    li      a3, 0
    mv      a4, t0 # x
    mv      a5, t1 # h
    mv      a6, a2

    # paint top half
    calc_origin a0, a1, a2, a3, a4, t1, t2
    blit_loop a5, a6, "mv t3, t1", op_fill, "addi t1, t3, -4"

    # paint bottom half
    add     a4, a4, a5    # x + h
    sub     a4, a1, a4    # width - x + h

    calc_origin a0, a1, a2, a3, a4, t1, t2
    blit_loop a5, a6, "mv t3, t1", op_fill, "addi t1, t3, -4"

    li      a0, 0

.done:
    ret
