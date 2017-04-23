#!/bin/bash
# Copyright (C) 2011 Samsung Electronics Co., Ltd.
#              http://www.samsung.com/
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
####################################
signed_bl1_position=0
bl2_position=30
uboot_position=62
tzsw_position=2110
device=/dev/$1boot0

function flash_bootloder () {
####################################
# fusing images

#<BL1 fusing>
echo "BL1 fusing"
dd if=./bl1.HardKernel of=$device seek=$signed_bl1_position

#<BL2 fusing>
echo "BL2 fusing"
dd if=./bl2.HardKernel of=$device seek=$bl2_position

#<u-boot fusing>
echo "u-boot fusing"
dd if=./u-boot.bin of=$device seek=$uboot_position

#<TrustZone S/W fusing>
echo "TrustZone S/W fusing"
dd if=./tzsw.HardKernel of=$device seek=$tzsw_position

####################################
#<Message Display>
echo "U-boot image is fused successfully."
}

if [ -z $1 ]
then
    echo "usage: ./emmc_fusing.sh <device file>"
    exit 0
fi

if [ -b "/dev/$1" ]
then
    echo "$1 reader is identified."
else
    echo "$1 is NOT identified."
    exit 0
fi

if [ -d /sys/block/$1boot0 ]; then
    echo "$1 is an eMMC card, disabling $1boot0 ro"
    if ! echo 0 > /sys/block/$1boot0/force_ro; then
	echo "Enabling r/w for $1boot0 failed"
	exit 1
    fi
    emmc=1
    flash_bootloder
    echo 1 > /sys/block/$1boot0/force_ro
fi

function create_partition () {
        fdisk /dev/$1 <<END
        n
        p
        1


        w
        q
END
}

function device_not_found_error () {
        echo "Given device not found!"
        echo "please check dmesg for verification"
}

function flash_kernel_rootfs () {
        echo "partition found"
        sudo umount /dev/$1p1
        sudo mkfs.ext4 /dev/$1p1
        sudo mkdir -p /mnt/tmp
        sudo mount /dev/$1p1 /mnt/tmp
        sudo tar -xzvf debian.tgz --warning=no-timestamp -C /mnt/tmp/
        sudo cp zImage /mnt/tmp/zImage
	sudo fw_setenv bootcmd 'ext4load mmc 1:1 0x40008000 zImage;bootm 0x40008000'
	sudo fw_setenv bootargs 'console=tty1 console=ttySAC1,115200 mem=1023M root=/dev/mmcblk1p1 rootwait rw drm_kms_helper.edid_firmware=edid/1920x1080.bin'
        sync
        sudo umount /dev/$1p1
}

if [ -b "/dev/$1p1" ]; then
        flash_kernel_rootfs $1
        echo "eMMC flashed"
        echo "Power off the board"
        echo "Set emmc boot mode boot board"
        echo "Good luck!"
else
        echo "partition not found!"
        if [ -b "/dev/$1" ]; then
                create_partition $1
                flash_kernel_rootfs $1
        else
                device_not_found_error
        fi
fi
