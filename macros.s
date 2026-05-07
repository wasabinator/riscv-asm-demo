.equ SYS_exit,    93
.equ SYS_ioctl,   29

.equ KDSETMODE,           0x4B3A
.equ KD_TEXT,             0x00

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
