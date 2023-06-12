# Fedora-RISCV-Builder

## 开始

### 目前支持的开发板

* [LicheePi-4A （8+8 内测版）](./doc/install-guild-licheepi4a.md)

### 自行构建

```
git clone https://github.com/chainsx/fedora-riscv-builder.git && cd fedora-riscv-builder
bash build.sh
```

### 下载预构建系统

[Release](https://github.com/chainsx/fedora-riscv-builder/releases)

* 用户名：`root`
* 密码：`fedora`

----

### 说明

本项目用到的名为 fedora-38-core-rootfs.tar.gz 的文件需要使用 risc-v 架构的 Fedora 38 主机进行构建，构建过程如下，如果不想自己构建，可以使用项目提供的预构建文件。

```
sudo su && cd ~
WORKDIR=$(pwd)

cd $WORKDIR
mkdir rootfs
mkdir -p rootfs/var/lib/rpm
rpm --root  $WORKDIR/rootfs/ --initdb

rpm -ivh --nodeps --root $WORKDIR/rootfs/ http://fedora.riscv.rocks/repos-dist/f38/latest/riscv64/Packages/f/fedora-release-38-34.noarch.rpm

mkdir -p $WORKDIR/rootfs/etc/yum.repos.d
cp /etc/yum.repos.d/*repo $WORKDIR/rootfs/etc/yum.repos.d
dnf --installroot=$WORKDIR/rootfs/ install dnf --nogpgcheck -y

cd $WORKDIR/rootfs
tar -zcvf fedora-38-core-rootfs.tar.gz .
```

这样，你在 /root 目录下可以得到项目脚本构建所需的 fedora-38-core-rootfs.tar.gz 文件。

## 引用 && 感谢

[fedora.riscv.rocks](http://fedora.riscv.rocks)
