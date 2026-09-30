#!/bin/bash

# Flash provided USB device with latest fedora ISO
SCRIPT="$(basename "$0")"
ISO_FOLDER="../../output-build/Fedora.x86_64-44.install.iso"

cd "$(dirname "$0")"

print_usage() {
  echo "Usage:"
  echo "./$SCRIPT <device> [iso]"
  echo
  echo "<device>  where to flash the iso"
  echo "[iso]     optional iso file path, defaults to $ISO_FOLDER"
}

if [ $# -lt 1 ]; then
  echo "Missing device"
  echo 
  print_usage
  exit 1
fi

DEVICE="$1"

# Check if device exists
if [[ ! -b "$DEVICE" ]]; then
  echo "ERROR: Could not find the device \"$DEVICE\"" >&2
  exit 1
fi

if [[ $# -eq 2 ]]; then
  if [[ ! -f "$2" ]]; then
    echo "ERROR: Provided ISO file does not exist";
    exit 1
  else
    ISO_FOLDER="$2"
  fi  
fi

dd if=$ISO_FOLDER of=$DEVICE status=progress
