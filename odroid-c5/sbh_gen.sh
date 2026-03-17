#!/bin/bash

meta_size=272
meta_cnt=2
crc_offset=1020
hdr_size=4096

Usage() {
  echo "Usage: $0 < input > output"
}

calc_CRC() {
  hex_str=${1}
  crc=0x1ad7bc43
  for ((i=0;i<${#hex_str};i+=8)); do
    hex=${hex_str:${i}:8}
    hex=${hex:6:2}${hex:4:2}${hex:2:2}${hex:0:2}
    crc=$(($crc + 0x$hex))
  done

  echo $crc
}

gen_header() {
  meta=`dd bs=1 status=none | xxd -p`
  meta=${meta//[[:space:]]/}
#echo ${meta}
#echo ${#meta}
  if [ ${#meta} != $((${meta_size} * ${meta_cnt} * 2)) ]; then
    echo "Error: Input data size error."
    return
  fi

  crc=$(calc_CRC ${meta})
  crc=$(printf "%x" $crc)
  crc=${crc:(-8)}
  crc=${crc:6:2}${crc:4:2}${crc:2:2}${crc:0:2}
#echo $crc

  echo ${meta} | xxd -r -p
  dd if=/dev/zero bs=1 count=$((${crc_offset} - ${#meta} / 2)) status=none
  echo ${crc} | xxd -r -p
  dd if=/dev/zero bs=1 count=$((${hdr_size} - ${crc_offset} - ${#crc} / 2)) status=none
}

main() {
    gen_header $@
}

main $@
