#!/bin/sh
#
# Pack DDR training firmware into a 256K ddr-fip.bin with an @DFM header,
# following mk_ddr_fip() in the vendor fip/t7/build.sh
#
# Usage: mk-ddr-fip.sh <output> <fw>:<magic> [<fw>:<magic> ...]

set -e

if [ $# -lt 2 ] ; then
	echo "Usage: $0 <output> <fw>:<magic> [<fw>:<magic> ...]"
	exit 1
fi

OUT=$1
shift

HDR_MAX=4096
FIP_MAX=258048
FW_ALIGN=4096
# 32K IMEM + 4K DMEM
FW_MAX=36864
# vendor header in front of each .fw file
FW_SKIP=96
HDR_SIZE=64

le16() {
	printf "%02x %02x" $(($1 & 0xff)) $((($1 >> 8) & 0xff)) | xxd -r -p
}

le32() {
	printf "%02x %02x %02x %02x" $(($1 & 0xff)) $((($1 >> 8) & 0xff)) \
		$((($1 >> 16) & 0xff)) $((($1 >> 24) & 0xff)) | xxd -r -p
}

zeros() {
	dd if=/dev/zero bs=$1 count=1 status=none
}

HDR=$(mktemp)
FIP=$(mktemp)
FW=$(mktemp)
trap 'rm -f ${HDR} ${FIP} ${FW}' EXIT

printf "@DFM" > ${HDR}
le16 $# >> ${HDR}
zeros 10 >> ${HDR}

: > ${FIP}
offset=${HDR_MAX}
for item in "$@" ; do
	file=${item%:*}
	magic=${item##*:}

	size=$(stat -c %s ${file})
	size=$(( (size + FW_ALIGN - 1) / FW_ALIGN * FW_ALIGN ))
	if [ ${size} -gt ${FW_MAX} ] ; then
		size=${FW_MAX}
	fi

	dd if=/dev/zero of=${FW} bs=${size} count=1 status=none
	dd if=${file} of=${FW} bs=1 skip=${FW_SKIP} count=${size} \
		conv=notrunc status=none
	cat ${FW} >> ${FIP}

	printf "@DFM" >> ${HDR}
	zeros 2 >> ${HDR}
	le16 ${HDR_SIZE} >> ${HDR}
	le32 ${offset} >> ${HDR}
	le32 ${size} >> ${HDR}
	zeros 4 >> ${HDR}
	printf "%-4.4s" ${magic} >> ${HDR}
	zeros 8 >> ${HDR}
	openssl dgst -sha256 -binary ${FW} >> ${HDR}

	offset=$((offset + size))
done

if [ $(stat -c %s ${HDR}) -gt ${HDR_MAX} ] ; then
	echo "ddr-fip header exceeds ${HDR_MAX} bytes"
	exit 1
fi
if [ $(stat -c %s ${FIP}) -gt ${FIP_MAX} ] ; then
	echo "ddr-fip firmware exceeds ${FIP_MAX} bytes"
	exit 1
fi

dd if=/dev/zero of=${OUT} bs=$((HDR_MAX + FIP_MAX)) count=1 status=none
dd if=${HDR} of=${OUT} conv=notrunc status=none
dd if=${FIP} of=${OUT} bs=${HDR_MAX} seek=1 conv=notrunc status=none
