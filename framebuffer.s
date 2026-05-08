# syscalls
.equ SYS_openat,  56
.equ SYS_ioctl,   29
.equ SYS_mmap,   222
.equ SYS_munmap, 215
.equ SYS_read,    63
.equ SYS_close,   57
.equ SYS_exit,    93

.equ AT_FDCWD,            -100
.equ FBIOGET_VSCREENINFO, 0x4600
.equ KDSETMODE,           0x4B3A
.equ KD_GRAPHICS,         0x01
.equ KD_TEXT,             0x00
.equ O_RDONLY,            0x000
.equ O_RDWR,              0x002
.equ VT_ACTIVATE,         0x5606
.equ VT_DISALLOCATE,      0x5608
.equ VT_GETSTATE,         0x5603
.equ VT_OPENQRY,          0x5600
.equ VT_WAITACTIVE,       0x5607

.include "macros.s"

.section .data
fb_path:      .asciz "/dev/fb0"
tty_path:     .asciz "/dev/tty0"
.align 8
fb_var:       .space 160, 0

.section .text
.global fb_open

# fb_open — open /dev/fb0, read screen info, mmap pixel buffer
# sets s0=fd s1=fb_base s2=width s3=height s4=bpp_bytes s5=fb_size
.global fb_open
fb_open:
    addi    sp, sp, -8
    sd      ra, 0(sp)

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

    # open /dev/fb0
    li      a0, AT_FDCWD
    la      a1, fb_path
    li      a2, O_RDWR
    li      a3, 0
    li      a7, SYS_openat
    ecall
    die_if_neg 3
    mv      s0, a0

    # FBIOGET_VSCREENINFO
    li      a1, FBIOGET_VSCREENINFO
    la      a2, fb_var
    li      a7, SYS_ioctl
    ecall
    die_if_neg 4

    # get screen dimensions
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

    # snapshow the x11 display so we can run the initial fade on it
    call    fb_snapshot
    die_if_neg 5

    # switch to VT7
    li      s7, 7
    mv      a0, s6
    li      a1, VT_ACTIVATE
    mv      a2, s7
    li      a7, SYS_ioctl
    ecall
    die_if_neg 6

    # set KD_GRAPHICS
    mv      a0, s6
    li      a1, KDSETMODE
    li      a2, KD_GRAPHICS
    li      a7, SYS_ioctl
    ecall
    die_if_neg 8

    # wait for it
    mv      a0, s6
    li      a1, VT_WAITACTIVE
    mv      a2, s7
    li      a7, SYS_ioctl
    ecall
    die_if_neg 7

    ld      ra, 0(sp)
    addi    sp, sp, 8
    ret

# fb_close — restore text mode, munmap, close fb0 and tty
.global fb_close
fb_close:
    addi    sp, sp, -8
    sd      ra, 0(sp)

    call    fb_restore  #restore x11 state and dealloc buffer

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

    ld      ra, 0(sp)
    addi    sp, sp, 8
    ret

# fb_snapshot(s1 = fb_base, s5 = fb_size) -> s10 = screen save buffer
.global fb_snapshot
fb_snapshot:
    .equ PROT_READ,     0x1
    .equ PROT_WRITE,    0x2
    .equ MAP_PRIVATE,   0x2
    .equ MAP_ANONYMOUS, 0x20

    addi    sp, sp, -32
    sd      ra, 0(sp)

    # alloc
    li      a0, 0
    mv      a1, s5              # fb_size
    li      a2, PROT_READ | PROT_WRITE
    li      a3, MAP_PRIVATE | MAP_ANONYMOUS
    li      a4, -1              # fd = -1 for anonymous
    li      a5, 0
    li      a7, SYS_mmap
    ecall
    bltz    a0, .end

    mv      s10, a0             # s10 = screen save buffer
    mv      a0, s1              # src = fb_base
    mv      a1, s10             # dst = save buffer
    mv      a2, s5              # byte count
    call    fb_copy
    li      a0, 0

.end:
    ld      ra, 0(sp)
    addi    sp, sp, 32
    ret

# fb_copy(src=a0, dst=a1, count=a2)
.global fb_copy
fb_copy:
    mv      t0, a0              # src
    mv      t1, a1              # dst
    mv      t2, a2              # byte count

.copy:
    ld      t3, 0(t0)
    sd      t3, 0(t1)
    addi    t0, t0, 8
    addi    t1, t1, 8
    addi    t2, t2, -8
    bnez    t2, .copy
    ret

.global fb_restore
fb_restore:
    addi    sp, sp, -32
    sd      ra, 0(sp)

    mv      a0, s10             # src = fb_base
    mv      a1, s1              # dst = save buffer
    mv      a2, s5              # byte count
    call    fb_copy

    # dealloc
    mv      a0, s10
    mv      a1, s5
    li      a7, SYS_munmap
    ecall

    ld      ra, 0(sp)
    addi    sp, sp, 32
    ret

# fill(fb_base=a0, width=a1, height=a2, frame=a3)
.global fill
fill:
    srli    t0, a2, 1
    blt     a3, t0, .begin        # frame < height/2?

    li      a0, -1                # -1 = animation is complete
    j       .done

.begin:
    # calculate offsets, which is used for moving alone pixels
    # the display is rotated, so the origin is at the bottom left
    # of the physical display that the user sees. that means the
    # origin from the user's view is (0, height).
    # to move right, add column size * 4 (4bpp), and to move down, add -4.

    slli    t5, a1, 2      # column offset

    # calculate origin (0, (width-1)*4)
    slli    t0, a1, 2
    add     t1, a0, t0
    addi    t1, t1, -4

    li      t2, 500        # number of rows to write
    li      t4, 0x000080FF # clear value

.rows:
    mv      t3, a2         # number of pixels to write (1 col = height because rotated)
    mv      t6, t1         # copy pos

.row:
    sw      t4, 0(t1)

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

# pixel_addr(x=a0, y=a1) -> a0
.global pixel_addr
pixel_addr:
    mul     t0, a1, s2
    add     t0, t0, a0
    slli    t0, t0, 2
    add     a0, s1, t0
    ret

# put_pixel(x=a0, y=a1, colour=a2)
.global put_pixel
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
