# demo.s
#
# RISC-V framebuffer demo Tony Miceli 2026
#
# coded specifically to run on the uConsole R01 as a brain exercise to learn
# something new, and practice the old age displiciple of trying to squeaze
# as much performance out of something pathetically underpowered, rather than
# the modern approach of throwing supercomputing at pathetically inefficient code.
#
# global registers (these need to be preserved across calls):
#   s0 = fd
#   s1 = fb_base
#   s2 = width
#   s3 = height
#   s4 = bpp_bytes
#   s5 = fb_size
#   s6 = tty fd
#   s7 = new VT number (from VT_OPENQRY)
#   s8 = original VT number
#   s9 = keyboard fd
#   s10 = screen save buffer
#
# Colour format: 0x00RRGGBB  (R01 is always 32bpp, 4 bytes/pixel)

# Max number of frames
.equ FRAME_MAX, 20000

.equ KEY_ESC,             0x01

.include "macros.s"

.section .data
frame:        .dword 0

.section .text
.global _start
_start:
    call    fb_open
    call    kb_open
    call    draw
    call    fb_close
    call    kb_close
    li      a0, 0
    li      a7, SYS_exit
    ecall

# draw — animation loop
draw:
    addi    sp, sp, -8
    sd      ra, 0(sp)

    # copy the save buffer to frame buffer
    mv      a0, s10             # src = save buffer
    mv      a1, s1              # dst = frame buffer
    mv      a2, s5              # byte count
    call    fb_copy

.loop:
    # increment frame counter
    la      t0, frame
    ld      t1, 0(t0)
    addi    t1, t1, 1
    sd      t1, 0(t0)

    li      t2, FRAME_MAX
    bge     t1, t2, .done

    #li      a0, 0x000080FF

    #mv      a0, s10             # src = save buffer
    #mv      a1, s1              # dst = frame buffer
    #mv      a2, s5              # byte count
    #call    fb_copy

    mv      a0, s1              # fb_base
    mv      a1, s2              # width
    mv      a2, s3              # height
    #mv      a3, t1              # frame index
    #andi    a3, t1, 500           # frame index / 8

    li      a3, 20
    call    fill

    call    kb_check
    li      t0, KEY_ESC
    bne     a0, t0, .loop

.done:
    ld      ra, 0(sp)
    addi    sp, sp, 8
    ret
