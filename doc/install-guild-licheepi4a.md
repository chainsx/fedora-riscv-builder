## LicheePi 4A 安装方法

### 支持情况

* GPU: TODO
* 风扇：支持
* 桌面：待测试

### 下载系统和 u-boot 文件

1.  到本项目 [Release](https://github.com/chainsx/fedora-riscv-builder/releases) 下载适用于 LicheePi 4A 的系统。
2.  如果需要使用 SD 镜像，需要下载适用于 LicheePi 4A 引导 SD 卡镜像的 [u-boot-with-spl.bin](../firmware/u-boot-with-spl.bin)。

### 安装系统到 SD 卡

#### 刷写 u-boot 到 EMMC

参考[官方Wiki](https://wiki.sipeed.com/hardware/zh/lichee/th1520/lpi4a/4_burn_image.html)

```
sudo ./fastboot flash ram ./images/u-boot-with-spl.bin
sudo ./fastboot reboot
sleep 10
sudo ./fastboot flash uboot ./images/u-boot-with-spl.bin
```

*注意，本项目提供的 u-boot 不会修改分区表*

#### 刷写系统到 SD 卡

这个不用我说了吧。

### u-boot 系统选择顺序

SD 优先于 EMMC

----------
## LicheePi 4A Installation Method

### Support Status

* GPU: TODO
* Fan: Supported
* Desktop: To be tested

### Downloading System and u-boot Files

1. Go to the [Release](https://github.com/chainsx/fedora-riscv-builder/releases) of this project to download the system suitable for LicheePi 4A.
2. If you need to use the SD image, download the [u-boot-with-spl.bin](../firmware/u-boot-with-spl.bin) file for booting the SD card on LicheePi 4A.

### Installing System to SD Card

#### Flashing u-boot to EMMC

Refer to the [official Wiki](https://wiki.sipeed.com/hardware/zh/lichee/th1520/lpi4a/4_burn_image.html)

```
sudo ./fastboot flash ram ./images/u-boot-with-spl.bin
sudo ./fastboot reboot
sleep 10
sudo ./fastboot flash uboot ./images/u-boot-with-spl.bin
```

*Note that the u-boot provided by this project will not modify the partition table.*

#### Flashing System to SD Card

I don't need to tell you this, right?

### u-boot System Selection Order

SD card takes priority over EMMC.
