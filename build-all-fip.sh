#!/bin/sh

if [ -z "$1" ] ; then
	echo "Usage: $0: <bl33/u-boot.bin path>"
	exit 1
fi

BOARDS=`find -maxdepth 1 -type d -iname "[a-z0-9]*" -exec basename {} \;`

TMP=`mktemp -d`
TMPB=`mktemp -d`

for board in $BOARDS; do
	if [ ! -e $board/Makefile ] ; then
		printf "[%20s]	Missing Makefile	[\033[0;35mTOFIX\033[0m]\n" $board
		continue
	fi
	./build-fip.sh $board $1 $TMP $TMPB > /dev/null 2>&1
	ERR=$?
	if [ $ERR -gt 0 ] ; then
		printf "[%20s]	Build			[\033[0;31mFAIL\033[0m]\n" $board
	else
		if [ -e $TMP/u-boot.bin -a -e $TMP/u-boot.bin.sd.bin -a -e $TMP/u-boot.bin.usb.bl2 -a -e $TMP/u-boot.bin.usb.tpl ] ; then
			printf "[%20s]	Build			[\033[0;32mOK\033[0m]\n" $board
		else
			printf "[%20s]	Build			[\033[0;31mMISSING OUTPUT\033[0m]\n" $board
			ls $TMP
		fi
	fi

	rm -fr $TMP/*
	rm -fr $TMPB/*
done

rm -fr $TMP
rm -fr $TMPB
