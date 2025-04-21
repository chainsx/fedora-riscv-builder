# Fedora-RISCV-Builder

## Getting Started

### Supported Devices

* [LicheePi-4A](./doc/install-guild-licheepi4a.md)

* Starfive Visionfive 2

* QEMU

### Build Manually

#### Host

Ubuntu 22.04/24.04

1.  LicheePi 4A

Fedora 42

```
git clone https://github.com/chainsx/fedora-riscv-builder.git && cd fedora-riscv-builder
bash build_lpi4a.sh --fedora_version 42
```

Fedora 41

```
git clone https://github.com/chainsx/fedora-riscv-builder.git && cd fedora-riscv-builder
bash build_lpi4a.sh --fedora_version 41
```

2.  Starfive Visionfive 2

Fedora 42

```
git clone https://github.com/chainsx/fedora-riscv-builder.git && cd fedora-riscv-builder
bash build_visionfive2.sh --fedora_version 42
```

Fedora 41

```
git clone https://github.com/chainsx/fedora-riscv-builder.git && cd fedora-riscv-builder
bash build_visionfive2.sh --fedora_version 41
```

3.  QEMU

Fedora 42

```
git clone https://github.com/chainsx/fedora-riscv-builder.git && cd fedora-riscv-builder
bash build_qemu.sh --fedora_version 42
```

Fedora 41

```
git clone https://github.com/chainsx/fedora-riscv-builder.git && cd fedora-riscv-builder
bash build_qemu.sh --fedora_version 41
```

### Download Pre-built Systems

[Release](https://github.com/chainsx/fedora-riscv-builder/releases)

* Username: `root`
* Password: `fedora`

----

## Reference && Thanks

[fedora.riscv.rocks](http://fedora.riscv.rocks)

