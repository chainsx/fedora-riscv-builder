#!/bin/bash
# chkconfig: - 99 10
# description: extend root

set -e

extend_root(){
    ROOT_PART="$(findmnt / -o source -n)"  # /dev/mmcblk0p3
    ROOT_DEV="/dev/$(lsblk -no pkname "$ROOT_PART")"  # /dev/mmcblk0
    PART_NUM="$(echo "$ROOT_PART" | grep -o "[[:digit:]]*$")"  # 3

    PART_INFO=$(parted "$ROOT_DEV" -ms unit s p)
    # BYT;
    # /dev/mmcblk0:31116288s:sd/mmc:512:512:msdos:SD SC16G:;
    # 1:8192s:593919s:585728s:fat16::boot, lba;
    # 2:593920s:1593343s:999424s:linux-swap(v1)::;
    # 3:1593344s:31116287s:29522944s:ext4::;
    LAST_PART_NUM=$(echo "$PART_INFO" | tail -n 1 | cut -f 1 -d:)  # 3
    PART_START=$(echo "$PART_INFO" | grep "^${PART_NUM}" | cut -f 2 -d: | sed 's/[^0-9]//g')  # 1593344
    PART_END=$(echo "$PART_INFO" | grep "^${PART_NUM}" | cut -f 3 -d: | sed 's/[^0-9]//g')  # XXXX < 31116288
    ROOT_END=$(echo "$PART_INFO" | grep "^/dev"| cut -f 2 -d: | sed 's/[^0-9]//g')  # 31116288
    ((ROOT_END--)) # 31116287

    if [ $PART_END -lt $ROOT_END ]; then
        fdisk "$ROOT_DEV" <<EOF
p
d
$PART_NUM
n
p
$PART_NUM
$PART_START

p
w
EOF
        resize2fs $ROOT_PART
        echo "Extend $ROOT_PART finished." >> /var/log/extend-root.log
    else
        echo "Already the largest! Do not need extend any more!" >> /var/log/extend-root.log
    fi
    return 0
}

if extend_root; then
    rm -f /etc/rc.d/init.d/extend-root.sh
else
    echo "Fail to root!" >> /var/log/extend-root.log
fi
