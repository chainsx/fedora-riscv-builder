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
    if [ -d $image_mnt ]; then
        if grep -q "$image_mnt " /proc/mounts ; then
            umount $image_mnt
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
    if [ -d ${image_mnt} ]; then
        rm -rf ${image_mnt}
    fi
    set -e
}

install_reqpkg() {
    apt install make bison bc flex kpartx xz-utils qemu-user-static
}

get_riscv_system() {
    cd $build_dir
    if [ -f $build_dir/fedora-38-core-rootfs.tar.gz ]; then
        echo "clean..."
        rm $build_dir/fedora-38-core-rootfs.tar.gz
    fi
    wget http://127.0.0.1/fedora-38-core-rootfs.tar.gz
    if [ ! -f $build_dir/fedora-38-core-rootfs.tar.gz ]; then
        echo "system tar download failed!"
        exit 2
    fi

    mkdir rootfs
    tar -zxvf fedora-38-core-rootfs.tar.gz -C rootfs
    cp -b /etc/resolv.conf rootfs/etc/resolv.conf
    chroot rootfs dnf update
    chroot rootfs dnf install alsa-utils haveged wpa_supplicant vim net-tools iproute iputils NetworkManager bluez -y
    chroot rootfs dnf install openssh-server openssh-clients passwd hostname parted linux-firmware-whence chkconfig e2fsprogs -y
    echo fedora-riscv > rootfs/etc/hostname
    cp $build_dir/config/extend-root.sh rootfs/etc/rc.d/init.d/extend-root.sh
    chmod +x rootfs/etc/rc.d/init.d/extend-root.sh

    cat << EOF | chroot rootfs  /bin/bash
    echo 'fedora' | passwd --stdin root
    chkconfig --add extend-root.sh
    chkconfig extend-root.sh on
EOF

}

prepare_toolchain() {
    cd $build_dir
    if [ ! -d $build_dir/riscv64-gcc ]; then
        wget http://127.0.0.1/Xuantie-900-gcc-linux-5.10.4-glibc-x86_64-V2.6.1-20220906.tar.gz
        tar -zxf Xuantie-900-gcc-linux-5.10.4-glibc-x86_64-V2.6.1-20220906.tar.gz
        rm *tar.gz && mv Xuantie* riscv64-gcc
    fi
}


build_kernel() {
    if [ ! -d $build_dir/thead-kernel ]; then
        git clone --depth=1 https://github.com/revyos/thead-kernel.git -b lpi4a
    fi
    cd thead-kernel
    if [ -f arch/riscv/configs/linux-thead-current_defconfig ]; then
        rm arch/riscv/configs/linux-thead-current_defconfig
    fi
    cp $build_dir/config/linux-thead-current.config arch/riscv/configs/linux-thead-current_defconfig
    make ARCH=riscv CROSS_COMPILE=${build_dir}/riscv64-gcc/bin/riscv64-unknown-linux-gnu- linux-thead-current_defconfig
    make ARCH=riscv CROSS_COMPILE=${build_dir}/riscv64-gcc/bin/riscv64-unknown-linux-gnu- -j$(nproc)
    make ARCH=riscv CROSS_COMPILE=${build_dir}/riscv64-gcc/bin/riscv64-unknown-linux-gnu- modules_install INSTALL_MOD_PATH=kmod
    cd $build_dir
    cp -rfp thead-kernel/kmod/lib/modules/* rootfs/lib/modules
}

mk_img() {
    cd $build_dir
    device=""
    LOSETUP_D_IMG
    size=`du -sh --block-size=1MiB ${build_dir}/rootfs | cut -f 1 | xargs`
    size=$(($size+720))
    losetup -D
    img_file=${build_dir}/sd.img
    dd if=/dev/zero of=${img_file} bs=1MiB count=$size status=progress && sync

    parted ${img_file} mklabel gpt mkpart primary ext4 32768s 524287s
    parted ${img_file} mkpart primary ext4 524288s 100%

    device=`losetup -f --show -P ${img_file}`
    trap 'LOSETUP_D_IMG' EXIT
    kpartx -va ${device}
    loopX=${device##*\/}
    partprobe ${device}

    sdbootp=/dev/mapper/${loopX}p1
    sdrootp=/dev/mapper/${loopX}p2
    
    mkfs.ext4 -L fedora-boot ${sdbootp}
    mkfs.ext4 -L fedora-root ${sdrootp}
    mkdir -p ${root_mnt} ${boot_mnt}
    mount -t ext4 ${sdbootp} ${boot_mnt}
    mount -t ext4 ${sdrootp} ${root_mnt}

    if [ -f $boot_mnt/config.txt ]; then
        rm $boot_mnt/config.txt
    fi
    cp $build_dir/config/config.txt $boot_mnt/config.txt

    cp $build_dir/firmware/light_aon_fpga.bin $boot_mnt
    cp $build_dir/firmware/light_c906_audio.bin $boot_mnt
    cp $build_dir/thead-kernel/arch/riscv/boot/Image $boot_mnt
    cp $build_dir/thead-kernel/arch/riscv/boot/dts/thead/*lpi4a*dtb $boot_mnt

    echo "/dev/mmcblk1p2  / ext4    defaults,noatime 0 0" > ${build_dir}/rootfs/etc/fstab
    echo "/dev/mmcblk1p1  /boot ext4    defaults,noatime 0 0" >> ${build_dir}/rootfs/etc/fstab

    rsync -avHAXq ${build_dir}/rootfs/* ${root_mnt}

    sync

    umount $sdrootp
    umount $sdbootp

    dd if=$sdbootp of=boot.img status=progress
    dd if=$sdrootp of=rootfs.img status=progress
    sync

    mount -t ext4 boot.img ${boot_mnt}
    mount -t ext4 rootfs.img ${root_mnt}

    if [ -f $boot_mnt/config.txt ]; then
        rm $boot_mnt/config.txt
    fi
    cp $build_dir/config/config-emmc.txt $boot_mnt/config.txt
    
    echo "/dev/mmcblk0p3  / ext4    defaults,noatime 0 0" > ${root_mnt}/etc/fstab
    echo "/dev/mmcblk0p2  /boot ext4    defaults,noatime 0 0" >> ${root_mnt}/etc/fstab
    sync
    sleep 10

    LOSETUP_D_IMG

    losetup -D
    kpartx -d ${img_file}
}

build_dir=$(pwd)
image_mnt=${build_dir}/image_mnt
boot_mnt=${build_dir}/boot_tmp
root_mnt=${build_dir}/root_tmp

install_reqpkg
get_riscv_system
prepare_toolchain
build_kernel
mk_img