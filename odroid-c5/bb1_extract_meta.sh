#!/bin/bash

Usage() {
  echo "Usage: $0 input > output"
}

extract_meta() {
  img_file=${1}
  meta_size=272

  if [ "$#" == "0" ]; then
    echo "Error: No image file!!!"
  elif [ ! -f ${img_file} ]; then
    echo "Error: Image file does not exist!!!"
  fi

  meta1=`dd if=${img_file} bs=1 count=$meta_size status=none | xxd -p`
  meta1=${meta1//[[:space:]]/}

  block_size=0x${meta1:26:2}${meta1:24:2}
  block_offset=${block_size}
  #echo ${block_size}
  #echo ${block_offset}
  block_size=`dd if=${img_file} bs=1 count=4 skip=$((${block_offset} + 12)) status=none | xxd -p`
  block_size=0x${block_size:2:2}${block_size:0:2}
  block_offset=$((${block_offset} + ${block_size}))
#echo ${block_size}
#echo ${block_offset}
  block_size=`dd if=${img_file} bs=1 count=4 skip=$((${block_offset} + 12)) status=none | xxd -p`
  block_size=0x${block_size:2:2}${block_size:0:2}
  block_offset=$((${block_offset} + ${block_size}))
#echo ${block_size}
#echo ${block_offset}
#return

  meta2=`dd if=${img_file} bs=1 count=$meta_size skip=$block_offset status=none | xxd -p`
  meta2=${meta2//[[:space:]]/}

  echo ${meta1} | xxd -r -p
  echo ${meta2} | xxd -r -p
}

main() {
  if [ "$#" == "0" ]; then
    Usage
  else
    extract_meta $@
  fi
}

main $@
