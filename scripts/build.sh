#!/bin/sh
# Create a Fedora distro in output-build
# ~15 minutes

cd "$(dirname "$0")"

sudo rm -rf ../output-build/*

sudo podman run -it --privileged \
  -v /dev:/dev \
  -v "../":/build \
  -w /build/kiwi-descriptions \
  fedora-collaudo-mkiso \
  ./kiwi-build --output-dir=../output --image-type=oem --image-profile=LXDE-Disk # kiwi-build automatically appends build to output-dir (i.e. output-dir=../output-build)
