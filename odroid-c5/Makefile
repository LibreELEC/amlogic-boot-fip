O ?= .
TMP ?= .
BL33 ?=
STORAGE ?= sto
QEMU_LD_PREFIX ?= /usr/x86_64-linux-gnu/

UNAME_M := $(shell uname -m)
ifneq ($(UNAME_M),x86_64)
	QEMU =  qemu-x86_64 -L $(QEMU_LD_PREFIX)
endif

AML_ENCRYPT ?= aml_encrypt_s7d

.PHONY: clean distclean

all: ${O}/u-boot.bin.signed

clean:
	rm -f ${TMP}/bb1st.${STORAGE}.bin.signed
	rm -f ${TMP}/bb1st.${STORAGE}.bin.signed.max
	rm -f ${TMP}/bb1st.${STORAGE}.bin.signed.max.hdr
	rm -f ${TMP}/bl30-payload.bin
	rm -f ${TMP}/bl33-payload.bin
	rm -f ${TMP}/blob-bl2e.${STORAGE}.bin.signed
	rm -f ${TMP}/blob-bl2e.${STORAGE}.bin.signed.max
	rm -f ${TMP}/blob-bl2x.bin.signed
	rm -f ${TMP}/blob-bl2x.bin.signed.max
	rm -f ${TMP}/ddr-fip.bin
	rm -f ${TMP}/device-fip.bin.signed
	rm -f ${TMP}/dvinit-params.bin

distclean: clean
	rm -f ${O}/u-boot.bin.signed

${TMP}/dvinit-params.bin: acs.bin
	./pad.sh $< $@ 7168

${TMP}/%: %.rsa.rsa
	cp $< $@

${TMP}/bb1st.${STORAGE}.bin.signed: ${TMP}/dvinit-params.bin
	${QEMU} ./acpu-imagetool create-boot-blobs \
		--chipset-authen-algorithm=rsa,none \
		--device-authen-algorithm=rsa,none \
		--infile-template-bb1st=bb1st.${STORAGE}.bin.signed.rsa.rsa \
		--infile-blob-bl2e=blob-bl2e.${STORAGE}.bin.signed.rsa.rsa \
		--infile-dvinit-params=${TMP}/dvinit-params.bin \
		--scs-family=s7d \
		--outfile-bb1st=$@

${TMP}/bl30-payload.bin: bl30.bin
	./pad.sh $< $@ 65536

${TMP}/bl33-payload.bin: ${BL33} bl33z.bin
	./bl33_process.sh $^ $@

${TMP}/device-fip.bin.signed: ${TMP}/bl30-payload.bin ${TMP}/bl33-payload.bin
	${QEMU} ./acpu-imagetool create-device-fip \
		--infile-template-chipset-fip-header=device-fip-header.bin.rsa.rsa \
		--infile-bl30-payload=${TMP}/bl30-payload.bin \
		--infile-bl33-payload=${TMP}/bl33-payload.bin \
		--infile-blob-bl40=blob-bl40.bin.signed.rsa.rsa \
		--infile-blob-bl31=blob-bl31.bin.signed.rsa.rsa \
		--infile-blob-bl32=blob-bl32.bin.signed.rsa.rsa \
		--header-layout=mini \
		--chipset-authen-algorithm=rsa,none \
		--device-authen-algorithm=rsa,none \
		--outfile-device-fip=$@

${O}/u-boot.bin.signed: ${TMP}/device-fip.bin.signed ${TMP}/bb1st.${STORAGE}.bin.signed ${TMP}/blob-bl2e.${STORAGE}.bin.signed ${TMP}/blob-bl2x.bin.signed
	./mk_uboot.sh "${O}" "${TMP}" ".signed" ".${STORAGE}" ""
