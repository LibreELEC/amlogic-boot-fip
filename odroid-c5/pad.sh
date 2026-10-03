#!/bin/bash
set -e

# Check args
if [ $# -lt 3 ]; then
    echo "Usage: pad.sh <in_path> <out_path> <size>"
    exit 1
fi

IN_FILE="${1}"
IN_SIZE=$(stat -c '%s' "${IN_FILE}")
OUT_FILE="${2}"
OUT_SIZE="${3}"
TMP_FILE="${OUT_FILE}.tmp"

dd if=/dev/zero of="${TMP_FILE}" bs="${OUT_SIZE}" count=1 status=none
dd if="${IN_FILE}" of="${TMP_FILE}" conv=notrunc status=none

mv "${TMP_FILE}" "${OUT_FILE}"

