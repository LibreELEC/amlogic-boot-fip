O ?= .
TMP ?= .
BL33 ?=
COMPRESS_LZ4 ?= 1
QEMU_LD_PREFIX ?= /usr/x86_64-linux-gnu/

UNAME_M := $(shell uname -m)
ifneq ($(UNAME_M),x86_64)
	QEMU =  qemu-x86_64 -L $(QEMU_LD_PREFIX)
endif

BL30_MAX := 65536
BL33_MAX := 1572864
DDR_FIP_SIZE := 262144

.PHONY: clean distclean
.NOTPARALLEL: ${TMP}/bl33.bin.lz4.enc ${TMP}/bl33.bin ${TMP}/dvinit-params.bin ${TMP}/bb1st-dv.sto.bin ${TMP}/bb1st-dv.usb.bin ${TMP}/bl30-payload.bin ${TMP}/bl33-payload.bin ${TMP}/device-fip.bin ${TMP}/ddr-fip.bin ${O}/u-boot.bin

all: ${O}/u-boot.bin

clean:
	rm -f ${TMP}/dvinit-params.bin ${TMP}/bb1st-dv.sto.bin ${TMP}/bb1st-dv.usb.bin
	rm -f ${TMP}/bl33.bin.lz4.enc ${TMP}/bl33.bin
	rm -f ${TMP}/bl30-payload.bin ${TMP}/bl33-payload.bin
	rm -f ${TMP}/device-fip.bin ${TMP}/ddr-fip.bin

distclean: clean
	rm -f ${O}/u-boot.bin ${O}/u-boot.bin.sd.bin ${O}/u-boot.bin.usb

${TMP}/dvinit-params.bin: acs.bin
	dd if=/dev/zero of=$@ bs=4096 count=1 status=none
	dd if=acs.bin of=$@ conv=notrunc status=none

${TMP}/bb1st-dv.%.bin: bb1st.%.bin.signed ${TMP}/dvinit-params.bin
	${QEMU} ./acpu-imagetool create-boot-blobs \
		--infile-template-bb1st=$< \
		--infile-dvinit-params=${TMP}/dvinit-params.bin \
		--scs-family=s4 \
		--outfile-bb1st=$@

${TMP}/bl30-payload.bin: bl30.bin
	@if [ $$(stat -c %s bl30.bin) -gt ${BL30_MAX} ] ; then \
		echo "bl30.bin exceeds ${BL30_MAX} bytes" ; exit 1 ; fi
	dd if=/dev/zero of=$@ bs=${BL30_MAX} count=1 status=none
	dd if=bl30.bin of=$@ conv=notrunc status=none

ifeq ($(COMPRESS_LZ4),0)
${TMP}/bl33.bin: ${BL33}
	cp ${BL33} $@
else
${TMP}/bl33.bin.lz4.enc: ${BL33}
	${QEMU} ./aml_encrypt_s4 --bl3sig --input ${BL33} --output $@ --compress lz4 --level v3 --type bl33

${TMP}/bl33.bin: ${TMP}/bl33.bin.lz4.enc
	dd if=$< of=$@ bs=1 skip=1824 status=none
endif

${TMP}/bl33-payload.bin: ${TMP}/bl33.bin
	@if [ $$(stat -c %s ${TMP}/bl33.bin) -gt ${BL33_MAX} ] ; then \
		echo "bl33 exceeds ${BL33_MAX} bytes" ; exit 1 ; fi
	dd if=/dev/zero of=$@ bs=${BL33_MAX} count=1 status=none
	dd if=${TMP}/bl33.bin of=$@ conv=notrunc status=none

${TMP}/device-fip.bin: device-fip-header.bin ${TMP}/bl30-payload.bin ${TMP}/bl33-payload.bin blob-bl31.bin.signed blob-bl32.bin.signed blob-bl40.bin.signed
	${QEMU} ./acpu-imagetool create-device-fip \
		--infile-template-chipset-fip-header=device-fip-header.bin \
		--infile-bl30-payload=${TMP}/bl30-payload.bin \
		--infile-bl33-payload=${TMP}/bl33-payload.bin \
		--infile-blob-bl40=blob-bl40.bin.signed \
		--infile-blob-bl31=blob-bl31.bin.signed \
		--infile-blob-bl32=blob-bl32.bin.signed \
		--outfile-device-fip=$@

${TMP}/ddr-fip.bin:
	dd if=/dev/zero of=$@ bs=${DDR_FIP_SIZE} count=1 status=none

${O}/u-boot.bin: ${TMP}/bb1st-dv.sto.bin ${TMP}/bb1st-dv.usb.bin ${TMP}/device-fip.bin ${TMP}/ddr-fip.bin
	./pack-s4.sh ${O}/u-boot.bin \
		${TMP}/bb1st-dv.sto.bin blob-bl2e.sto.bin.signed blob-bl2x.bin.signed \
		${TMP}/ddr-fip.bin ${TMP}/device-fip.bin ${O}/u-boot.bin.sd.bin
	./pack-s4.sh ${O}/u-boot.bin.usb \
		${TMP}/bb1st-dv.usb.bin blob-bl2e.usb.bin.signed blob-bl2x.bin.signed \
		${TMP}/ddr-fip.bin ${TMP}/device-fip.bin
