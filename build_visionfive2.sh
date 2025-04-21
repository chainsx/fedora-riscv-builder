#!/bin/bash

get_visionfive_tools() {
    if [ ! -d $build_dir/visionfive-tools ]; then
        git clone https://github.com/starfive-tech/soft_3rdpart.git -b JH7110_VisionFive2_devel visionfive-tools
    fi
    cd visionfive-tools/spl_tool
    make
    cd $build_dir
}

build_kernel() {
    if [ ! -d $build_dir/visionfive-linux ]; then
        git clone --depth=1 https://github.com/starfive-tech/linux.git -b JH7110_VisionFive2_6.1.y_devel visionfive-linux
    fi
    cd visionfive-linux

    make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- starfive_visionfive2_defconfig
    make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j$(nproc)
    make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- modules_install INSTALL_MOD_PATH=kmod
    cd $build_dir
    cp -rfp visionfive-linux/kmod/lib/modules/* rootfs/lib/modules
}

build_u-boot() {
    if [ ! -d $build_dir/visionfive-u-boot ]; then
        git clone --depth=1 https://github.com/starfive-tech/u-boot.git -b JH7110_VisionFive2_devel-v3.9.3 visionfive-u-boot
    fi
    cd visionfive-u-boot
    make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- starfive_visionfive2_defconfig
    make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j$(nproc)

    $build_dir/visionfive-tools/spl_tool/spl_tool -c -f spl/u-boot-spl.bin
    cp spl/u-boot-spl.bin.normal.out $build_dir/firmware/visionfive-u-boot-spl.bin.normal.out
    cp spl/u-boot-spl.bin $build_dir/firmware/visionfive-u-boot-with-spl.bin

    cd $build_dir
}

build_opensbi() {
    if [ ! -d $build_dir/visionfive-opensbi ]; then
        git clone --depth=1 https://github.com/starfive-tech/opensbi.git -b JH7110_VisionFive2_devel visionfive-opensbi
    fi
    cd visionfive-opensbi
    make PLATFORM=generic FW_PIC=y CROSS_COMPILE=riscv64-linux-gnu- -j$(nproc)
    cp build/platform/generic/firmware/fw_dynamic.bin $build_dir/firmware
    cp build/platform/generic/firmware/fw_payload.bin $build_dir/firmware
    cd $build_dir
}

mk_img() {
    cd $build_dir
    device=""
    LOSETUP_D_IMG
    UMOUNT_ALL

    size=8192000 #4Gb

    losetup -D
    img_file=${build_dir}/sd.img
    dd if=/dev/zero of=${img_file} bs=512 count=$size status=progress && sync

    device=`losetup -f --show -P ${img_file}`
    trap 'LOSETUP_D_IMG' EXIT

    sfdisk ${device} < config/visionfive2-fdisk.cnf 

    kpartx -va ${device}
    loopX=${device##*\/}
    partprobe ${device}

    dd if=firmware/visionfive-u-boot-with-spl.bin of=/dev/${loopX}p1 bs=512 status=progress && sync    
    dd if=firmware/visionfive2_fw_payload.img of=/dev/${loopX}p2 bs=512 status=progress && sync    

    sdbootp=/dev/mapper/${loopX}p3
    sdrootp=/dev/mapper/${loopX}p4    

    mkfs.vfat -n fedora-boot ${sdbootp}
    mkfs.ext4 -L fedora-root ${sdrootp}
    mkdir -p ${root_mnt} ${boot_mnt}
    mount ${sdbootp} ${boot_mnt}
    mount ${sdrootp} ${root_mnt}

    if [ -d $boot_mnt/extlinux ]; then
        rm -rf $boot_mnt/extlinux
    fi

    mkdir -p $boot_mnt/extlinux

    line=$(blkid | grep $sdrootp)
    uuid=${line#*UUID=\"}
    uuid=${uuid%%\"*}
    
    echo "label Fedora
    kernel /Image
    initrd /initrd.img
    fdtdir /
    append  console=ttyS0,115200 root=UUID=${uuid} rootfstype=ext4 rootwait rw earlycon clk_ignore_unused loglevel=7 eth=$ethaddr rootrwoptions=rw,noatime rootrwreset=yes init=/lib/systemd/systemd" \
    > $boot_mnt/extlinux/extlinux.conf

    cp $build_dir/firmware/fw_dynamic.bin $boot_mnt
    cp $build_dir/visionfive-linux/arch/riscv/boot/Image $boot_mnt
    cp -r $build_dir/visionfive-linux/arch/riscv/boot/dts/starfive $boot_mnt/starfive

    echo "LABEL=fedora-root  / ext4    defaults,noatime 0 0" > ${build_dir}/rootfs/etc/fstab
    echo "LABEL=fedora-boot  /boot vfat    defaults,noatime 0 0" >> ${build_dir}/rootfs/etc/fstab

    cp -rfp ${build_dir}/rootfs/boot/* $boot_mnt
    rm -rf ${build_dir}/rootfs/boot/*

    rsync -avHAXq ${build_dir}/rootfs/* ${root_mnt}
    sync
    sleep 10

    umount $sdrootp
    umount $sdbootp

    LOSETUP_D_IMG
    UMOUNT_ALL

    losetup -D
    kpartx -d ${img_file}
}

comp_img() {
    if [ ! -f $build_dir/sd.img ]; then
        echo "sd flash file build failed!"
        exit 2
    fi

    xz -v sd.img
    mv sd.img.xz Fedora-38-Minimal-VisionFive2-riscv64-sd.img.xz

    sha256sum Fedora-38-Minimal-VisionFive2-riscv64-sd.img.xz >> Fedora-38-Minimal-VisionFive2-riscv64-sd.img.xz.sha256

}

build_dir=$(pwd)
boot_mnt=${build_dir}/boot_tmp
root_mnt=${build_dir}/root_tmp
rootfs_dir=${build_dir}/rootfs

source scripts/common.sh
source scripts/fedora_rootfs.sh

default_param
parseargs "$@" || help $?

install_reqpkg
init_base_system ${fedora_version}
install_riscv_pkgs
get_visionfive_tools
UMOUNT_ALL
build_kernel
build_u-boot
build_opensbi
mk_img
comp_img
