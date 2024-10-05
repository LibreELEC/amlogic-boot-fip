O ?= .
TMP ?= .
BL33 ?=

.phony: clean distclean

all: ${O}/u-boot.bin ${O}/bl1.bin.hardkernel

clean:
	: # no-op

distclean: clean

${O}/u-boot.bin: ${TMP}/
	cp u-boot.bin ${O}/u-boot.bin

${O}/bl1.bin.hardkernel: ${TMP}/
	cp bl1.bin.hardkernel ${O}/u-boot.bin
