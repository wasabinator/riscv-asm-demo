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
#
# Colour format: 0x00RRGGBB  (R01 is always 32bpp, 4 bytes/pixel)

# Max number of frames
.equ FRAME_MAX, 20000

# syscalls
.equ SYS_openat,  56
.equ SYS_ioctl,   29
.equ SYS_mmap,   222
.equ SYS_munmap, 215
.equ SYS_read,    63
.equ SYS_close,   57
.equ SYS_exit,    93

.equ AT_FDCWD,            -100
.equ EVIOCGRAB,           0x40044590
.equ FBIOGET_VSCREENINFO, 0x4600
.equ KDSETMODE,           0x4B3A
.equ KD_GRAPHICS,         0x01
.equ KD_TEXT,             0x00
.equ O_NONBLOCK,          0x800
.equ O_RDONLY,            0x000
.equ O_RDWR,              0x002
.equ VT_ACTIVATE,         0x5606
.equ VT_DISALLOCATE,      0x5608
.equ VT_GETSTATE,         0x5603
.equ VT_OPENQRY,          0x5600
.equ VT_WAITACTIVE,       0x5607

.equ EV_KEY,    0x01
.equ KEY_ESC,   0x01

# macros
.macro die_if_neg code
    bgez    a0, 1337f
    li      t0, \code
    li      t1, 6
    blt     t0, t1, 1338f   # code 5 = before KD_GRAPHICS so need to skip tty restore
    mv      a0, s6
    li      a1, KDSETMODE
    li      a2, KD_TEXT
    li      a7, SYS_ioctl
    ecall
1338:
    li      a0, \code
    li      a7, SYS_exit
    ecall
1337:
.endm

.section .data
fb_path:      .asciz "/dev/fb0"
tty_path:     .asciz "/dev/tty0"
kbd_path:     .asciz "/dev/input/event3"
.align 8
fb_var:       .space 160, 0
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
.loop:
    la      t0, frame
    ld      t1, 0(t0)
    addi    t1, t1, 1
    sd      t1, 0(t0)
    li      t2, FRAME_MAX
    bge     t1, t2, .done
    li      a0, 0x000080FF
    call    fill
    call    kb_check
    li      t0, KEY_ESC
    bne     a0, t0, .loop

.done:
    ld      ra, 0(sp)
    addi    sp, sp, 8
    ret

# fb_open — open /dev/fb0, read screen info, mmap pixel buffer
# sets s0=fd s1=fb_base s2=width s3=height s4=bpp_bytes s5=fb_size
fb_open:
    # open /dev/tty
    li      a0, AT_FDCWD
    la      a1, tty_path
    li      a2, O_RDWR
    li      a3, 0
    li      a7, SYS_openat
    ecall
    die_if_neg 1
    mv      s6, a0

    # save current VT
    addi    sp, sp, -16     # allocate space on stack for struct 
    mv      a0, s6
    li      a1, VT_GETSTATE
    mv      a2, sp
    li      a7, SYS_ioctl
    ecall
    lh      s8, 0(sp)       # v_active is first field in struct
    addi    sp, sp, 16      # restore stack
    die_if_neg 2

    # use vt7
    li s7, 7

    # switch to it
    mv      a0, s6
    li      a1, VT_ACTIVATE
    mv      a2, s7
    li      a7, SYS_ioctl
    ecall
    die_if_neg 4

    # wait for it
    mv      a0, s6
    li      a1, VT_WAITACTIVE
    mv      a2, s7
    li      a7, SYS_ioctl
    ecall
    die_if_neg 5

    # set KD_GRAPHICS
    mv      a0, s6
    li      a1, KDSETMODE
    li      a2, KD_GRAPHICS
    li      a7, SYS_ioctl
    ecall
    die_if_neg 6

    # open /dev/fb0
    li      a0, AT_FDCWD
    la      a1, fb_path
    li      a2, O_RDWR
    li      a3, 0
    li      a7, SYS_openat
    ecall
    die_if_neg 7
    mv      s0, a0

    # FBIOGET_VSCREENINFO
    li      a1, FBIOGET_VSCREENINFO
    la      a2, fb_var
    li      a7, SYS_ioctl
    ecall
    die_if_neg 8

    la      t0, fb_var
    lw      s2, 0(t0)
    lw      s3, 4(t0)
    lw      s4, 24(t0)
    srli    s4, s4, 3
    mul     s5, s2, s3
    mul     s5, s5, s4

    # mmap(NULL, fb_size, PROT_READ|PROT_WRITE, MAP_SHARED, fb_fd, 0)
    li      a0, 0
    mv      a1, s5
    li      a2, 0x3
    li      a3, 0x1
    mv      a4, s0
    li      a5, 0
    li      a7, SYS_mmap
    ecall
    die_if_neg 9

    mv      s1, a0
    ret

# fb_close — restore text mode, munmap, close fb0 and tty
fb_close:
    # restore KD_TEXT
    mv      a0, s6
    li      a1, KDSETMODE
    li      a2, KD_TEXT
    li      a7, SYS_ioctl
    ecall

    # switch back to original VT (we got this in s8 during fb_open)
    mv      a0, s6
    li      a1, VT_ACTIVATE
    mv      a2, s8
    li      a7, SYS_ioctl
    ecall

    # wait for it
    mv      a0, s6
    li      a1, VT_WAITACTIVE
    mv      a2, s8
    li      a7, SYS_ioctl
    ecall

    # disallocate the VT we used
    mv      a0, s6
    li      a1, VT_DISALLOCATE
    mv      a2, s7
    li      a7, SYS_ioctl
    ecall

    # munmap
    mv      a0, s1
    mv      a1, s5
    li      a7, SYS_munmap
    ecall

    # close fb0
    mv      a0, s0
    li      a7, SYS_close
    ecall

    # close tty
    mv      a0, s6
    li      a7, SYS_close
    ecall
    ret

kb_open:
    li      a0, AT_FDCWD
    la      a1, kbd_path
    li      a2, O_NONBLOCK      # non-blocking so we can poll each frame
    li      a3, 0
    li      a7, SYS_openat
    ecall
    die_if_neg 10
    mv      s9, a0

    # grab exclusive access to keyboard
    mv      a0, s9
    li      a1, EVIOCGRAB
    li      a2, 1
    li      a7, SYS_ioctl
    ecall
    die_if_neg 11
    ret

# kb_check — returns keycode in a0 if key down event, 0 otherwise
kb_check:
    addi    sp, sp, -32
    sd      ra, 0(sp)

    mv      a0, s9
    addi    a1, sp, 8
    li      a2, 24
    li      a7, SYS_read
    ecall
    bltz    a0, .no_key         # EAGAIN = no event

    lhu     t0, 24(sp)          # type
    li      t1, EV_KEY
    bne     t0, t1, .no_key

    lw      t0, 28(sp)          # value — only report keydown (1)
    li      t1, 1
    bne     t0, t1, .no_key

    lhu     a0, 26(sp)          # return keycode
    j       .kb_done
.no_key:
    li      a0, 0
.kb_done:
    ld      ra, 0(sp)
    addi    sp, sp, 32
    ret

kb_close:
    mv      a0, s9
    li      a1, EVIOCGRAB
    li      a2, 0
    li      a7, SYS_ioctl
    ecall

    # close kbd
    mv      a0, s9
    li      a7, SYS_close
    ecall
    ret

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
