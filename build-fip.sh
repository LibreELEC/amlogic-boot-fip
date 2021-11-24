#!/bin/sh

if [ -z "$1" -o -z "$2" ] ; then
	echo "Usage: $0: <board model> <bl33/u-boot.bin path> [output directory] [temporary directory]"
	exit 1
fi

if [ ! -d $1 ] ; then
	echo "Invalid board name \"$1\""
	exit 1
fi

if [ ! -e $2 ] ; then
	echo "Invalid bl33/u-boot file \"$2\""
	exit 1
fi

BL33=`readlink -f $2`

ARGS="BL33=$BL33"

if [ -n "$3" ] ; then
	OUT=`readlink -f $3`
	ARGS="$ARGS O=$OUT"
fi

if [ -n "$3" -a -e "$4" ] ; then
	TMP=`readlink -f $4`
else
	TMP=`mktemp -d`
fi

make -C `basename $1` $ARGS TMP=$TMP
ERR=$?

if ! [ -n "$3" -a -e "$4" ] ; then
	rm -fr $TMP
fi

exit $ERR
