#!/bin/sh

# Bootstrap script
# This script should be run only once

cd "$(dirname "$0")"

# Ansible is a prerequisite
if ! command -v ansible >/dev/null 2>&1; then
    echo "ansible must be installed in order to proceeed" >&2
    exit 1
fi 

# Create a podman Fedora container to build the custom ISo as described in the Dockerfile
sudo podman build -t fedora-collaudo-mkiso .

# Setup rclone
ansible-playbook ../playbooks/rclone_setup.yml -K --ask-vault-pass

