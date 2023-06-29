qemu-system-riscv64 -M virt -m 1G \
-bios fw_jump.bin \
-kernel u-boot-nodtb.bin \
-drive file=rootfs.img,format=raw,id=hd0 \
-device virtio-blk-device,drive=hd0 \
