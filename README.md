# amlogic-boot-fip

Firmware Image Pacakge (FIP) sources used to sign Amlogic u-boot binaries in LibreELEC images

## U-Boot/BL33 Firmware Packaging

```
Usage: ./build-fip.sh: <board model> <bl33/u-boot.bin path> [output directory] [temporary directory]
```

Pass the board name and the bl33/U-boot payload to generate a bootable binary.

Example:

```
$ mkdir my-output-dir
$ ./build-fip.sh lepotato /path/to/u-boot/u-boot.bin my-output-dir
make: Entering directory 'lepotato'
python3 acs_tool.py bl2.bin /tmp/tmp.xq7XhFy6rW/bl2_acs.bin acs.bin 0
ACS tool process done.
./blx_fix.sh /tmp/tmp.xq7XhFy6rW/bl2_acs.bin /tmp/tmp.xq7XhFy6rW/zero_tmp /tmp/tmp.xq7XhFy6rW/bl2_zero.bin bl21.bin /tmp/tmp.xq7XhFy6rW/bl21_zero.bin /tmp/tmp.xq7XhFy6rW/bl2_new.bin bl2
2916+0 records in
2916+0 records out
2916 bytes (2,9 kB, 2,8 KiB) copied, 0,00332667 s, 877 kB/s
5992+0 records in
5992+0 records out
5992 bytes (6,0 kB, 5,9 KiB) copied, 0,00695574 s, 861 kB/s
./aml_encrypt_gxl --bl2sig --input /tmp/tmp.xq7XhFy6rW/bl2_new.bin --output /tmp/tmp.xq7XhFy6rW/bl2.n.bin.sig
./blx_fix.sh bl30.bin /tmp/tmp.xq7XhFy6rW/zero_tmp /tmp/tmp.xq7XhFy6rW/bl30_zero.bin bl301.bin /tmp/tmp.xq7XhFy6rW/bl301_zero.bin /tmp/tmp.xq7XhFy6rW/bl30_new.bin bl30
2076+0 records in
2076+0 records out
2076 bytes (2,1 kB, 2,0 KiB) copied, 0,00238937 s, 869 kB/s
3176+0 records in
3176+0 records out
3176 bytes (3,2 kB, 3,1 KiB) copied, 0,00360341 s, 881 kB/s
./aml_encrypt_gxl --bl3enc --input /tmp/tmp.xq7XhFy6rW/bl30_new.bin --output /tmp/tmp.xq7XhFy6rW/bl30_new.bin.enc
./aml_encrypt_gxl --bl3enc --input bl31.img --output /tmp/tmp.xq7XhFy6rW/bl31.img.enc
./aml_encrypt_gxl --bl3enc --input /path/to/u-boot/u-boot.bin --output /tmp/tmp.xq7XhFy6rW/bl33.bin.enc
./aml_encrypt_gxl --bootmk --output /path/to/my-output-dir/u-boot.bin --level v3 \
               --bl2 /tmp/tmp.xq7XhFy6rW/bl2.n.bin.sig --bl30 /tmp/tmp.xq7XhFy6rW/bl30_new.bin.enc \
	       --bl31 /tmp/tmp.xq7XhFy6rW/bl31.img.enc --bl33 /tmp/tmp.xq7XhFy6rW/bl33.bin.enc
make: Leaving directory 'lepotato'
$ ls my-output-dir
u-boot.bin  u-boot.bin.sd.bin  u-boot.bin.usb.bl2  u-boot.bin.usb.tpl
```

System Requirements:
 - x86-64 Linux system
 - Python 3 (for GXBB, GXL & GXM boards only)
 - sh
 - make
 - readlink
 - mktemp
 - cat
 - dd

Open-source tools exist to replace the binary-only Amlogic tools:
 - https://github.com/afaerber/meson-tools (GXBB, GXL & GXM only)
 - https://github.com/repk/gxlimg (GXBB, GXL, GXM & AXG only)
 - https://github.com/angerman/meson64-tools (developed for G12B, should work on G12A & SM1)
