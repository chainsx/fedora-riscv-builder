## LicheePi 4A 安装方法

### 支持情况

* GPU: TODO
* 风扇：支持
* 桌面：待测试

### 下载系统和 u-boot 文件

1.  到本项目 [Release](https://github.com/chainsx/fedora-riscv-builder/releases) 下载适用于 LicheePi 4A 的系统，可以选择 EMMC 或 SD 镜像。
2.  如果需要使用 SD 镜像，需要下载适用于 LicheePi 4A 引导 SD 卡镜像的 [u-boot-with-spl.bin](../firmware/u-boot-with-spl.bin)。

### 安装系统到 EMMC

同官方镜像刷写过程，需要下载名称带有 “*emmc.tar.gz” 的文件然后解压，可以使用官方 u-boot，


 ```
sudo ./fastboot flash boot boot.img
sudo ./fastboot flash root root.img
 ```

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

这个不用我说了吧

### 需要注意的事

1.  目前系统正在完善，遇到问题可以发 issue。
2.  对于 u-boot 的修改只是将 cmdline 从官方 u-boot 里剥离出来以 u-boot env 的格式放在 /boot/config.txt 里，受支持的 u-boot env 可以添加进去。

### u-boot 系统选择顺序

SD 优先于 EMMC
