#!/bin/bash

apt install -y \
    bridge-utils \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    virtinst \
    libguestfs-tools \
    wait-for-it \
    whois \
    sshpass

virsh net-destroy default
virsh net-undefine default
virsh net-define ./default_network.xml
virsh net-autostart default
virsh net-start default

exit 0
