#!/bin/bash

function mk_uboot() {
	output_images=$1
	input_payloads=$2
	postfix=$3
	storage_type_suffix=$4
	chipset_variant_suffix=$5

	device_fip="${input_payloads}/device-fip.bin${postfix}"
	bb1st="${input_payloads}/bb1st${storage_type_suffix}${chipset_variant_suffix}.bin${postfix}"
	bl2e="${input_payloads}/blob-bl2e${storage_type_suffix}${chipset_variant_suffix}.bin${postfix}"
	bl2x="${input_payloads}/blob-bl2x.bin${postfix}"

	if [ ! -f ${device_fip} ] || \
	   [ ! -f ${bb1st} ] || \
	   [ ! -f ${bl2e} ] || \
	   [ ! -f ${bl2x} ]; then
		echo fip:${device_fip}
		echo bb1st:${bb1st}
		echo bl2e:${bl2e}
		echo bl2x:${bl2x}
		echo "Error: ${input_payloads}/ bootblob does not all exist... abort"
		ls -la ${input_payloads}/
		exit -1
	fi

	attach_blob_hdr ${bb1st}
	if [ "$CONFIG_DYNAMIC_SZ" == "y" ] ; then
		local bl2e_sz=`stat -c "%s" ${bl2e}`
		local bl2x_sz=`stat -c "%s" ${bl2x}`
		if [ "$CONFIG_BL2E_96K" == "y" ] && [ "$bl2e_sz" -lt "116912" ]; then
			dd if=/dev/zero of=${bl2e}.max bs=1 count=116912 &> /dev/null
			dd if=${bl2e} of=${bl2e}.max conv=notrunc &> /dev/null
			bl2e=${bl2e}.max
		elif [ "$CONFIG_BL2E_128K" == "y" ] && [ "$bl2e_sz" -lt "149680" ]; then
			dd if=/dev/zero of=${bl2e}.max bs=1 count=149680 &> /dev/null
			dd if=${bl2e} of=${bl2e}.max conv=notrunc &> /dev/null
			bl2e=${bl2e}.max
		elif [ "$CONFIG_BL2E_256K" == "y" ] && [ "$bl2e_sz" -lt "280752" ]; then
			dd if=/dev/zero of=${bl2e}.max bs=1 count=280752 &> /dev/null
			dd if=${bl2e} of=${bl2e}.max conv=notrunc &> /dev/null
			bl2e=${bl2e}.max
		elif [ "$CONFIG_BL2E_1024K" == "y" ] && [ "$bl2e_sz" -lt "1067184" ]; then
			dd if=/dev/zero of=${bl2e}.max bs=1 count=1067184 &> /dev/null
			dd if=${bl2e} of=${bl2e}.max conv=notrunc &> /dev/null
			bl2e=${bl2e}.max
		fi

		if [ "$bl2x_sz" -lt "108720" ]; then
			dd if=/dev/zero of=${bl2x}.max bs=1 count=108720 &> /dev/null
			dd if=${bl2x} of=${bl2x}.max conv=notrunc &> /dev/null
			bl2x=${bl2x}.max
		fi
	fi
	file_info_cfg="${output_images}/aml-payload.cfg"
	file_info_cfg_temp=${temp_cfg}.temp

	bootloader="${output_images}/u-boot.bin${storage_type_suffix}${postfix}"
	#sdcard_image="${output_images}/u-boot.bin.sd.bin${postfix}"

	#fake ddr fip 256KB
	ddr_fip="${input_payloads}/ddr-fip.bin"
	if [ ! -f ${ddr_fip} ]; then
		echo "==== use empty ddr-fip ===="
		dd if=/dev/zero of=${ddr_fip} bs=1024 count=256 status=none
	fi

	#cat those together with 4K upper aligned for sdcard
	align_base=4096
	total_size=0
	for file in ${bb1st} ${bl2e} ${bl2x} ${ddr_fip} ${device_fip}; do
		size=`stat -c "%s" ${file}`
		upper=$[(size+align_base-1)/align_base*align_base]
		total_size=$[total_size+upper]
		echo ${file} ${size} ${upper}
	done

	echo ${total_size}
	rm -f ${bootloader}
	dd if=/dev/zero of=${bootloader} bs=${total_size} count=1 status=none

	sector=512
	seek=0
	seek_sector=0
	dateStamp=S7D-${CHIPSET_NAME}-`date +%y%m%d%H%M%S`

	echo @AMLBOOT > ${file_info_cfg_temp}
	dd if=${file_info_cfg_temp} of=${file_info_cfg} bs=1 count=8 conv=notrunc &> /dev/null
	nItemNum=5
	nSizeHDR=$[64+nItemNum*16]
	printf "02 %02x %02x %02x" $[(nItemNum)&0xFF] $[(nSizeHDR)&0xFF] $[((nSizeHDR)>>8)&0xFF] \
		| xxd -r -ps > ${file_info_cfg_temp}
	cat ${file_info_cfg_temp} >> ${file_info_cfg}

	echo ${dateStamp} > ${file_info_cfg_temp}
	dd if=${file_info_cfg_temp} of=${file_info_cfg} bs=1 count=20 oflag=append conv=notrunc &> /dev/null

	index=0
	arrPayload=("BBST" "BL2E" "BL2X" "DDRF" "DEVF");
	nPayloadOffset=0
	nPayloadSize=0
	for file in ${bb1st} ${bl2e} ${bl2x} ${ddr_fip} ${device_fip}; do
		size=`stat -c "%s" ${file}`
		size_sector=$[(size+align_base-1)/align_base*align_base]
		nPayloadSize=$[size_sector]
		size_sector=$[size_sector/sector]
		seek_sector=$[seek/sector+seek_sector]
		#nPayloadOffset=$[sector*(seek_sector+1)]
		nPayloadOffset=$[sector*(seek_sector)]
		echo ${file} ${seek_sector} ${size_sector} $[sector*(seek_sector)]
		dd if=${file} of=${bootloader} bs=${sector} seek=${seek_sector} conv=notrunc status=none

		echo ${arrPayload[$index]} > ${file_info_cfg_temp}.x
		index=$((index+1))
		dd if=${file_info_cfg_temp}.x of=${file_info_cfg_temp} bs=1 count=4 &> /dev/null
		rm -f ${file_info_cfg_temp}.x
		printf "%02x %02x %02x %02x %02x %02x %02x %02x 00 00 00 00" $[(nPayloadOffset)&0xFF] $[((nPayloadOffset)>>8)&0xFF] $[((nPayloadOffset)>>16)&0xFF] $[((nPayloadOffset)>>24)&0xFF] \
		$[(nPayloadSize)&0xFF] $[((nPayloadSize)>>8)&0xFF] $[((nPayloadSize)>>16)&0xFF] $[((nPayloadSize)>>24)&0xFF] | xxd -r -ps >> ${file_info_cfg_temp}
		dd if=${file_info_cfg_temp} of=${file_info_cfg} oflag=append conv=notrunc &> /dev/null
		rm -f ${file_info_cfg_temp}
		seek=$[(size+align_base-1)/align_base*align_base]
	done

	openssl dgst -sha256 -binary ${file_info_cfg} > ${file_info_cfg}.sha256
	cat ${file_info_cfg} >> ${file_info_cfg}.sha256
	#cat ${file_info_cfg}.sha256 >> ${file_info_cfg}
	rm -f ${file_info_cfg}
	mv -f ${file_info_cfg}.sha256 ${file_info_cfg}

	dd if=${file_info_cfg} of=${bootloader} bs=512 seek=540 conv=notrunc status=none
	dd if=hdr_revA of=${bootloader} bs=512 seek=543 conv=notrunc status=none

	if [ ${storage_type_suffix} == ".sto" ]; then
		#echo "Image SDCARD"
		#total_size=$[total_size+512]
		#rm -f ${sdcard_image}
		#dd if=/dev/zero of=${sdcard_image} bs=${total_size} count=1 status=none
		#dd if=${file_info_cfg}   of=${sdcard_image} conv=notrunc status=none
		#dd if=${bootloader} of=${sdcard_image} bs=512 seek=1 conv=notrunc status=none
		mv ${bootloader} ${output_images}/u-boot.bin${postfix}
	fi

	rm -f ${file_info_cfg}
}

function attach_blob_hdr () {
	local bb1st_folder=${MAIN_FOLDER}/$1
	local bl2_size=`stat -c "%s" $bb1st_folder`

	if [ "${bl2_size}" -le "${BL2_MAX_SIZE}" ]; then
		dd if=/dev/zero of=${bb1st_folder}.max bs=1024 count=266 status=none
		dd if=${bb1st_folder} of=${bb1st_folder}.max  bs=1 count=${bl2_size} conv=notrunc
		bb1st_folder=${bb1st_folder}.max
	fi

	./attach_sbh.sh $bb1st_folder $bb1st_folder.hdr
	bb1st_folder=$bb1st_folder.hdr

	bb1st=${bb1st_folder}
}

CONFIG_DYNAMIC_SZ=y
CONFIG_BL2E_96K=y
BL2_MAX_SIZE=272384
mk_uboot "$1" "$2" "$3" "$4" "$5"
