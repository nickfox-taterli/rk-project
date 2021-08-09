# Rockchip PX30 Custom Board Project

------

这个项目是为了我的PX30板做的,所以具体不兼容其他板很正常,仅供参考,共同进步.

## 编译笔记

### 1. 编译ATF

```shell
cd arm-trusted-firmware
make realclean
CFLAGS='-gdwarf-2' CROSS_COMPILE=/root/project/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu- make PLAT=px30 DEBUG=0 ERROR_DEPRECATED=1 bl31
cp build/px30/release/bl31/bl31.elf ../u-boot/bl31.elf
cd ../
```

### 2. 编译引导

```shell
cd u-boot
make ARCH=arm CROSS_COMPILE=/root/project/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu- evb-px30_defconfig
make ARCH=arm CROSS_COMPILE=/root/project/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu- menuconfig
make ARCH=arm CROSS_COMPILE=/root/project/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu- u-boot.itb
make ARCH=arm CROSS_COMPILE=/root/project/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-
cd ../
```

### 3. 编译内核

```shell
cd kernel
make ARCH=arm64 CROSS_COMPILE=/root/project/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu- rockchip_linux_defconfig
make ARCH=arm64 CROSS_COMPILE=/root/project/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu- -j4
make ARCH=arm64 CROSS_COMPILE=/root/project/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu- px30-evb-ddr3-v11.img
cd ../
```

### 4. 制作系统镜像

```shell
cd rk-rootfs-build
apt-get install binfmt-support qemu-user-static
dpkg -i ubuntu-build-service/packages/*
apt-get install -f -y
RELEASE=buster TARGET=base ARCH=arm64 ./mk-base-debian.sh
RELEASE=buster TARGET=base ARCH=arm64 ./mk-rootfs.sh
./mk-image.sh
cd ../
```

### 5. 编译烧录工具(官方版)

```shell
cd rkdeveloptool
apt-get install libudev-dev libusb-1.0-0-dev dh-autoreconf
aclocal
autoreconf -i
autoheader
automake --add-missing
./configure
make
cd ../
```

### 6. 编译烧录工具(社区版)

```shell
cd rkflashtool
apt-get install libusb-1.0-0-dev
make
cd ../
```

## 引导和烧录相关

### 1. 烧录方法(官方版)

```shell
./rkdeveloptool db px30_loader_v1.14.120.bin
# 等待Loader成功启动后才可以继续烧录.
sleep 1
./rkdeveloptool gpt parameter_gpt.txt
./rkdeveloptool wl 0x40 idbloader.img
./rkdeveloptool wl 0x4000 u-boot.itb
./rkdeveloptool wl 0x8000 boot.img
./rkdeveloptool wl 0x40000 linaro-rootfs.img
./rkdeveloptool rd
```

### 2. 分区参考

```text
FIRMWARE_VER: 8.1
MACHINE_MODEL: PX30
MACHINE_ID: 007
MANUFACTURER: PX30
MAGIC: 0x5041524B
ATAG: 0x00200800
MACHINE: px30
CHECK_MASK: 0x80
PWR_HLD: 0,0,A,0,1
TYPE: GPT
CMDLINE: mtdparts=rk29xxnand:0x00001f40@0x00000040(loader1),0x00000080@0x00001f80(reserved1),0x00002000@0x00002000(reserved2),0x00002000@0x00004000(loader2),0x00002000@0x00006000(atf),0x00038000@0x00008000(boot:bootable),-@0x0040000(rootfs:grow)
uuid:rootfs=a26ad83c-802b-4321-ac9b-b7d356d112af
```

### 3. boot.img 制作

```shell
../u-boot/tools/mkimage -n px30 -T rksd -d ../u-boot/tpl/u-boot-tpl.bin idbloader.img
cat ../u-boot/spl/u-boot-spl.bin >> idbloader.img
cp ../u-boot/u-boot.itb .
genext2fs -b 32768 -B $((32*1024*1024/32768)) -d boot/ -i 8192 -U boot.img
```
