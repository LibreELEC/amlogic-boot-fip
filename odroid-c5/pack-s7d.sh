#!/bin/sh
#
# Pack S7D boot blobs into a bootable image with an @AMLBOOT payload table,
# following mk_uboot() and attach_blob_hdr() in the vendor fip/s7d/build.sh
#
# Usage: pack-s7d.sh <output> <bb1st> <bl2e> <bl2x> <ddr-fip> <device-fip> [sd-output]

set -e

if [ $# -lt 6 ] ; then
	echo "Usage: $0 <output> <bb1st> <bl2e> <bl2x> <ddr-fip> <device-fip> [sd-output]"
	exit 1
fi

OUT=$1
SD_OUT=$7
BB1ST=$2
shift 2
BLOBS="$1 $2 $3 $4"
TAGS="BBST BL2E BL2X DDRF DEVF"

ALIGN=4096
SECTOR=512
# the payload table and hdr_revA live in the bb1st padding
HDR_SECTOR=540
REVA_SECTOR=543

BL2_MAX=272384
SBH_SIZE=4096
SBH_META=272
SBH_CRC=1020

if [ -n "${SOURCE_DATE_EPOCH}" ] ; then
	STAMP=S7D-s905x5m-$(date -u -d @${SOURCE_DATE_EPOCH} +%y%m%d%H%M%S)
else
	STAMP=S7D-s905x5m-$(date +%y%m%d%H%M%S)
fi

aligned() {
	size=$(stat -c %s $1)
	echo $(( (size + ALIGN - 1) / ALIGN * ALIGN ))
}

le16_at() {
	od -An -tu1 -j $2 -N 2 $1 | awk '{ print $1 + $2 * 256 }'
}

le32() {
	printf "%02x %02x %02x %02x" $(($1 & 0xff)) $((($1 >> 8) & 0xff)) \
		$((($1 >> 16) & 0xff)) $((($1 >> 24) & 0xff)) | xxd -r -p
}

TMPD=$(mktemp -d)
trap 'rm -rf ${TMPD}' EXIT

# pad bb1st to the bl2 maximum and prepend a 4K secure boot header holding
# the two 272-byte metadata blocks of bb1st and their checksum
if [ $(stat -c %s ${BB1ST}) -gt ${BL2_MAX} ] ; then
	echo "bb1st exceeds ${BL2_MAX} bytes"
	exit 1
fi
dd if=/dev/zero of=${TMPD}/bb1st bs=${BL2_MAX} count=1 status=none
dd if=${BB1ST} of=${TMPD}/bb1st conv=notrunc status=none

offset=$(le16_at ${TMPD}/bb1st 12)
offset=$((offset + $(le16_at ${TMPD}/bb1st $((offset + 12)))))
offset=$((offset + $(le16_at ${TMPD}/bb1st $((offset + 12)))))

dd if=${TMPD}/bb1st of=${TMPD}/meta bs=${SBH_META} count=1 status=none
dd if=${TMPD}/bb1st bs=1 skip=${offset} count=${SBH_META} status=none >> ${TMPD}/meta
crc=$(od -An -tu1 -v ${TMPD}/meta | awk -v crc=$((0x1ad7bc43)) '
	BEGIN { n = 0 }
	{ for (i = 1; i <= NF; i++) {
		crc += $i * 256 ^ (n % 4); n++
	} }
	END { printf "%.0f", crc % 4294967296 }')

dd if=/dev/zero of=${TMPD}/bb1st.hdr bs=${SBH_SIZE} count=1 status=none
dd if=${TMPD}/meta of=${TMPD}/bb1st.hdr conv=notrunc status=none
le32 ${crc} | dd of=${TMPD}/bb1st.hdr bs=1 seek=${SBH_CRC} conv=notrunc status=none
cat ${TMPD}/bb1st >> ${TMPD}/bb1st.hdr

BLOBS="${TMPD}/bb1st.hdr ${BLOBS}"

total=0
for blob in ${BLOBS} ; do
	total=$((total + $(aligned ${blob})))
done

CFG=${TMPD}/cfg

dd if=/dev/zero of=${OUT} bs=${total} count=1 status=none

ITEMS=5
HDR_SIZE=$((64 + ITEMS * 16))
printf "@AMLBOOT" > ${CFG}
printf "02 %02x %02x %02x" ${ITEMS} $((HDR_SIZE & 0xff)) \
	$(((HDR_SIZE >> 8) & 0xff)) | xxd -r -p >> ${CFG}
printf "%-20.20s" "${STAMP}" >> ${CFG}

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
dd if=$(dirname $0)/hdr_revA of=${OUT} bs=${SECTOR} seek=${REVA_SECTOR} conv=notrunc status=none

if [ -n "${SD_OUT}" ] ; then
	dd if=/dev/zero of=${SD_OUT} bs=$((total + SECTOR)) count=1 status=none
	dd if=${CFG}.sha of=${SD_OUT} conv=notrunc status=none
	dd if=${OUT} of=${SD_OUT} bs=${SECTOR} seek=1 conv=notrunc status=none
fi
