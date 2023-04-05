#!/bin/bash

OS_TYPE="ubuntu-22.10-cloud"
VM_NAME="inner"
DISK_IMAGE="ubuntu-22.10-server-cloudimg-amd64.img"

if [ ! -f "$DISK_IMAGE" ]; then
  wget https://cloud-images.ubuntu.com/releases/22.10/release/ubuntu-22.10-server-cloudimg-amd64.img
fi

virt-install --import \
    --name "$VM_NAME" \
    --vcpu 2 \
    --ram 2048 \
    --disk path="$DISK_IMAGE" \
    --os-variant ubuntu20.04 \
    --network network:default \
    --graphics none \
    --console pty,target_type=serial \
    --noautoconsole \
    --filesystem "`pwd`",runner