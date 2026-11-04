O ?= .
TMP ?= .
BL33 ?=
COMPRESS_ZSTD ?= 1
QEMU_LD_PREFIX ?= /usr/x86_64-linux-gnu/

UNAME_M := $(shell uname -m)
ifneq ($(UNAME_M),x86_64)
	QEMU =  qemu-x86_64 -L $(QEMU_LD_PREFIX)
endif

DVINIT_SIZE := 7168
BL30_MAX := 65536
BL33_MAX := 1572864
DDR_FIP_SIZE := 262144
# CONFIG_BL2E_96K
BL2E_SIZE ?= 116912
BL2X_SIZE := 108720

.PHONY: clean distclean
.NOTPARALLEL: ${TMP}/bl33.bin.zst ${TMP}/bl33.bin ${TMP}/dvinit-params.bin ${TMP}/bb1st-dv.sto.bin ${TMP}/bb1st-dv.usb.bin ${TMP}/bl2e.sto.bin ${TMP}/bl2e.usb.bin ${TMP}/bl2x.bin ${TMP}/bl30-payload.bin ${TMP}/bl33-payload.bin ${TMP}/device-fip.bin ${TMP}/ddr-fip.bin ${O}/u-boot.bin

all: ${O}/u-boot.bin

clean:
	rm -f ${TMP}/dvinit-params.bin ${TMP}/bb1st-dv.sto.bin ${TMP}/bb1st-dv.usb.bin
	rm -f ${TMP}/bl2e.sto.bin ${TMP}/bl2e.usb.bin ${TMP}/bl2x.bin
	rm -f ${TMP}/bl33.bin.zst ${TMP}/bl33.bin
	rm -f ${TMP}/bl30-payload.bin ${TMP}/bl33-payload.bin
	rm -f ${TMP}/device-fip.bin ${TMP}/ddr-fip.bin

distclean: clean
	rm -f ${O}/u-boot.bin ${O}/u-boot.bin.sd.bin ${O}/u-boot.bin.usb

${TMP}/dvinit-params.bin: acs.bin
	@if [ $$(stat -c %s acs.bin) -gt ${DVINIT_SIZE} ] ; then \
		echo "acs.bin exceeds ${DVINIT_SIZE} bytes" ; exit 1 ; fi
	dd if=/dev/zero of=$@ bs=${DVINIT_SIZE} count=1 status=none
	dd if=acs.bin of=$@ conv=notrunc status=none

${TMP}/bb1st-dv.%.bin: bb1st.%.bin.signed blob-bl2e.%.bin.signed ${TMP}/dvinit-params.bin
	${QEMU} ./acpu-imagetool create-boot-blobs \
		--chipset-authen-algorithm=rsa,none \
		--device-authen-algorithm=rsa,none \
		--infile-template-bb1st=bb1st.$*.bin.signed \
		--infile-blob-bl2e=blob-bl2e.$*.bin.signed \
		--infile-dvinit-params=${TMP}/dvinit-params.bin \
		--scs-family=s7d \
		--outfile-bb1st=$@

${TMP}/bl2e.%.bin: blob-bl2e.%.bin.signed
	@if [ $$(stat -c %s $<) -gt ${BL2E_SIZE} ] ; then \
		echo "$< exceeds ${BL2E_SIZE} bytes" ; exit 1 ; fi
	dd if=/dev/zero of=$@ bs=${BL2E_SIZE} count=1 status=none
	dd if=$< of=$@ conv=notrunc status=none

${TMP}/bl2x.bin: blob-bl2x.bin.signed
	@if [ $$(stat -c %s $<) -gt ${BL2X_SIZE} ] ; then \
		echo "$< exceeds ${BL2X_SIZE} bytes" ; exit 1 ; fi
	dd if=/dev/zero of=$@ bs=${BL2X_SIZE} count=1 status=none
	dd if=$< of=$@ conv=notrunc status=none

${TMP}/bl30-payload.bin: bl30.bin
	@if [ $$(stat -c %s bl30.bin) -gt ${BL30_MAX} ] ; then \
		echo "bl30.bin exceeds ${BL30_MAX} bytes" ; exit 1 ; fi
	dd if=/dev/zero of=$@ bs=${BL30_MAX} count=1 status=none
	dd if=bl30.bin of=$@ conv=notrunc status=none

le32 = printf "%08x" $(1) | sed 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/' | xxd -r -p

ifeq ($(COMPRESS_ZSTD),0)
${TMP}/bl33.bin: ${BL33}
	cp ${BL33} $@
else
${TMP}/bl33.bin.zst: ${BL33}
	${QEMU} ./zstd -q -f -9 ${BL33} -o $@

# "ZSTD", original size, compressed size, zstd frame
${TMP}/bl33.bin: ${TMP}/bl33.bin.zst
	printf "ZSTD" > $@
	$(call le32,$$(stat -c %s ${BL33})) >> $@
	$(call le32,$$(stat -c %s $<)) >> $@
	cat $< >> $@
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
		--header-layout=mini \
		--chipset-authen-algorithm=rsa,none \
		--device-authen-algorithm=rsa,none \
		--outfile-device-fip=$@

${TMP}/ddr-fip.bin:
	dd if=/dev/zero of=$@ bs=${DDR_FIP_SIZE} count=1 status=none

${O}/u-boot.bin: ${TMP}/bb1st-dv.sto.bin ${TMP}/bb1st-dv.usb.bin ${TMP}/bl2e.sto.bin ${TMP}/bl2e.usb.bin ${TMP}/bl2x.bin ${TMP}/device-fip.bin ${TMP}/ddr-fip.bin
	./pack-s7d.sh ${O}/u-boot.bin \
		${TMP}/bb1st-dv.sto.bin ${TMP}/bl2e.sto.bin ${TMP}/bl2x.bin \
		${TMP}/ddr-fip.bin ${TMP}/device-fip.bin ${O}/u-boot.bin.sd.bin
	./pack-s7d.sh ${O}/u-boot.bin.usb \
		${TMP}/bb1st-dv.usb.bin ${TMP}/bl2e.usb.bin ${TMP}/bl2x.bin \
		${TMP}/ddr-fip.bin ${TMP}/device-fip.bin
