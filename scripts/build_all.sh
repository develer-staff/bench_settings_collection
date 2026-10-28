#!/bin/sh

cd "$(dirname "$0")"

./fedora-build/build_container.sh

./fedora-build/run_build.sh
