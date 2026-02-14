#!/bin/bash
set -e

# Check args
if [ $# -lt 2 ]; then
    echo "Usage: bl33-compress.sh <bl33_in> <bl33z_in> <bl33_out>"
    exit 1
fi

BL33_IN="${1}" # u-boot input
BL33Z_IN="${2}"
BL33_OUT="${3}"
BL33_PAD="${BL33_OUT}.pad"
BL33_COMB="${BL33_OUT}.comb"
BL33_ZSTD="${BL33_OUT}.zstd"
BL33_HDR="${BL33_OUT}.hdr"

cleanup()
{
    rm -f "${BL33_PAD}" "${BL33_COMB}" "${BL33_ZSTD}" "${BL33_HDR}"
}
trap cleanup 0

# Pad u-boot (BL33) to a multiple of 4096
BL33_SIZE=$(stat -c '%s' ${BL33_IN})
BL33_PAD_SIZE=$[(BL33_SIZE + 4095) / 4096 * 4096]
./pad.sh "${BL33_IN}" "${BL33_PAD}" "${BL33_PAD_SIZE}"

# Combine padded BL33 + BL33Z
cat "${BL33_PAD}" "${BL33Z_IN}" > "${BL33_COMB}"

# Compress results
zstd "${BL33_COMB}" -9 -o "${BL33_ZSTD}"

# Sizes before/after compression
BEFORE_SIZE=$(stat -c '%s' "${BL33_COMB}")
AFTER_SIZE=$(stat -c '%s' "${BL33_ZSTD}")

# Generate header w/ sizes before and after
printf '%s' ZSTD > "${BL33_HDR}"
printf "%02x%02x%02x%02x" $[ (BEFORE_SIZE) & 0xff] \
       $[(BEFORE_SIZE >> 8) & 0xff] $[(BEFORE_SIZE >> 16) & 0xff] \
       $[(BEFORE_SIZE >> 24) & 0xff] | xxd -r -ps >> "${BL33_HDR}"
printf "%02x%02x%02x%02x" $[ AFTER_SIZE & 0xff] \
	$[(AFTER_SIZE >> 8) & 0xff] $[(AFTER_SIZE >> 16) & 0xff] \
	$[(AFTER_SIZE >> 24) & 0xff] | xxd -r -ps >> "${BL33_HDR}"

# Combine header + compressed data
cat "${BL33_ZSTD}" >> "${BL33_HDR}"
mv "${BL33_HDR}" "${BL33_COMB}"

# Pad results to final size
./pad.sh "${BL33_COMB}" "${BL33_OUT}" 1572864
