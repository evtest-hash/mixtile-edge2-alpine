# Mixtile mainline Alpine Linux system image building 

## System Requirements:

Debian 12(Bookworm) / Ubuntu 22.04 (Jammy) or above

## Install Dependency:

```shell
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y build-essential gcc-aarch64-linux-gnu bison \
qemu-user-static qemu-system-arm qemu-efi u-boot-tools binfmt-support \
debootstrap flex libssl-dev bc rsync kmod cpio xz-utils fakeroot parted \
udev dosfstools uuid-runtime git-lfs device-tree-compiler python2 python3 \
python-is-python3 fdisk bc debhelper python3-pyelftools python3-setuptools \
python3-distutils python3-pkg-resources swig libfdt-dev libpython3-dev
```
## Build System Images:

1. ### Build u-boot & kernel:
```shell
./build-base.sh
```
2. ### Build alpine linux system image:

```shell
sudo ./build-image-alpine-minimal.sh
```

output image: alpine-mixtile-edge2-3.19-aarch64.img.xz

System image should be uncompressed by xz before being installed to device.

## Prepare upgrade tool:
```shell
git clone https://github.com/rockchip-linux/rkdeveloptool.git
cd rkdeveloptool
sudo apt-get install libudev-dev libusb-1.0-0-dev dh-autoreconf
aclocal
autoreconf -i
autoheader
automake --add-missing
./configure
make
```
## Install system image to device:
```shell
wget https://downloads.mixtile.com/edge2/MiniLoaderAll.bin
sudo ./rkdeveloptool db MiniLoaderAll.bin
sudo ./rkdeveloptool wl 0 alpine-mixtile-edge2-3.19-aarch64.img
sudo ./rkdeveloptool rd
```