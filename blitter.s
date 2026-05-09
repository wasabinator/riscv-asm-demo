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

# fill(dst_buffer=a0, dst_width=a1, dst_height=a2, dst_x=a3, dst_y=a4, dst_w=a5, dst_h=a6, colour=a7)
.global fill
fill:
    # t1 = frame buffer origin
    # t2 = x position increment value
    # we don't need to calc y incrementer since we just move +4 bytes because this is a portrait display rotated
    calc_origin a0, a1, a2, a3, a4, t1, t2

    mv      t4, a6         # number of rows to write (screen is rotated so this is src_w)

.rows:
    mv      t3, a5         # number of pixels to write (src_h because rotated)
    mv      t6, t1         # copy pos

.row:
    sw      a7, 0(t1)

    # advance to next column
    add     t1, t1, t2

    # check if col done
    addi    t3, t3, -1
    bgtz    t3, .row

    # advance to next row
    addi    t1, t6, -4

    # check if rows done
    addi    t4, t4, -1
    bgtz    t4, .rows

    ret

#blit s1, s10, s5, op_copy
#blit s1, s10, s5, "li t3, 0x00FF0000"

# define operations as macros
.macro op_copy
    # t3 already has src value, nothing to do
.endm

.macro op_fill colour
    li      t3, \colour
.endm

.macro op_and src2
    lw      t4, 0(t1)
    and     t3, t3, t4
.endm

# the body of the blitter loops. uses t6 & t7 as counters
.macro blit_loop w, h, stash, innerop, advance
    mv      t7, \h
1337:
    mv      t6, \w     # rotated so we loop w * h
    \stash             # stash state needed for later advance
1338:
    \innerop           # inner blit operation goes here
    addi    t6, t6, -1
    bnez    t6, 1338b

    \advance           # advance based on previously stashed state
    addi    t7, t7, -1
    bnez    t7, 1337b
.endm

.macro stash src, tmp
    mv      \tmp, \src
.endm

.macro advance src, tmp, offset
    add     \src, \tmp, \offset
.endm
