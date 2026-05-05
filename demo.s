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
#   s0=fd
#   s1=fb_base
#   s2=width
#   s3=height
#   s4=bpp_bytes
#   s5=fb_size
# Colour format: 0x00RRGGBB  (R01 is always 32bpp, 4 bytes/pixel)

# Max number of frames
.equ FRAME_MAX, 20


# syscall values
.equ AT_FDCWD,   -100
.equ O_RDWR,     0x002
.equ SYS_openat,  56
.equ SYS_ioctl,   29
.equ SYS_mmap,   222
.equ SYS_munmap, 215
.equ SYS_read,    63
.equ SYS_close,   57
.equ SYS_exit,    93
.equ FBIOGET_VSCREENINFO, 0x4600

.equ AT_FDCWD,   -100
.equ O_RDWR,     0x002

# macros
.macro die_if_neg code
    bgez    a0, 1337f
    li      a0, \code
    li      a7, SYS_exit
    ecall
1337:
.endm

.section .data
fb_path:  .asciz "/dev/fb0"
.align 8
fb_var:   .space 160, 0
frame:    .dword 0

.section .text
.global _start
_start:
    call    fb_open
    call    draw
    call    fb_close
    li      a0, 0
    li      a7, SYS_exit
    ecall

# draw — animation loop
draw:
    addi    sp, sp, -8
    sd      ra, 0(sp)
.loop:
    la      t0, frame
    ld      t1, 0(t0)
    addi    t1, t1, 1
    sd      t1, 0(t0)
    li      t2, FRAME_MAX
    bge     t1, t2, .done
    li      a0, 0x000080FF
    call    fill
    j       .loop
.done:
    ld      ra, 0(sp)
    addi    sp, sp, 8
    ret

# fb_open — open /dev/fb0, read screen info, mmap pixel buffer
# sets s0=fd s1=fb_base s2=width s3=height s4=bpp_bytes s5=fb_size
fb_open:
    li      a0, AT_FDCWD
    la      a1, fb_path
    li      a2, O_RDWR
    li      a3, 0
    li      a7, SYS_openat
    ecall

    die_if_neg 1

    mv      s0, a0
    li      a1, FBIOGET_VSCREENINFO
    la      a2, fb_var
    li      a7, SYS_ioctl
    ecall

    die_if_neg 2

    la      t0, fb_var
    lw      s2, 0(t0)
    lw      s3, 4(t0)
    lw      s4, 24(t0)
    srli    s4, s4, 3
    mul     s5, s2, s3
    mul     s5, s5, s4

    li      a0, 0
    mv      a1, s5
    li      a2, 0x3
    li      a3, 0x1
    mv      a4, s0
    li      a5, 0
    li      a7, SYS_mmap
    ecall
    li      t0, -4096
    die_if_neg 3
    mv      s1, a0
    ret

# fb_shutdown — wait for Enter, munmap, close
fb_close:
    addi    sp, sp, -16
    li      a0, 0
    mv      a1, sp
    li      a2, 1
    li      a7, SYS_read
    ecall
    addi    sp, sp, 16
    mv      a0, s1
    mv      a1, s5
    li      a7, SYS_munmap
    ecall
    mv      a0, s0
    li      a7, SYS_close
    ecall
    ret

.die1:
    li      a0, 1
    li      a7, SYS_exit
    ecall
.die2:
    li      a0, 2
    li      a7, SYS_exit
    ecall
.die3:
    li      a0, 3
    li      a7, SYS_exit
    ecall

# fill(colour=a0)
fill:
    mv      t0, s1
    mul     t1, s2, s3
    mv      t2, a0
.fl:
    sw      t2, 0(t0)
    addi    t0, t0, 4
    addi    t1, t1, -1
    bnez    t1, .fl
    ret

# pixel_addr(x=a0, y=a1) -> a0
pixel_addr:
    mul     t0, a1, s2
    add     t0, t0, a0
    slli    t0, t0, 2
    add     a0, s1, t0
    ret

# put_pixel(x=a0, y=a1, colour=a2)
put_pixel:
    addi    sp, sp, -16
    sd      ra, 0(sp)
    sd      a2, 8(sp)
    call    pixel_addr
    ld      a2, 8(sp)
    sw      a2, 0(a0)
    ld      ra, 0(sp)
    addi    sp, sp, 16
    ret
