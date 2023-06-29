#!/bin/bash

LOSETUP_D_IMG(){
    set +e
    if [ -d ${root_mnt} ]; then
        if grep -q "${root_mnt} " /proc/mounts ; then
            umount ${root_mnt}
        fi
    fi
    if [ -d ${boot_mnt} ]; then
        if grep -q "${boot_mnt} " /proc/mounts ; then
            umount ${boot_mnt}
        fi
    fi
    if [ "x$device" != "x" ]; then
        kpartx -d ${device}
        losetup -d ${device}
        device=""
    fi
    if [ -d ${root_mnt} ]; then
        rm -rf ${root_mnt}
    fi
    if [ -d ${boot_mnt} ]; then
        rm -rf ${boot_mnt}
    fi
    set -e
}

UMOUNT_ALL(){
    set +e
    if grep -q "${rootfs_dir}/dev " /proc/mounts ; then
        umount -l ${rootfs_dir}/dev
    fi
    if grep -q "${rootfs_dir}/proc " /proc/mounts ; then
        umount -l ${rootfs_dir}/proc
    fi
    if grep -q "${rootfs_dir}/sys " /proc/mounts ; then
        umount -l ${rootfs_dir}/sys
    fi
    set -e
}

install_reqpkg() {
    apt install make bison bc flex kpartx xz-utils qemu-user-static libssl-dev gcc-riscv64-linux-gnu -y
}

get_riscv_system() {
    cd $build_dir
    if [ -f $build_dir/*rootfs.tar.gz ]; then
        echo "clean tar..."
        rm $build_dir/*rootfs.tar.gz
    fi
    wget $fedora_core_rootfs_addr -O rootfs.tar.gz
    if [ ! -f $build_dir/rootfs.tar.gz ]; then
        echo "system tar download failed!"
        exit 2
    fi

    if [ -d ${rootfs_dir} ]; then
        echo "clean rootfs..."
        rm -rf ${rootfs_dir}
    fi

    mkdir ${rootfs_dir}
    tar -zxvf rootfs.tar.gz -C ${rootfs_dir}
    cp -b /etc/resolv.conf ${rootfs_dir}/etc/resolv.conf

    mount --bind /dev ${rootfs_dir}/dev
    mount -t proc /proc ${rootfs_dir}/proc
    mount -t sysfs /sys ${rootfs_dir}/sys

    chroot ${rootfs_dir} dnf update -y
    chroot ${rootfs_dir} dnf install alsa-utils haveged wpa_supplicant vim net-tools iproute iputils NetworkManager bluez fedora-release-server passwd hostname -y
    chroot ${rootfs_dir} dnf install wget openssh-server openssh-clients parted chkconfig e2fsprogs dracut -y
    echo fedora-riscv > ${rootfs_dir}/etc/hostname

    cat << EOF | chroot ${rootfs_dir}  /bin/bash
    echo 'fedora' | passwd --stdin root
    dracut --no-kernel /boot/initrd.img
EOF

}

build_kernel() {
    if [ ! -d $build_dir/linux ]; then
        git clone --depth=1 https://github.com/torvalds/linux.git -b v6.2
    fi
    cd linux
    if [ -f arch/riscv/configs/linux-qemu-current_defconfig ]; then
        rm arch/riscv/configs/linux-qemu-current_defconfig
    fi
    cp $build_dir/config/linux-qemu-current.config arch/riscv/configs/linux-qemu-current_defconfig
    make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- linux-qemu-current_defconfig
    make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j$(nproc)
    make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- modules_install INSTALL_MOD_PATH=kmod
    cd $build_dir
    cp -rfp linux/kmod/lib/modules/* rootfs/lib/modules
}

build_u-boot() {
    if [ ! -d $build_dir/u-boot ]; then
        git clone --depth=1 https://github.com/u-boot/u-boot.git -b v2022.04
    fi
    cd u-boot
    make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- qemu-riscv64_smode_defconfig
    make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j$(nproc)
    cp u-boot-nodtb.bin $build_dir/firmware
    cd $build_dir
}

build_opensbi() {
    if [ ! -d $build_dir/opensbi ]; then
        git clone --depth=1 https://github.com/riscv-software-src/opensbi.git -b v1.3
    fi
    cd opensbi
    make PLATFORM=generic PLATFORM_RISCV_XLEN=64 CROSS_COMPILE=riscv64-linux-gnu- -j$(nproc)
    cp build/platform/generic/firmware/fw_jump.bin $build_dir/firmware
    cd $build_dir
}

mk_img() {
    cd $build_dir
    device=""
    LOSETUP_D_IMG
    UMOUNT_ALL
    size=`du -sh --block-size=1MiB ${build_dir}/rootfs | cut -f 1 | xargs`
    size=$(($size+720))
    losetup -D
    img_file=${build_dir}/rootfs.img
    dd if=/dev/zero of=${img_file} bs=1MiB count=$size status=progress && sync

    parted ${img_file} mklabel gpt mkpart primary fat32 32768s 524287s
    parted ${img_file} mkpart primary ext4 524288s 100%

    device=`losetup -f --show -P ${img_file}`
    trap 'LOSETUP_D_IMG' EXIT
    kpartx -va ${device}
    loopX=${device##*\/}
    partprobe ${device}

    sdbootp=/dev/mapper/${loopX}p1
    sdrootp=/dev/mapper/${loopX}p2
    
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
    append  console=ttyS0,115200 root=UUID=${uuid} rootfstype=ext4 rootwait rw earlycon loglevel=7 rootrwoptions=rw,noatime rootrwreset=yes init=/lib/systemd/systemd" \
    > $boot_mnt/extlinux/extlinux.conf

    cp $build_dir/firmware/fw_jump.bin $boot_mnt
    cp $build_dir/linux/arch/riscv/boot/Image $boot_mnt

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
    if [ ! -f $build_dir/rootfs.img ]; then
        echo "rootfs file build failed!"
        exit 2
    fi

    if [ -d $build_dir/tar_dir ]; then
        rm -rf $build_dir/tar_dir
    fi

    mkdir tar_dir

    mv $build_dir/firmware/fw_jump.bin $build_dir/tar_dir
    mv $build_dir/firmware/u-boot-nodtb.bin $build_dir/tar_dir
    mv $build_dir/config/run-qemu-rv64.sh $build_dir/tar_dir
    mv $build_dir/rootfs.img $build_dir/tar_dir

    cd tar_dir && tar -zcvf ../Fedora-38-Minimal-QEMU-riscv64.tar.gz .
    cd $build_dir

    if [ ! -f $build_dir/Fedora-38-Minimal-QEMU-riscv64.tar.gz ]; then
        echo "image file build failed!"
        exit 2
    fi

    sha256sum Fedora-38-Minimal-QEMU-riscv64.tar.gz >> Fedora-38-Minimal-QEMU-riscv64.tar.gz.sha256

}

build_dir=$(pwd)
boot_mnt=${build_dir}/boot_tmp
root_mnt=${build_dir}/root_tmp
rootfs_dir=${build_dir}/rootfs

fedora_core_rootfs_addr="https://github.com/chainsx/fedora-riscv-builder/releases/download/basic-data/fedora-38-core-rootfs.tar.gz"

install_reqpkg
get_riscv_system
UMOUNT_ALL
build_kernel
build_u-boot
build_opensbi
mk_img
comp_img

