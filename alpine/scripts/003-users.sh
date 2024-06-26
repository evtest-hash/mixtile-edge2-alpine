#!/bin/sh

set -eux

FIRST_USER_NAME=mixtile

apk add sudo

for GRP in spi i2c gpio; do
	getent group "$GRP" >/dev/null || addgroup --system "$GRP"
done

adduser -s /bin/ash -D "$FIRST_USER_NAME"

for GRP in adm dialout audio users video games input gpio spi i2c netdev; do
  adduser "$FIRST_USER_NAME" "$GRP"
done

echo "mixtile:mixtile" | /usr/sbin/chpasswd
echo "mixtile ALL=NOPASSWD: ALL" >> /etc/sudoers

# todo what to do with root password?
