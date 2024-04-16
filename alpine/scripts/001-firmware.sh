#!/bin/sh

set -ux

apk add usbutils kmod bluez bluez-deprecated alpine-conf
mkdir -p /lib/firmware/brcm
cp /alpine/assets/firmware/* /lib/firmware/brcm
setup-devd udev
exit 0


