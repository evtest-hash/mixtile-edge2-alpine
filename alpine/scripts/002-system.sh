#!/bin/sh

set -eux

targetHostname="mixtile"

# base stuff
apk add ca-certificates
update-ca-certificates
#ln -sT /etc/ssl /usr/ssl

setup-hostname "$targetHostname"
echo "127.0.0.1    $targetHostname $targetHostname.localdomain" > /etc/hosts

sed -i 's/^.*ttyS0.*$/ttyS2::respawn:\/sbin\/getty -L ttyS2 1500000 vt100/' /etc/inittab
