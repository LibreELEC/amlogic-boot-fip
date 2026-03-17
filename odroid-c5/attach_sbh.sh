#!/bin/bash

HDR_BASEDIR=$(dirname $(readlink -f $0))

Usage() {
  echo "Usage: $0 img_file img_file_with_header"
}

main() {
  if [ "$#" != "2" ]; then
    Usage
    return
  fi

  if [ ! -f $1 ]; then
    echo "Error: Image file does not exist!!!"
    return
  fi

  source ${HDR_BASEDIR}/bb1_extract_meta.sh $1 | source ${HDR_BASEDIR}/sbh_gen.sh > $2
  cat $1 >> $2
}

main $@
