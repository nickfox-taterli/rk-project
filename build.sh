#!/bin/bash
PROJECT_DIR="/root/project"
SERVER_ADDR="http://156.251.191.19:44915"

BUILD_ATF=false
BUILD_UBOOT=false
BUILD_KERNEL=false
BUILD_ROOTFS=false
BUILD_TOOLS=false

COPY_FILE=true
COPY_BOOT=true
COPY_WEB=true

DOWNLOAD_FILE=false
DOWNLOAD_ROOTFS=false
DOWNLOAD_BOARD=false

# 编译过程

## 编译ATF
if [ "$BUILD_ATF" = true ]; then
    cd $PROJECT_DIR/arm-trusted-firmware
    make realclean
    CFLAGS='-gdwarf-2' CROSS_COMPILE=$PROJECT_DIR/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu- make PLAT=px30 DEBUG=0 ERROR_DEPRECATED=1 bl31
    cp build/px30/release/bl31/bl31.elf $PROJECT_DIR/u-boot/bl31.elf
    cd $PROJECT_DIR
fi

## 编译引导
if [ "$BUILD_UBOOT" = true ]; then
    cd $PROJECT_DIR/u-boot
    make ARCH=arm CROSS_COMPILE=$PROJECT_DIR/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu- evb-px30_defconfig
    make ARCH=arm CROSS_COMPILE=$PROJECT_DIR/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu- menuconfig
    make ARCH=arm CROSS_COMPILE=$PROJECT_DIR/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu- u-boot.itb
    make ARCH=arm CROSS_COMPILE=$PROJECT_DIR/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-
    cd $PROJECT_DIR
fi

## 编译内核
if [ "$BUILD_KERNEL" = true ]; then
    cd $PROJECT_DIR/kernel
    # make ARCH=arm64 CROSS_COMPILE=$PROJECT_DIR/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu- rockchip_linux_defconfig
    make ARCH=arm64 CROSS_COMPILE=$PROJECT_DIR/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu- -j32
    make ARCH=arm64 CROSS_COMPILE=$PROJECT_DIR/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu- px30-evb-ddr3-v11.img
    cd $PROJECT_DIR
fi

## 制作系统镜像
if [ "$BUILD_ROOTFS" = true ]; then
    cd $PROJECT_DIR/rk-rootfs-build
    apt-get install binfmt-support qemu-user-static
    dpkg -i ubuntu-build-service/packages/*
    apt-get install -f -y
    RELEASE=buster TARGET=desktop ARCH=arm64 ./mk-base-debian.sh
    RELEASE=buster TARGET=desktop ARCH=arm64 ./mk-rootfs.sh
    ./mk-image.sh
    cd $PROJECT_DIR
fi

## 编译烧录工具(官方版)
if [ "$BUILD_TOOLS" = true ]; then
    cd $PROJECT_DIR/rkdeveloptool
    apt-get install libudev-dev libusb-1.0-0-dev dh-autoreconf
    aclocal
    autoreconf -i
    autoheader
    automake --add-missing
    ./configure
    make
    cd $PROJECT_DIR
fi

## 编译烧录工具(社区版)
if [ "$BUILD_TOOLS" = true ]; then
    cd $PROJECT_DIR/rkflashtool
    apt-get install libusb-1.0-0-dev
    make
    cd $PROJECT_DIR
fi

# 编译结果处理

## 复制文件
if [ "$COPY_FILE" = true ]; then
    cp $PROJECT_DIR/u-boot/idbloader.img $PROJECT_DIR/output/idbloader.img
    cp $PROJECT_DIR/u-boot/u-boot.itb $PROJECT_DIR/output/u-boot.itb
    cp $PROJECT_DIR/kernel/arch/arm64/boot/Image $PROJECT_DIR/output/boot/
    cp $PROJECT_DIR/kernel/arch/arm64/boot/dts/rockchip/px30-evb-ddr3-v11.dtb $PROJECT_DIR/output/boot/
    # cp $PROJECT_DIR/rk-rootfs-build/linaro-rootfs.img $PROJECT_DIR/output/linaro-rootfs.img
fi

## 制作boot.img
if [ "$COPY_BOOT" = true ]; then
    cd output
    $PROJECT_DIR/u-boot/tools/mkimage -n px30 -T rksd -d $PROJECT_DIR/u-boot/tpl/u-boot-tpl.bin idbloader.img
    cat $PROJECT_DIR/u-boot/spl/u-boot-spl.bin >> idbloader.img
    genext2fs -b 32768 -B $((32*1024*1024/32768)) -d boot/ -i 8192 -U boot.img
    cd ..
fi

## 复制到可被下载目录
if [ "$COPY_WEB" = true ]; then
    cp $PROJECT_DIR/rkdeveloptool/rkdeveloptool /var/www/html/
    cp $PROJECT_DIR/output/parameter_gpt.txt /var/www/html/
    cp $PROJECT_DIR/output/idbloader.img /var/www/html/
    cp $PROJECT_DIR/output/u-boot.itb /var/www/html/
    cp $PROJECT_DIR/output/boot.img /var/www/html/
    cp $PROJECT_DIR/output/linaro-rootfs.img /var/www/html/
    cp $PROJECT_DIR/output/px30_loader_v1.14.120.bin /var/www/html/
fi

# 烧录过程

## 下载主要文件
if [ "$DOWNLOAD_FILE" = true ]; then
    wget $SERVER_ADDR/rkdeveloptool -O rkdeveloptool
    wget $SERVER_ADDR/parameter_gpt.txt -O parameter_gpt.txt
    wget $SERVER_ADDR/idbloader.img -O idbloader.img
    wget $SERVER_ADDR/u-boot.itb -O u-boot.itb
    wget $SERVER_ADDR/boot.img -O boot.img
    wget $SERVER_ADDR/px30_loader_v1.14.120.bin -O px30_loader_v1.14.120.bin
fi

## 下载系统镜像(文件比较大,所以用AXEL!)
if [ "$DOWNLOAD_ROOTFS" = true ]; then
    rm -rf linaro-rootfs.img
    wget $SERVER_ADDR/linaro-rootfs.img -O linaro-rootfs.img
fi

## 开始烧录
if [ "$DOWNLOAD_BOARD" = true ]; then
    chmod a+x rkdeveloptool
    ./rkdeveloptool db px30_loader_v1.14.120.bin
    # 等待Loader成功启动后才可以继续烧录.
    sleep 1
    ./rkdeveloptool gpt parameter_gpt.txt
    ./rkdeveloptool wl 0x40 idbloader.img
    ./rkdeveloptool wl 0x4000 u-boot.itb
    ./rkdeveloptool wl 0x8000 boot.img
    ./rkdeveloptool wl 0x40000 linaro-rootfs.img
    ./rkdeveloptool rd
fi