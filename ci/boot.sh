#!/bin/bash

VM_NAME="inner"
DISK_IMAGE="/tmp/ubuntu.qcow2"
ROOT_DISK="/var/lib/libvirt/images/$VM_NAME/root-disk.qcow2"

sudo mkdir /var/lib/libvirt/images/$VM_NAME \
  && sudo qemu-img convert \
  -f qcow2 \
  -O qcow2 \
  $DISK_IMAGE \
  $ROOT_DISK

sudo qemu-img resize \
  $ROOT_DISK \
  20G

ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -P ""

sudo echo "#cloud-config
users:
  - default
  - name: runner
    ssh-authorized-keys:
      - $(cat ~/.ssh/id_rsa.pub)
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash

network:
  version: 2
  renderer: networkd
  ethernets:
    alleths:
      match:
        name: en*
      dhcp4: true

hostname: $VM_NAME

runcmd:
  - apt-get update
  - apt install build-essential cmake wget apt-transport-https
  - wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/dart.gpg
  - echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | tee /etc/apt/sources.list.d/dart_stable.list
  - apt-get install dart

" | sudo tee /var/lib/libvirt/images/$VM_NAME/cloud-init.cfg

sudo cloud-localds \
  /var/lib/libvirt/images/$VM_NAME/cloud-init.iso \
  /var/lib/libvirt/images/$VM_NAME/cloud-init.cfg

sudo virt-install --import \
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