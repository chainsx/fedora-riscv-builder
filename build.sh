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
    if [ -d $img_mnt ]; then
        if grep -q "$img_mnt " /proc/mounts ; then
            umount $img_mnt
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

install_reqpkg() {
    apt install make bision bc flex xz kpartx qemu-user-static
}

get_riscv_system() {
    cd $build_dir
    wget https://dl.fedoraproject.org/pub/alt/risc-v/repo/virt-builder-images/images/Fedora-Developer-37-20221130.n.0-mmc.raw.img.xz -O system.img.xz
    unxz -v system.img.xz
    img_file=system.img

    if [ ! -f $build_dir/system.img.xz ]; then
        echo "system image download failed!"
        exit 2
    fi
    LOSETUP_D_IMG

    device=`losetup -f --show -P ${img_file}`
    trap 'LOSETUP_D_IMG' EXIT
    kpartx -va ${device}
    loopX=${device##*\/}
    partprobe ${device}

    bootp=/dev/mapper/${loopX}p3
    rootp=/dev/mapper/${loopX}p4

    if [ -d $img_mnt ]; then
        LOSETUP_D_IMG
        rmdir $img_mnt
    fi
    mkdir $img_mnt
    
    mount $rootp $img_mnt
    mount $bootp $img_mnt/boot

    chroot $img_mnt dnf remove kernel* opensbi* *bootloader*

    cp -rfp $img_mnt $build_dir/rootfs
    sync

    umount $img_mnt/boot
    umount $img_mnt
    kpartx -d ${device}

    rmdir $img_mnt
}

prepare_toolchain() {
    cd $build_dir
    wget https://github.com/chainsx/armbian-riscv-build/releases/download/toolchain/Xuantie-900-gcc-linux-5.10.4-glibc-x86_64-V2.6.1-20220906.tar.gz
    tar -zxvf Xuantie-900-gcc-linux-5.10.4-glibc-x86_64-V2.6.1-20220906.tar.gz
    rm *tar.gz && mv Xuantie* riscv64-gcc
}


build_kernel() {
    git clone --depth=1 http://github.com/revyos/thead-kernel.get -b lpi4a
    cd thead-kernel
    wget https://github.com/chainsx/armbian-riscv-build/raw/main/config/kernel/linux-thead-current.config -O arch/riscv/configs/linux-thead-current_defconfig
    make ARCH=riscv CROSS_COMPILE=${build_dir}/riscv64-gcc/bin/riscv64-unknown-linux-gnu- linux-thead-current_defconfig
    make ARCH=riscv CROSS_COMPILE=${build_dir}/riscv64-gcc/bin/riscv64-unknown-linux-gnu- -j$(nproc)
    make ARCH=riscv CROSS_COMPILE=${build_dir}/riscv64-gcc/bin/riscv64-unknown-linux-gnu- modules_install INSTALL_MOD=kmod
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

    parted ${img_file} mklabel gpt mkpart primary fat32 32768s 524287s
    parted ${img_file} mkpart primary ext4 524288s 100%

    device=`losetup -f --show -P ${img_file}`
    trap 'LOSETUP_D_IMG' EXIT
    kpartx -va ${device}
    loopX=${device##*\/}
    partprobe ${device}

    sdbootp=/dev/mapper/${loopX}p1
    sdrootp=/dev/mapper/${loopX}p2
    
    mkfs.vfat -n boot ${sdbootp}
    mkfs.ext4 -L rootfs ${sdrootp}
    mkdir -p ${root_mnt} ${boot_mnt}
    mount -t ext4 ${sdbootp} ${boot_mnt}
    mount -t ext4 ${sdrootp} ${root_mnt}

    echo "fdt_file=light-lpi4a.dtb
    kernel_file=Image
    bootargs=console=ttyS0,115200 root=/dev/mmcblk1p2 rootfstype=ext4 rootwait rw earlycon clk_ignore_unused loglevel=7 eth=$ethaddr rootrwoptions=rw,noatime rootrwreset=yes init=/lib/systemd/systemd" >> $boot_mnt/config.txt

    cd $boot_mnt
    wget https://github.com/chainsx/armbian-riscv-build/raw/main/packages/blobs/riscv64/thead/light_aon_fpga.bin
    wget https://github.com/chainsx/armbian-riscv-build/raw/main/packages/blobs/riscv64/thead/light_c906_audio.bin

    cp $build_dir/thead-kernel/arch/riscv/boot/Image .
    cp $build_dir/thead-kernel/arch/riscv/boot/dts/thrad/*lpi4a*dtb .

    sync

    rsync -avHAXq ${build_dir}/rootfs/* ${root_mnt}
    echo "/dev/mmcblk1p2  / ext4    defaults,noatime 0 0" > ${build_dir}/rootfs/etc/fstab
    echo "/dev/mmcblk1p1  /boot ext4    defaults,noatime 0 0" >> ${build_dir}/rootfs/etc/fstab

    sync

    umount $sdrootp
    umount $sdbootp

    LOSETUP_D_IMG

    dd if=$sdbootp of=boot.img status=progress
    dd if=$sdrootp of=rootfs.img status=progress
    sync

    mount -t ext4 boot.img ${boot_mnt}
    mount -t ext4 rootfs.img ${root_mnt}

    rm $boot_mnt/config.txt
    echo "fdt_file=light-lpi4a.dtb
    kernel_file=Image
    bootargs=console=ttyS0,115200 root=/dev/mmcblk0p3 rootfstype=ext4 rootwait rw earlycon clk_ignore_unused loglevel=7 eth=$ethaddr rootrwoptions=rw,noatime rootrwreset=yes init=/lib/systemd/systemd" >> $boot_mnt/config.txt
    echo "/dev/mmcblk0p3  / ext4    defaults,noatime 0 0" > ${build_dir}/rootfs/etc/fstab
    echo "/dev/mmcblk0p2  /boot ext4    defaults,noatime 0 0" >> ${build_dir}/rootfs/etc/fstab

    umount $sdrootp
    umount $sdbootp

    losetup -D
    kpartx -d ${img_file}
}

build_dir=$(pwd)
img_mnt=${build_dir}/img_mnt
boot_mnt=${build_dir}/boot_tmp
root_mnt=${build_dir}/root_tmp
install_reqpkg
get_riscv_system
prepare_toolchain
build_kernel
mk_img