#!/bin/bash
# Boots the OEM install ISO built by playbooks/build_iso.yml in a QEMU VM.
#
# First run: creates a virtual disk, boots the ISO and installs the system on
# the disk. The installer reboots at the end (oem-reboot): QEMU is started with
# -no-reboot so it exits, then the VM is restarted from the installed disk.
# Next runs: boots directly from the installed disk.
#
# Live mode (--live): boots the built disk image (*.raw) directly, without
# installing, on a temporary overlay: all changes are discarded at shutdown.

set -euo pipefail

SCRIPT="$(basename "$0")"
cd "$(dirname "$0")"

ISO="../output-build/Fedora.x86_64-44.install.iso"
RAW="../output-build/Fedora.x86_64-44.raw"
LIVE=0
VM_DIR="../output-qemu"
DISK_SIZE="16G"
MEMORY="4096"
CPUS="2"
SSH_PORT="2222"
FORCE_INSTALL=0
RESET=0
DISPLAY_OPT="gtk"

print_usage() {
  echo "Usage:"
  echo "./$SCRIPT [options]"
  echo
  echo "Options:"
  echo "  -i, --iso <file>      ISO file to install, defaults to $ISO"
  echo "  -l, --live [raw]      boot the built disk image without installing, changes are"
  echo "                        discarded at shutdown; raw image defaults to $RAW"
  echo "  -s, --size <size>     virtual disk size, defaults to $DISK_SIZE"
  echo "  -m, --memory <MiB>    VM memory, defaults to $MEMORY"
  echo "  -c, --cpus <n>        VM cpus, defaults to $CPUS"
  echo "  -p, --ssh-port <port> host port forwarded to guest ssh (22), defaults to $SSH_PORT"
  echo "  -I, --install         boot the ISO again and reinstall on the existing disk"
  echo "  -r, --reset           delete disk and UEFI vars and start from scratch"
  echo "  -n, --nographic       no graphical window, serial console on terminal"
  echo "  -h, --help            show this help"
  echo
  echo "Connect to the guest with: ssh -p $SSH_PORT collaudo@localhost"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  -i | --iso)
    ISO="$(cd "$OLDPWD" && realpath -- "$2")"
    shift 2
    ;;
  -l | --live)
    LIVE=1
    if [[ $# -gt 1 && "$2" != -* ]]; then
      RAW="$(cd "$OLDPWD" && realpath -- "$2")"
      shift
    fi
    shift
    ;;
  -s | --size)
    DISK_SIZE="$2"
    shift 2
    ;;
  -m | --memory)
    MEMORY="$2"
    shift 2
    ;;
  -c | --cpus)
    CPUS="$2"
    shift 2
    ;;
  -p | --ssh-port)
    SSH_PORT="$2"
    shift 2
    ;;
  -I | --install)
    FORCE_INSTALL=1
    shift
    ;;
  -r | --reset)
    RESET=1
    shift
    ;;
  -n | --nographic)
    DISPLAY_OPT="none"
    shift
    ;;
  -h | --help)
    print_usage
    exit 0
    ;;
  *)
    echo "ERROR: Unknown option \"$1\"" >&2
    echo
    print_usage
    exit 1
    ;;
  esac
done

for cmd in qemu-system-x86_64 qemu-img; do
  if ! command -v "$cmd" >/dev/null; then
    echo "ERROR: \"$cmd\" not found, install qemu (Fedora: qemu-kvm qemu-img, Ubuntu: qemu-system-x86 qemu-utils)" >&2
    exit 1
  fi
done

# UEFI firmware is required (kiwi image built with firmware="uefi").
# Paths differ between Fedora (edk2-ovmf) and Ubuntu/Debian (ovmf).
OVMF_CODE=""
OVMF_VARS_TEMPLATE=""
for pair in \
  "/usr/share/edk2/ovmf/OVMF_CODE.fd:/usr/share/edk2/ovmf/OVMF_VARS.fd" \
  "/usr/share/OVMF/OVMF_CODE_4M.fd:/usr/share/OVMF/OVMF_VARS_4M.fd" \
  "/usr/share/OVMF/OVMF_CODE.fd:/usr/share/OVMF/OVMF_VARS.fd" \
  "/usr/share/edk2/x64/OVMF_CODE.4m.fd:/usr/share/edk2/x64/OVMF_VARS.4m.fd"; do
  code="${pair%%:*}"
  vars="${pair##*:}"
  if [[ -f "$code" && -f "$vars" ]]; then
    OVMF_CODE="$code"
    OVMF_VARS_TEMPLATE="$vars"
    break
  fi
done

if [[ -z "$OVMF_CODE" ]]; then
  echo "ERROR: UEFI firmware (OVMF) not found, install edk2-ovmf (Fedora) or ovmf (Ubuntu)" >&2
  exit 1
fi

DISK="$VM_DIR/disk.qcow2"
OVMF_VARS="$VM_DIR/OVMF_VARS.fd"

if [[ $RESET -eq 1 ]]; then
  echo "Removing $DISK and $OVMF_VARS"
  rm -f "$DISK" "$OVMF_VARS"
fi

mkdir -p "$VM_DIR"

INSTALL=$FORCE_INSTALL
[[ -f "$DISK" || $LIVE -eq 1 ]] || INSTALL=1

if [[ $INSTALL -eq 1 && ! -f "$ISO" ]]; then
  echo "ERROR: ISO file \"$ISO\" does not exist, build it with playbooks/build_iso.yml" >&2
  exit 1
fi

if [[ $LIVE -eq 0 && ! -f "$DISK" ]]; then
  echo "Creating virtual disk $DISK ($DISK_SIZE)"
  qemu-img create -f qcow2 "$DISK" "$DISK_SIZE" >/dev/null
fi

if [[ $LIVE -eq 0 && ! -f "$OVMF_VARS" ]]; then
  cp "$OVMF_VARS_TEMPLATE" "$OVMF_VARS"
fi

ACCEL=(-machine q35)
if [[ -r /dev/kvm && -w /dev/kvm ]]; then
  ACCEL+=(-accel kvm -cpu host)
else
  echo "WARNING: /dev/kvm not accessible, running without acceleration (slow)" >&2
  ACCEL+=(-accel tcg -cpu max)
fi

if [[ "$DISPLAY_OPT" == "none" ]]; then
  DISPLAY_ARGS=(-nographic)
else
  DISPLAY_ARGS=(-display gtk -vga virtio)
fi

run_qemu() {
  local extra=("$@")
  qemu-system-x86_64 \
    "${ACCEL[@]}" \
    -m "$MEMORY" \
    -smp "$CPUS" \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$OVMF_VARS" \
    -drive if=none,id=disk0,format=qcow2,file="$DISK" \
    -device virtio-blk-pci,drive=disk0,bootindex=1 \
    -netdev user,id=net0,hostfwd=tcp::"$SSH_PORT"-:22 \
    -device virtio-net-pci,netdev=net0 \
    -device qemu-xhci -device usb-tablet \
    "${DISPLAY_ARGS[@]}" \
    "${extra[@]}"
}

if [[ $LIVE -eq 1 ]]; then
  if [[ ! -f "$RAW" ]]; then
    echo "ERROR: disk image \"$RAW\" does not exist, build it with playbooks/build_iso.yml" >&2
    exit 1
  fi
  # Temporary overlay on top of the read-only raw image (owned by root after
  # the build): the guest writes go to the overlay, removed at exit. The overlay
  # is at least $DISK_SIZE so oem-resize can grow the root partition.
  DISK="$(mktemp -p "$VM_DIR" live.XXXXXX.qcow2)"
  OVMF_VARS="$(mktemp -p "$VM_DIR" OVMF_VARS.live.XXXXXX.fd)"
  trap 'rm -f "$DISK" "$OVMF_VARS"' EXIT
  qemu-img create -q -f qcow2 -b "$(realpath "$RAW")" -F raw "$DISK"
  # grow to $DISK_SIZE, keep the raw image size if it is already bigger
  qemu-img resize -q "$DISK" "$DISK_SIZE" 2>/dev/null || true
  cp "$OVMF_VARS_TEMPLATE" "$OVMF_VARS"
  echo "Live boot of $RAW, changes are discarded at shutdown (ssh -p $SSH_PORT collaudo@localhost)"
  run_qemu
  exit 0
fi

if [[ $INSTALL -eq 1 ]]; then
  echo "Installing from $ISO (the VM restarts from disk when the installer reboots)"
  echo
  echo ">>> In the ISO boot menu select \"Install\" within 5 seconds: the default entry is"
  echo ">>> \"Boot from Hard Disk\", which on an empty disk ends in \"No bootable option or device\"."
  echo ">>> If that happens, close the VM window and rerun: ./$SCRIPT --install"
  echo
  run_qemu \
    -drive if=none,id=cd0,media=cdrom,readonly=on,file="$ISO" \
    -device ide-cd,drive=cd0,bootindex=0 \
    -no-reboot
fi

echo "Booting from $DISK (ssh -p $SSH_PORT collaudo@localhost)"
run_qemu
