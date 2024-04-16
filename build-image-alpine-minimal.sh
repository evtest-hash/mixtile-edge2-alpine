#!/usr/bin/env bash

# these scripts are based on https://github.com/knoopx/alpine-raspberry-pi.

set -eux

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

enter_chroot=false
if [[ "${1:-}" == "shell" ]]; then
  shift
  enter_chroot=true
fi

ALPINE_VERSION="${1:-3.19}"
ALPINE_ARCH="${2:-aarch64}"

if [[ "$ALPINE_ARCH" == "" ]] || [[ "$ALPINE_VERSION" == "" ]]; then
  echo "Error: must specify arguments alpine arch and version"
  echo "Usage:"
  echo "  $0 <version> <arch>"
  echo ""
  echo "Example:"
  echo "  $0 v3.10.2 aarch64"
fi

alpine_branch="$(echo "$ALPINE_VERSION" | awk -F. '{gsub("^v", "", $1); print "v"$1"."$2}')"

tmpdir="$(mktemp -d -t "alpine-mixtile-edge2-$ALPINE_VERSION-$ALPINE_ARCH.XXXXXXXXXX")"
artifact_file="$script_dir/alpine-mixtile-edge2-$ALPINE_VERSION-$ALPINE_ARCH.img"
rootfs="$tmpdir"
boot_dir="$rootfs/boot"
build_dir="$rootfs/alpine"

clean_up() {
  [[ -x "$rootfs/destroy" ]] && "$rootfs/destroy" -y || true
  findmnt -M "$rootfs" && umount "$rootfs"
  [[ -n "$tmpdir" ]] && rm -rf "$tmpdir"
  losetup --detach-all # todo this should be only the current loop
}
trap clean_up SIGTERM SIGINT SIGQUIT

rm -rf "$artifact_file"
truncate -s 1024M  "$artifact_file"

parted --script "${artifact_file}" \
mklabel msdos \
mkpart primary fat32 16MiB 80MiB \
mkpart primary ext4 80MiB 100% \
set 1 boot on

LOOP_DEV=$(losetup --partscan --show --find "$artifact_file")
BOOT_DEV="$LOOP_DEV"p1
ROOT_DEV="$LOOP_DEV"p2


# format partitions
mkfs.fat -F32 -n ALPINE "$BOOT_DEV"
mkfs.ext4 -O '^has_journal' "$ROOT_DEV"
mkdir -p "$rootfs"
mount --make-private "$ROOT_DEV" "$rootfs"
mkdir -p "$boot_dir"
mount  --make-private "$BOOT_DEV" "$boot_dir"
mkdir -p "$build_dir"
mount --bind "$script_dir/alpine" "$build_dir"

echo "Setup bootloader..."
dd if="u-boot/deploy/idbloader.img" of="$LOOP_DEV" bs=512 seek=64 conv=notrunc
dd if="u-boot/deploy/u-boot.itb" of="$LOOP_DEV" bs=512 seek=16384 conv=notrunc

echo "Setup kernel..."
cp -v "kernel/deploy/Image" "$boot_dir"
cp -v "kernel/deploy/rk3568-mixtile-edge2.dtb" "$boot_dir"
cp -v "deploy/boot.scr" "$boot_dir"
mkdir -p "$rootfs/lib/modules"
tar -xf "kernel/deploy/kmods.tar.gz" -C "$rootfs"

sudo ./alpine-chroot-install \
  -a "$ALPINE_ARCH" \
  -b "$alpine_branch" \
  -d "$rootfs" \
  -k "ARCH CI QEMU_EMULATOR RPI_CI_.* TRAVIS_.*" \
  -p "alpine-base ca-certificates ssl_client"

"${script_dir}/alpine/run.sh" "$rootfs"

if [[ "$enter_chroot" == "true" ]]; then
  "$rootfs/enter-chroot"
fi

"$rootfs/destroy"

file_dirs=(
  var/cache/apk
  root
  enter-chroot
  destroy
  etc/resolv.conf
  env.sh
)
for file_dir in "${file_dirs[@]}"; do
  file_dir="$rootfs/$file_dir"
  ls -la "$file_dir"
  [[ -d "$file_dir" ]] && find "$file_dir" -mindepth 1 -delete
  [[ -f "$file_dir" ]] && rm "$file_dir"
done

umount -lf "$rootfs"

# shrink image
ROOT_PART_START=$(parted -ms "$artifact_file" unit B print | awk -F: 'END{gsub("B$", "", $2); print $2}')
ROOT_BLOCK_SIZE=$(tune2fs -l "$ROOT_DEV" | awk -F': *' '/^Block size:/{print $2}')
ROOT_MIN_SIZE=$(resize2fs -P "$ROOT_DEV" 2>/dev/null | awk -F': *' '/:/{print $2}')

# shrink fs
e2fsck -f -p "$ROOT_DEV"
resize2fs -p "$ROOT_DEV" "$ROOT_MIN_SIZE"

# shrink partition
PART_END=$((ROOT_PART_START + (ROOT_MIN_SIZE * ROOT_BLOCK_SIZE)))
echo Yes | parted ---pretend-input-tty "$artifact_file" unit B resizepart 2 "$PART_END" 

sync --file-system
sync

losetup -d "$LOOP_DEV"

# truncate free space
FREE_START=$(parted -ms "$artifact_file" unit B print free | awk -F: 'END{gsub("B$", "", $2); print $2}')
truncate -s "$FREE_START" "$artifact_file"

echo -e "\nCompressing $(basename "${artifact_file}.xz")\n"
xz -3 --force --keep --quiet --threads=0 "${artifact_file}"
rm -rf "${artifact_file}"

echo "DONE."
