#!/bin/sh

# Build fedora container with required tools to build ISO
# Must be run as root because otherwise sudo can't find it

cd "$(dirname "$0")"

if ! [ $(id -u) = 0 ]; then
   echo "This script must be run as root" 
   exit 1
fi

podman build -t fedora-collaudo-mkiso .
