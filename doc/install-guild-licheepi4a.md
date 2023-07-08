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

#### Flashing System to EMMC

1.  UMS (USB Mass Storage) function using u-boot (experimental):
   
    If there is a dial switch, please set it to EMMC mode.
    
    Use the serial port to interrupt with `Ctrl^C` when counting down the seconds in u-boot to enter the u-boot command line, and then enter the following command:
    ```
    ums 0 emmc 0
    ```
    Then EMMC will map the USB Mass Storage device onto the computer.
    
    The automatic access to UMS function is currently under development. Interested parties can help develop it together: https://github.com/chainsx/thead-u-boot/tree/emmc-flasher
    
3.  After booting using the SD card, add the img image to EMMC.

### u-boot System Selection Order

SD card takes priority over EMMC.
