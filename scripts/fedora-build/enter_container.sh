#!/bin/sh
# Enter fedora container to build the image
# Must be run as root because kiwi-ng requires access to /dev

if ! [ $(id -u) = 0 ]; then
   echo "This script must be run as root" 
   exit 1
fi

cd "$(dirname "$0")"

podman run -it --privileged \
  -v /dev:/dev \
  -v "../../":/build \
  fedora-collaudo-mkiso
