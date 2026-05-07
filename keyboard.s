.equ SYS_close,   57
.equ SYS_ioctl,   29
.equ SYS_openat,  56
.equ SYS_read,    63

.equ AT_FDCWD,    -100
.equ EV_KEY,      0x01
.equ EVIOCGRAB,   0x40044590
.equ O_NONBLOCK,  0x800

.include "macros.s"

.section .data
kbd_path:     .asciz "/dev/input/event3"

.section .text

.global kb_open
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
.global kb_check
kb_check:
    addi    sp, sp, -32         # alloc read buffer on stack

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
    addi    sp, sp, 32          # dealloc read buffer
    ret

.global kb_close
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
