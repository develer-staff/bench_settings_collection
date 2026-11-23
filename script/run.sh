#!/bin/sh

# Usage:
# $ ./run_vm.sh <Fedora-x86_64-xx-y.z.iso>
# 
# The resulting QEMU virtual machine provide ssh connection on port 2222
# and remote connection through SPICE protocol (which enables copy/paste)
# To access it:
# $ remote-viewer spice://127.0.0.1:5900
# 
# Reference:
# https://developer.fedoraproject.org/tools/virtualization/setting-up-fedora-workstation-vm-on-qemu-using-bios.html

DISK_NAME=fedora.raw
DISK_SIZE=64G
SCRIPT_DIR="$(dirname "$0")"
DISK_PATH="$SCRIPT_DIR/$DISK_NAME"

script=$(basename "$0")

print_usage() {
  echo "Usage: ./$script [ISO]"
  echo ""
  echo "[ISO]: ISO path, if not provided it just boots from $DISK_PATH"
}

if [ ! -f "$DISK_PATH" ]; then
  qemu-img create -f raw $DISK_PATH $DISK_SIZE
  echo "$DISK_PATH created."
else
  echo "$DISK_PATH already exists."
fi

ADD_ISO=""

if [ $# -eq 1 ]; then
  ISO_NAME="$(basename "$1")"
  echo "Adding $ISO_NAME as boot option"

  if [ ! -f "$1" ]; then
    echo "File $1 not found";
    exit 1;
  fi

  ADD_ISO="-cdrom $1"
fi

echo "Starting virtual machine."
echo "Once running, view it with:"
echo "  remote-viewer spice://127.0.0.1:5900"

qemu-system-x86_64 \
    -boot d \
    -m 8192 \
    -cpu max \
    -smp 6 \
    $ADD_ISO \
    -drive file=$DISK_PATH,format=raw \
    -netdev user,id=vnet,hostfwd=tcp::2222-:22 \
    -device virtio-net-pci,netdev=vnet \
    -accel kvm \
    -vga qxl \
    -spice port=5900,disable-ticketing=on \
    -device virtio-serial-pci \
    -device virtserialport,chardev=vdagent,name=com.redhat.spice.0 \
    -chardev spicevmc,id=vdagent,name=vdagent  
