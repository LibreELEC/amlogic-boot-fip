O ?= .
TMP ?= .
BL33 ?=
QEMU_LD_PREFIX ?= /usr/x86_64-linux-gnu/

UNAME_M := $(shell uname -m)
ifneq ($(UNAME_M),x86_64)
	QEMU =  qemu-x86_64 -L $(QEMU_LD_PREFIX)
endif

.PHONY: clean distclean
.NOTPARALLEL: ${TMP}/bl30_new.bin ${TMP}/fip.bin ${TMP}/bl2_acs.bin ${TMP}/bl2_new.bin ${TMP}/boot_new.bin ${O}/u-boot.bin

all: ${O}/u-boot.bin

clean:
	rm -f ${TMP}/bl301_zero.bin
	rm -f ${TMP}/bl30_zero.bin
	rm -f ${TMP}/bl30_new.bin
	rm -f ${TMP}/bl21_zero.bin
	rm -f ${TMP}/bl2_zero.bin
	rm -f ${TMP}/zero_tmp
	rm -f ${TMP}/bl2_acs.bin
	rm -f ${TMP}/bl2_new.bin
	rm -f ${TMP}/fip.bin
	rm -f ${TMP}/boot_new.bin

distclean: clean
	rm -f ${O}/u-boot.bin ${O}/u-boot.bin.sd.bin ${O}/u-boot.bin.usb.bl2 ${O}/u-boot.bin.usb.tpl

${TMP}/bl30_new.bin: bl30.bin bl301.bin
	./blx_fix.sh bl30.bin ${TMP}/zero_tmp ${TMP}/bl30_zero.bin bl301.bin ${TMP}/bl301_zero.bin ${TMP}/bl30_new.bin bl30

${TMP}/fip.bin: ${TMP}/bl30_new.bin bl31.img ${BL33}
	${QEMU} ./fip_create --bl30 ${TMP}/bl30_new.bin --bl31 bl31.img --bl33 ${BL33} ${TMP}/fip.bin

${TMP}/bl2_acs.bin: bl2.bin acs.bin
	sed -i 's/\x73\x02\x08\x91/\x1F\x20\x03\xD5/' bl2.bin
	python3 acs_tool.py bl2.bin ${TMP}/bl2_acs.bin acs.bin 0

${TMP}/bl2_new.bin: ${TMP}/bl2_acs.bin bl21.bin
	./blx_fix.sh ${TMP}/bl2_acs.bin ${TMP}/zero_tmp ${TMP}/bl2_zero.bin bl21.bin ${TMP}/bl21_zero.bin ${TMP}/bl2_new.bin bl2

${TMP}/boot_new.bin: ${TMP}/fip.bin ${TMP}/bl2_new.bin
	cat ${TMP}/bl2_new.bin ${TMP}/fip.bin > ${TMP}/boot_new.bin

${O}/u-boot.bin: ${TMP}/boot_new.bin
	${QEMU} ./aml_encrypt_gxb --bootsig --input ${TMP}/boot_new.bin --output ${TMP}/u-boot.bin
	dd if=$(TMP)/u-boot.bin of=$(TMP)/u-boot.bin.gxbb bs=512 conv=fsync
	dd if=$(TMP)/u-boot.bin of=$(TMP)/u-boot.bin.gxbb bs=512 seek=9 skip=8 count=87 conv=fsync,notrunc
	dd if=/dev/zero of=$(TMP)/u-boot.bin.gxbb bs=512 seek=8 count=1 conv=fsync,notrunc
	dd if=bl1.bin.hardkernel of=$(TMP)/u-boot.bin.gxbb bs=512 seek=2 skip=2 count=1 conv=fsync,notrunc
	${QEMU} ./aml_chksum $(TMP)/u-boot.bin.gxbb
	cp -R ${TMP}/u-boot.bin.gxbb ${O}/u-boot.bin
	cp -R ${TMP}/u-boot.bin.gxbb ${O}/u-boot.bin.sd.bin
