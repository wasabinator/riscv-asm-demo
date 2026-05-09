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
.equ FRAME_MAX,        500
.equ CYCLES_PER_FRAME, 16666666 # 1GHz CPU

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

    rdcycle s11                 # last frame time

.loop:
    # increment frame counter
    la      t0, frame
    ld      t1, 0(t0)
    addi    t1, t1, 1
    sd      t1, 0(t0)

    li      t2, FRAME_MAX
    bge     t1, t2, .done

    #mv      a0, s10             # src = save buffer
    #mv      a1, s1              # dst = frame buffer
    #mv      a2, s5              # byte count
    #call    fb_copy

    mv      a0, s1              # fb_base
    mv      a1, s2              # fb_width
    mv      a2, s3              # fb_height
    li      a3, 200             # x
    li      a4, 50              # y
    mv      a5, t1              # w
    li      a6, 100             # h
    li      a7, 0x000080FF      # colour
    call    fill

.wait:
    call    kb_check
    li      t0, KEY_ESC
    bne     a0, t0, .loop

    rdcycle t0
    sub     t0, t0, s11             # elapsed since last frame
    li      t1, CYCLES_PER_FRAME
    blt     t0, t1, .wait           # wait on frame time interval
    rdcycle s11                     # reset frame timer

.done:
    ld      ra, 0(sp)
    addi    sp, sp, 8
    ret
