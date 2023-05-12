# Fedora-RISCV-Builder

## 开始

### 目前支持的开发板

* [LicheePi-4A （8+8 内测版）](./doc/install-guild-licheepi4a.md)

### 自行构建

```
git clone https://github.com/chainsx/fedora-riscv-builder.git && cd fedora-riscv-builder
bash build.sh
```

### 下载

[Release](https://github.com/chainsx/fedora-riscv-builder/releases)

----

### 说明

本项目用到的名为 fedora-38-core-rootfs.tar.gz 的文件需要使用 risc-v 主机进行构建，构建过程如下，如果不想自己构建，可以使用项目提供的预构建文件。

```
WORKDIR=$(pwd)

cd $WORKDIR
mkdir rootfs
mkdir -p rootfs/var/lib/rpm
rpm --root  $WORKDIR/rootfs/ --initdb

rpm -ivh --nodeps --root $WORKDIR/rootfs/ http://fedora.riscv.rocks/repos-dist/f38/latest/riscv64/Packages/f/fedora-release-38-34.noarch.rpm

mkdir -p $WORKDIR/rootfs/etc/yum.repos.d
cp /etc/yum.repos.d/*repo $WORKDIR/rootfs/etc/yum.repos.d
dnf --installroot=$WORKDIR/rootfs/ install dnf --nogpgcheck -y
```