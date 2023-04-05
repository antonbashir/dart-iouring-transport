#!/bin/bash

VM_NAME="inner"
DISK_IMAGE="/tmp/ubuntu.qcow2"
ROOT_DISK="/var/lib/libvirt/images/$VM_NAME/root-disk.qcow2"

mkdir /var/lib/libvirt/images/$VM_NAME \
  && qemu-img convert \
  -f qcow2 \
  -O qcow2 \
  $DISK_IMAGE \
  $ROOT_DISK

qemu-img resize \
  $ROOT_DISK \
  20G

echo "#cloud-config
system_info:
  default_user:
    name: ubuntu
    home: /home/ubuntu

password: ubuntu
chpasswd: { expire: False }
hostname: $VM_NAME

# configure sshd to allow users logging in using password 
# rather than just keys
ssh_pwauth: True
" |  tee /var/lib/libvirt/images/$VM_NAME/cloud-init.cfg

sudo cloud-localds \
  /var/lib/libvirt/images/$VM_NAME/cloud-init.iso \
  /var/lib/libvirt/images/$VM_NAME/cloud-init.cfg

virt-install --import \
    --name "$VM_NAME" \
    --vcpu 2 \
    --ram 2048 \
    --disk $ROOT_DISK,device=disk,bus=virtio \
    --disk /var/lib/libvirt/images/$VM_NAME/cloud-init.iso,device=cdrom \
    --os-variant ubuntu20.04 \
    --network network:default \
    --graphics none \
    --console pty,target_type=serial \
    --noautoconsole