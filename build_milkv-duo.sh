#!/bin/bash

LOSETUP_D_IMG(){
    set +e
    if [ -d ${root_mnt} ]; then
        if grep -q "${root_mnt} " /proc/mounts ; then
            umount ${root_mnt}
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
    sudo -E apt-get -y install pkg-config build-essential ninja-build automake autoconf libtool wget curl git gcc libssl-dev bc slib
    sudo -E apt-get -y install squashfs-tools android-sdk-libsparse-utils jq python3-distutils scons parallel tree python3-dev python3-pip
    sudo -E apt-get -y install device-tree-compiler ssh cpio fakeroot libncurses5 flex bison libncurses5-dev genext2fs rsync unzip
    sudo -E apt-get -y install dosfstools mtools tclsh ssh-client android-sdk-ext4-utils pixz qemu-user-static
    sudo -E apt-get -y autoremove --purge

    sudo wget https://github.com/Kitware/CMake/releases/download/v3.26.4/cmake-3.26.4-linux-x86_64.sh
    sudo sh cmake-3.26.4-linux-x86_64.sh --skip-license --prefix=/usr/local/
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
EOF

}

build_bsp() {
    if [ ! -d $build_dir/duo-buildroot-sdk-glibc ]; then
        git clone --depth=1 https://github.com/chainsx/duo-buildroot-sdk-glibc.git -b develop
    fi
    cd duo-buildroot-sdk-glibc
    sudo bash build_milkv.sh
    mv out/milkv*img $build_dir/milkv-buildroot.img
    rm -rf buildroot-*/output
}

mk_img() {
    cd $build_dir
    device=""
    LOSETUP_D_IMG
    UMOUNT_ALL
    size=1500
    losetup -D
    img_file=${build_dir}/milkv-buildroot.img
    dd if=/dev/zero of=add.img bs=1MiB count=$size status=progress && sync

    cat add.img >> ${img_file} && rm add.img
    parted -s ${img_file} -- resizepart 2 100%

    device=`losetup -f --show -P ${img_file}`
    trap 'LOSETUP_D_IMG' EXIT
    kpartx -va ${device}
    loopX=${device##*\/}
    partprobe ${device}

    sdrootp=/dev/mapper/${loopX}p2
    
    resize2fs ${sdrootp}

    mkdir -p ${root_mnt}
    mount ${sdrootp} ${root_mnt}

    rm -rf ${root_mnt}/*

    echo "/dev/mmcblk0p2  / ext4    defaults,noatime 0 0" > ${build_dir}/rootfs/etc/fstab
    #echo "/dev/mmcblk0p1  /boot vfat    defaults,noatime 0 0" >> ${build_dir}/rootfs/etc/fstab

    rsync -avHAXq ${build_dir}/rootfs/* ${root_mnt}
    sync
    sleep 10

    umount $sdrootp

    LOSETUP_D_IMG
    UMOUNT_ALL

    losetup -D
    kpartx -d ${img_file}
}

comp_img() {
    if [ ! -f $build_dir/milkv-buildroot.img ]; then
        echo "rootfs file build failed!"
        exit 2
    fi

    cd $build_dir
    pixz milkv-buildroot.img
    mv milkv-buildroot.img.xz Fedora-38-Minimal-MilkV-Duo-riscv64.img.xz

    if [ ! -f $build_dir/Fedora-38-Minimal-MilkV-Duo-riscv64.img.xz ]; then
        echo "image file build failed!"
        exit 2
    fi

    sha256sum Fedora-38-Minimal-MilkV-Duo-riscv64.img.xz >> Fedora-38-Minimal-MilkV-Duo-riscv64.img.xz.sha256

}

build_dir=$(pwd)
root_mnt=${build_dir}/root_tmp
rootfs_dir=${build_dir}/rootfs

fedora_core_rootfs_addr="https://github.com/chainsx/fedora-riscv-builder/releases/download/basic-data/fedora-38-core-rootfs.tar.gz"

install_reqpkg
get_riscv_system
UMOUNT_ALL
build_bsp
mk_img
comp_img

