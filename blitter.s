.macro blit src, dst, count, innerop
    mv      t0, \src
    mv      t1, \dst
    mv      t2, \count
.blit_loop:
    lw      t3, 0(t0)
    \innerop
    sw      t3, 0(t1)
    addi    t0, t0, 4
    addi    t1, t1, 4
    addi    t2, t2, -1
    bnez    t2, .blit_loop
.endm

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

# fill(dst_buffer=a0, dst_width=a1, dst_height=a2, dst_x=a3, dst_y=a4, dst_w=a5, dst_h=a6, colour=a7)
.global fill
fill:
    srli    t0, a2, 1
    blt     a3, t0, .begin        # frame < height/2?

    li      a0, -1                # -1 = animation is complete
    j       .done

.begin:
    # calculate offsets, which is used for moving along pixels
    # the display is rotated, so the origin is at the bottom left
    # of the physical display that the user sees. that means the
    # origin from the user's view is (0, height).
    # to move right, add column size * 4 (4bpp), and to move down, add -4.

    slli    t5, a1, 2      # column offset

    # calculate origin (0, (width-1)*4)
    slli    t0, a1, 2
    add     t1, a0, t0
    addi    t1, t1, -4

    # move to (dst_x, dst_y)
    mul     t0, a3, t5
    add     t1, t1, t0
    slli    t0, a4, 2
    sub     t1, t1, t0

    mv      t2, a6         # number of rows to write (screen is rotated so this is src_w)

.rows:
    mv      t3, a5         # number of pixels to write (src_h because rotated)
    mv      t6, t1         # copy pos

.row:
    sw      a7, 0(t1)

    # advance to next column
    add     t1, t1, t5

    # check if col done
    addi    t3, t3, -1
    bgtz    t3, .row

    # advance to next row
    addi    t1, t6, -4

    # check if rows done
    addi    t2, t2, -1
    bgtz    t2, .rows

    li      a0, 0

.done:
    ret

#blit s1, s10, s5, op_copy
#blit s1, s10, s5, "li t3, 0x00FF0000"
