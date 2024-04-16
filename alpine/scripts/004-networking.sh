#!/bin/sh

set -eux

cp /alpine/assets/network-interfaces /etc/network/interfaces

apk add dbus avahi
