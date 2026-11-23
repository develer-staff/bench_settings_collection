#!/bin/sh
# Creates a Fedora distro in ./output-build
# ~15 minutes

cd "$(dirname "$0")"

sudo rm -rf ../output-build/*

# kiwi works in /var/tmp and rsyncs files there with --xattrs. On SELinux
# enforcing hosts (e.g. Fedora) the container overlay rejects the
# security.selinux xattr (fsetxattr: Operation not supported), so bind mount
# a host directory as the container /var/tmp, where labels can be set.
# KIWI_TMP can be provided by the caller (playbooks/build_iso.yml), which
# then takes care of removing it.
if [ -z "$KIWI_TMP" ]; then
  KIWI_TMP="$(sudo mktemp -d /var/tmp/kiwi-build.XXXXXX)"
  trap 'sudo rm -rf "$KIWI_TMP"' EXIT
fi

sudo podman run -it --privileged \
  -v /dev:/dev \
  -v "../":/build \
  -v "$KIWI_TMP":/var/tmp \
  -w /build/kiwi-descriptions \
  fedora-collaudo-mkiso \
  ./kiwi-build --output-dir=../output --image-type=oem --image-profile=MATE_Compiz-Disk #LXDE-Disk # kiwi-build automatically appends build to output-dir (i.e. output-dir=../output-build)
