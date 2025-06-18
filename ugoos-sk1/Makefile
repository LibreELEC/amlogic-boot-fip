O ?= .
TMP ?= .
BL33 ?=
COMPRESS_LZ4 ?= 0

ifeq ($(COMPRESS_LZ4),0)
	BL33_ARGS :=
else
	BL33_ARGS :=--compress lz4
endif

AML_ENCRYPT = aml_encrypt_g12b

.PHONY: clean distclean
.NOTPARALLEL: ${TMP}/bl30_new.bin.g12a.enc ${TMP}/bl30_new.bin.enc ${TMP}/bl31.img.enc ${TMP}/bl33.bin.enc ${TMP}/bl2.n.bin.sig ${O}/u-boot.bin

all: ${O}/u-boot.bin

clean:
	rm -f ${TMP}/bl30_new.bin.g12a.enc ${TMP}/bl30_new.bin.enc
	rm -f ${TMP}/bl31.img.enc ${TMP}/bl33.bin.enc
	rm -f ${TMP}/bl21_zero.bin ${TMP}/bl2_zero.bin
	rm -f ${TMP}/bl301_zero.bin ${TMP}/bl30_zero.bin ${TMP}/bl2.n.bin.sig

distclean: clean
	rm -f ${O}/u-boot.bin ${O}/u-boot.bin.sd.bin ${O}/u-boot.bin.usb.bl2 ${O}/u-boot.bin.usb.tpl

ifneq ($(GXLIMG_PATH),)
${TMP}/bl30_new.bin.enc: bl30_new.bin
	${GXLIMG_PATH} -t bl30 -s bl30_new.bin ${TMP}/bl30_new.bin.enc

${TMP}/bl31.img.enc: bl31.img
	${GXLIMG_PATH} -t bl3x -s bl31.img ${TMP}/bl31.img.enc

${TMP}/bl33.bin.enc: ${BL33}
	${GXLIMG_PATH} -t bl3x -s ${BL33} ${TMP}/bl33.bin.enc

${TMP}/bl2.n.bin.sig: bl2_new.bin
	${GXLIMG_PATH} -t bl2 -s bl2_new.bin ${TMP}/bl2.n.bin.sig

${O}/u-boot.bin: ${TMP}/bl2.n.bin.sig ${TMP}/bl30_new.bin.enc ${TMP}/bl31.img.enc ${TMP}/bl33.bin.enc
	${GXLIMG_PATH} -t fip --rev v3 \
		       --bl2 ${TMP}/bl2.n.bin.sig --bl30 ${TMP}/bl30_new.bin.enc \
		       --bl31 ${TMP}/bl31.img.enc --bl33 ${TMP}/bl33.bin.enc \
		       --ddrfw piei.fw --ddrfw lpddr4_1d.fw --ddrfw lpddr4_2d.fw \
		       --ddrfw diag_lpddr4.fw --ddrfw aml_ddr.fw \
		       ${O}/u-boot.bin;
else
${TMP}/bl30_new.bin.g12a.enc: bl30_new.bin
	./${AML_ENCRYPT} --bl30sig --input bl30_new.bin --output ${TMP}/bl30_new.bin.g12a.enc --level v3

${TMP}/bl30_new.bin.enc: ${TMP}/bl30_new.bin.g12a.enc
	./${AML_ENCRYPT} --bl3sig --input ${TMP}/bl30_new.bin.g12a.enc --output ${TMP}/bl30_new.bin.enc --level v3 --type bl30

${TMP}/bl31.img.enc: bl31.img
	./${AML_ENCRYPT} --bl3sig --input bl31.img --output ${TMP}/bl31.img.enc --level v3 --type bl31

${TMP}/bl33.bin.enc: ${BL33}
	./${AML_ENCRYPT} --bl3sig --input ${BL33} --output ${TMP}/bl33.bin.enc --level v3 --type bl33 ${BL33_ARGS}

${TMP}/bl2.n.bin.sig: bl2_new.bin
	./${AML_ENCRYPT} --bl2sig --input bl2_new.bin --output ${TMP}/bl2.n.bin.sig

${O}/u-boot.bin: ${TMP}/bl2.n.bin.sig ${TMP}/bl30_new.bin.enc ${TMP}/bl31.img.enc ${TMP}/bl33.bin.enc
	./${AML_ENCRYPT} --bootmk --output ${O}/u-boot.bin --level v3 \
		       --bl2 ${TMP}/bl2.n.bin.sig --bl30 ${TMP}/bl30_new.bin.enc \
		       --bl31 ${TMP}/bl31.img.enc --bl33 ${TMP}/bl33.bin.enc \
		       --ddrfw1 piei.fw --ddrfw2 lpddr4_1d.fw --ddrfw3 lpddr4_2d.fw \
		       --ddrfw4 diag_lpddr4.fw --ddrfw5 aml_ddr.fw ;
endif
