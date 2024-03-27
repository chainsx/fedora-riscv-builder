# Fedora-RISCV-Builder

## Getting Started

### Supported Devices

* [LicheePi-4A](./doc/install-guild-licheepi4a.md)

* Starfive Visionfive 2

* QEMU

### Build Manually

1.  LicheePi 4A

```
git clone https://github.com/chainsx/fedora-riscv-builder.git && cd fedora-riscv-builder
bash build_lpi4a.sh
```

2.  Starfive Visionfive 2

```
git clone https://github.com/chainsx/fedora-riscv-builder.git && cd fedora-riscv-builder
bash build_visionfive2.sh
```

3.  QEMU

```
git clone https://github.com/chainsx/fedora-riscv-builder.git && cd fedora-riscv-builder
bash build_qemu.sh
```

### Download Pre-built Systems

[Release](https://github.com/chainsx/fedora-riscv-builder/releases)

* Username: `root`
* Password: `fedora`

----

### Instructions

The project requires a file named `fedora-39-core-rootfs.tar.gz` to be built using a Fedora 39 host or docker with the RISC-V architecture. The build process is as follows. If you do not wish to build it yourself, you can use the pre-built file provided by the project.

```
sudo su && cd ~
WORKDIR=$(pwd)

cd $WORKDIR
mkdir rootfs
mkdir -p rootfs/var/lib/rpm
rpm --root  $WORKDIR/rootfs/ --initdb

rpm -ivh --nodeps --root $WORKDIR/rootfs/ http://fedora.riscv.rocks/repos-dist/f39/latest/riscv64/Packages/f/fedora-release-39-0.21.noarch.rpm

mkdir -p $WORKDIR/rootfs/etc/yum.repos.d
cp <this_repo_dir>./repo/*repo $WORKDIR/rootfs/etc/yum.repos.d
sed -i "s|f38|f39|g" $WORKDIR/rootfs/etc/yum.repos.d/fedora-riscv.repo
sed -i "s|f38|f39|g" $WORKDIR/rootfs/etc/yum.repos.d/fedora-riscv-koji.repo  # for fedora 39
dnf --installroot=$WORKDIR/rootfs/ install dnf --nogpgcheck -y

cd $WORKDIR/rootfs
tar -zcvf fedora-39-core-rootfs.tar.gz .
```

This way, you will obtain the `fedora-39-core-rootfs.tar.gz` file required for the project script in the `/root` directory.

## Reference && Thanks

[fedora.riscv.rocks](http://fedora.riscv.rocks)
