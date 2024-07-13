O ?= .
TMP ?= .
BL33 ?=
COMPRESS_LZ4 ?= 0
QEMU_LD_PREFIX ?= /usr/x86_64-linux-gnu/

ifeq ($(COMPRESS_LZ4),0)
	BL33_ARGS :=
else
	BL33_ARGS :=--compress lz4
endif

UNAME_M := $(shell uname -m)
ifneq ($(UNAME_M),x86_64)
	QEMU =  qemu-x86_64 -L $(QEMU_LD_PREFIX)
endif

AML_ENCRYPT ?= aml_encrypt_g12a

.PHONY: clean distclean
.NOTPARALLEL: ${TMP}/bl30_new.bin ${TMP}/bl2_new.bin ${TMP}/bl30_new.bin.g12a.enc ${TMP}/bl30_new.bin.enc ${TMP}/bl31.img.enc ${TMP}/bl33.bin.enc ${TMP}/bl2.n.bin.sig ${O}/u-boot.bin

all: ${O}/u-boot.bin

clean:
	rm -f ${TMP}/bl30_new.bin ${TMP}/bl2_new.bin
	rm -f ${TMP}/bl30_new.bin.g12a.enc ${TMP}/bl30_new.bin.enc
	rm -f ${TMP}/bl31.img.enc ${TMP}/bl33.bin.enc
	rm -f ${TMP}/bl21_zero.bin ${TMP}/bl2_zero.bin
	rm -f ${TMP}/bl301_zero.bin ${TMP}/bl30_zero.bin ${TMP}/bl2.n.bin.sig

distclean: clean
	rm -f ${O}/u-boot.bin ${O}/u-boot.bin.sd.bin ${O}/u-boot.bin.usb.bl2 ${O}/u-boot.bin.usb.tpl

${TMP}/bl30_new.bin: bl30.bin bl301.bin
	./blx_fix.sh bl30.bin ${TMP}/zero_tmp ${TMP}/bl30_zero.bin bl301.bin ${TMP}/bl301_zero.bin ${TMP}/bl30_new.bin bl30
	@if [ -e ${TMP}/zero_tmp ] ; then rm ${TMP}/zero_tmp ; fi
	@rm ${TMP}/bl30_zero.bin ${TMP}/bl301_zero.bin

${TMP}/bl2_new.bin: bl2.bin acs.bin
	./blx_fix.sh bl2.bin ${TMP}/zero_tmp ${TMP}/bl2_zero.bin acs.bin ${TMP}/bl21_zero.bin ${TMP}/bl2_new.bin bl2
	@if [ -e ${TMP}/zero_tmp ] ; then rm ${TMP}/zero_tmp ; fi
	@rm ${TMP}/bl2_zero.bin ${TMP}/bl21_zero.bin

ifneq ($(GXLIMG_PATH),)
${TMP}/bl30_new.bin.enc: ${TMP}/bl30_new.bin
	${GXLIMG_PATH} -t bl30 -s ${TMP}/bl30_new.bin ${TMP}/bl30_new.bin.enc

${TMP}/bl31.img.enc: bl31.img
	${GXLIMG_PATH} -t bl3x -s bl31.img ${TMP}/bl31.img.enc

${TMP}/bl33.bin.enc: ${BL33}
	${GXLIMG_PATH} -t bl3x -s ${BL33} ${TMP}/bl33.bin.enc

${TMP}/bl2.n.bin.sig: ${TMP}/bl2_new.bin
	${GXLIMG_PATH} -t bl2 -s ${TMP}/bl2_new.bin ${TMP}/bl2.n.bin.sig

${O}/u-boot.bin: ${TMP}/bl2.n.bin.sig ${TMP}/bl30_new.bin.enc ${TMP}/bl31.img.enc ${TMP}/bl33.bin.enc
	if [ -e lpddr3_1d.fw ] ; then \
		${GXLIMG_PATH} -t fip --rev v3 \
			       --bl2 ${TMP}/bl2.n.bin.sig --bl30 ${TMP}/bl30_new.bin.enc \
			       --bl31 ${TMP}/bl31.img.enc --bl33 ${TMP}/bl33.bin.enc \
			       --ddrfw ddr4_1d.fw --ddrfw ddr4_2d.fw --ddrfw ddr3_1d.fw \
			       --ddrfw piei.fw --ddrfw lpddr4_1d.fw --ddrfw lpddr4_2d.fw \
			       --ddrfw diag_lpddr4.fw --ddrfw aml_ddr.fw --ddrfw lpddr3_1d.fw \
			       ${O}/u-boot.bin;\
	else \
		${GXLIMG_PATH} -t fip --rev v3 \
			       --bl2 ${TMP}/bl2.n.bin.sig --bl30 ${TMP}/bl30_new.bin.enc \
			       --bl31 ${TMP}/bl31.img.enc --bl33 ${TMP}/bl33.bin.enc \
			       --ddrfw ddr4_1d.fw --ddrfw ddr4_2d.fw --ddrfw ddr3_1d.fw \
			       --ddrfw piei.fw --ddrfw lpddr4_1d.fw --ddrfw lpddr4_2d.fw \
			       --ddrfw diag_lpddr4.fw --ddrfw aml_ddr.fw \
			       ${O}/u-boot.bin;\
	fi
else
${TMP}/bl30_new.bin.g12a.enc: ${TMP}/bl30_new.bin
	${QEMU} ./${AML_ENCRYPT} --bl30sig --input ${TMP}/bl30_new.bin --output ${TMP}/bl30_new.bin.g12a.enc --level v3

${TMP}/bl30_new.bin.enc: ${TMP}/bl30_new.bin.g12a.enc
	${QEMU} ./${AML_ENCRYPT} --bl3sig --input ${TMP}/bl30_new.bin.g12a.enc --output ${TMP}/bl30_new.bin.enc --level v3 --type bl30

${TMP}/bl31.img.enc: bl31.img
	${QEMU} ./${AML_ENCRYPT} --bl3sig --input bl31.img --output ${TMP}/bl31.img.enc --level v3 --type bl31

${TMP}/bl33.bin.enc: ${BL33}
	${QEMU} ./${AML_ENCRYPT} --bl3sig --input ${BL33} --output ${TMP}/bl33.bin.enc --level v3 --type bl33 ${BL33_ARGS}

${TMP}/bl2.n.bin.sig: ${TMP}/bl2_new.bin
	${QEMU} ./${AML_ENCRYPT} --bl2sig --input ${TMP}/bl2_new.bin --output ${TMP}/bl2.n.bin.sig

${O}/u-boot.bin: ${TMP}/bl2.n.bin.sig ${TMP}/bl30_new.bin.enc ${TMP}/bl31.img.enc ${TMP}/bl33.bin.enc
	if [ -e lpddr3_1d.fw ] ; then \
		${QEMU} ./${AML_ENCRYPT} --bootmk --output ${O}/u-boot.bin --level v3 \
			       --bl2 ${TMP}/bl2.n.bin.sig --bl30 ${TMP}/bl30_new.bin.enc \
			       --bl31 ${TMP}/bl31.img.enc --bl33 ${TMP}/bl33.bin.enc \
			       --ddrfw1 ddr4_1d.fw --ddrfw2 ddr4_2d.fw --ddrfw3 ddr3_1d.fw \
			       --ddrfw4 piei.fw --ddrfw5 lpddr4_1d.fw --ddrfw6 lpddr4_2d.fw \
			       --ddrfw7 diag_lpddr4.fw --ddrfw8 aml_ddr.fw --ddrfw9 lpddr3_1d.fw ;\
	else \
		${QEMU} ./${AML_ENCRYPT} --bootmk --output ${O}/u-boot.bin --level v3 \
			       --bl2 ${TMP}/bl2.n.bin.sig --bl30 ${TMP}/bl30_new.bin.enc \
			       --bl31 ${TMP}/bl31.img.enc --bl33 ${TMP}/bl33.bin.enc \
			       --ddrfw1 ddr4_1d.fw --ddrfw2 ddr4_2d.fw --ddrfw3 ddr3_1d.fw \
			       --ddrfw4 piei.fw --ddrfw5 lpddr4_1d.fw --ddrfw6 lpddr4_2d.fw \
			       --ddrfw7 diag_lpddr4.fw --ddrfw8 aml_ddr.fw ;\
	fi
ifneq ($(AML_USER_SIG),)
	${QEMU} ./${AML_ENCRYPT} --bootsig \
		       --input ${O}/u-boot.bin \
		       --amluserkey ${AML_USER_SIG} \
		       --aeskey enable \
		       --output ${O}/u-boot.bin.encrypt \
		       --level 3
endif
endif
