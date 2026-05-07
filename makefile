ARCH := $(shell uname -m)

ifeq ($(ARCH),riscv64)
	AS = as
	LD = ld
else
	AS = riscv64-unknown-linux-gnu-as
	LD = riscv64-unknown-linux-gnu-ld
endif

ASFLAGS = -mno-relax
DEPLOY_HOST = cpi@uConsole-R01
DEPLOY_PATH = /home/cpi

demo: demo.o sine.o keyboard.o framebuffer.o
	$(LD) -o $@ $^

%.o: %.s
	$(AS) $(ASFLAGS) -o $@ $<

clean:
	rm -f *.o demo

deploy: demo
	scp demo $(DEPLOY_HOST):$(DEPLOY_PATH)
