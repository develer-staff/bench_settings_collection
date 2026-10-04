#!/bin/sh
# Create a Fedora distro in output-build
# ~15 minutes

cd "$(dirname "$0")"

rm -rf ../../output-build/*

cd ../../kiwi-descriptions

# kiwi-build automatically appends build to output-dir (i.e. output-dir=../output-build)
./kiwi-build --output-dir=../output --image-type=oem --image-profile=LXDE-Disk
