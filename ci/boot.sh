#!/bin/bash

OS_TYPE="ubuntu-22.10-cloud"
VM_NAME="inner"
DISK_IMAGE="./ubuntu.img"

usermod -G libvirt -a $USER
chown libvirt-qemu:libvirt-qemu $DISK_IMAGE

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