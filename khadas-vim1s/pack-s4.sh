#!/bin/sh
#
# Pack S4 boot blobs into a bootable image with an @AMLBOOT payload table,
# following mk_uboot() in the vendor fip/s4/build.sh
#
# Usage: pack-s4.sh <output> <bb1st> <bl2e> <bl2x> <ddr-fip> <device-fip> [sd-output]

set -e

if [ $# -lt 6 ] ; then
	echo "Usage: $0 <output> <bb1st> <bl2e> <bl2x> <ddr-fip> <device-fip> [sd-output]"
	exit 1
fi

OUT=$1
SD_OUT=$7
shift
BLOBS="$1 $2 $3 $4 $5"
TAGS="BBST BL2E BL2X DDRF DEVF"

ALIGN=4096
SECTOR=512
# the payload table lives in the bb1st padding, at sector 332
HDR_SECTOR=332

if [ -n "${SOURCE_DATE_EPOCH}" ] ; then
	STAMP=SC2-$(date -u -d @${SOURCE_DATE_EPOCH} +%Y%m%d%H%M%S)
else
	STAMP=SC2-$(date +%Y%m%d%H%M%S)
fi

aligned() {
	size=$(stat -c %s $1)
	echo $(( (size + ALIGN - 1) / ALIGN * ALIGN ))
}

le32() {
	printf "%02x %02x %02x %02x" $(($1 & 0xff)) $((($1 >> 8) & 0xff)) \
		$((($1 >> 16) & 0xff)) $((($1 >> 24) & 0xff)) | xxd -r -p
}

total=0
for blob in ${BLOBS} ; do
	total=$((total + $(aligned ${blob})))
done

CFG=$(mktemp)
trap 'rm -f ${CFG} ${CFG}.sha' EXIT

dd if=/dev/zero of=${OUT} bs=${total} count=1 status=none

ITEMS=5
HDR_SIZE=$((64 + ITEMS * 16))
printf "@AMLBOOT" > ${CFG}
printf "01 %02x %02x %02x 00 00 00 00" ${ITEMS} $((HDR_SIZE & 0xff)) \
	$(((HDR_SIZE >> 8) & 0xff)) | xxd -r -p >> ${CFG}
printf "%-16.16s" "${STAMP}" >> ${CFG}

offset=0
set -- ${TAGS}
for blob in ${BLOBS} ; do
	size=$(aligned ${blob})
	dd if=${blob} of=${OUT} bs=${SECTOR} seek=$((offset / SECTOR)) \
		conv=notrunc status=none
	printf "%s" $1 >> ${CFG}
	le32 ${offset} >> ${CFG}
	le32 ${size} >> ${CFG}
	le32 0 >> ${CFG}
	offset=$((offset + size))
	shift
done

openssl dgst -sha256 -binary ${CFG} > ${CFG}.sha
cat ${CFG} >> ${CFG}.sha

dd if=${CFG}.sha of=${OUT} bs=${SECTOR} seek=${HDR_SECTOR} conv=notrunc status=none

if [ -n "${SD_OUT}" ] ; then
	dd if=/dev/zero of=${SD_OUT} bs=$((total + SECTOR)) count=1 status=none
	dd if=${CFG}.sha of=${SD_OUT} conv=notrunc status=none
	dd if=${OUT} of=${SD_OUT} bs=${SECTOR} seek=1 conv=notrunc status=none
fi
