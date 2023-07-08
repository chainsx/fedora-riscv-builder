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

Hold down the `BOOT` key and connect the power supply to the development board.

```
sudo ./fastboot flash ram ./images/u-boot-with-spl.bin
sudo ./fastboot reboot
sleep 10
sudo ./fastboot flash uboot ./images/u-boot-with-spl.bin
```

*Note that the u-boot provided by this project will not modify the partition table.*

#### Flashing System to SD Card

I don't need to tell you this, right?

:)

#### Flashing System to EMMC use EMMC-Flasher

You need to download the `u-boot-emmc-flasher.bin` file provided in the Release of this project.

Hold down the `BOOT` key and connect the power supply to the development board.

```
sudo ./fastboot flash ram ./images/u-boot-emmc-flasher.bin
sudo ./fastboot reboot
```

Then the EMMC of LicheePi 4A will be mapped as a disk and displayed on your computer. At this time, you can use the `etcher` or `dd command` to write the image to it.

### u-boot System Selection Order

SD card takes priority over EMMC.
