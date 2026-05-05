ARCH := $(shell uname -m)

ifeq ($(ARCH),riscv64)
    AS = as
    LD = ld
else
    AS = riscv64-unknown-linux-gnu-as
    LD = riscv64-unknown-linux-gnu-ld
endif

ASFLAGS = -mno-relax

demo: demo.o
	$(LD) -o $@ $<

%.o: %.s
	$(AS) $(ASFLAGS) -o $@ $<

clean:
	rm -f *.o demo

