#!/bin/bash

fedora_core_rootfs_addr="https://github.com/chainsx/fedora-riscv-builder/releases/download/basic-data/fedora-38-core-rootfs.tar.gz"

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
    chroot ${rootfs_dir} dnf install wget openssh-server openssh-clients parted realtek-firmware chkconfig e2fsprogs dracut NetworkManager-wifi -y
    echo fedora-riscv > ${rootfs_dir}/etc/hostname
    cp $build_dir/config/extend-root.sh ${rootfs_dir}/etc/rc.d/init.d/extend-root.sh
    chmod +x ${rootfs_dir}/etc/rc.d/init.d/extend-root.sh
    sed -i "s|#PermitRootLogin prohibit-password|PermitRootLogin yes|g" ${rootfs_dir}/etc/ssh/sshd_config

    cat << EOF | chroot ${rootfs_dir}  /bin/bash
    echo 'fedora' | passwd --stdin root
    chkconfig --add extend-root.sh
    chkconfig extend-root.sh on
    dracut --no-kernel /boot/initrd.img
EOF

}
