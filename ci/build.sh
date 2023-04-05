#!/bin/bash


OS_TYPE="ubuntu-22.10"
VM_NAME="inner"
DISK_IMAGE="/tmp/$VM_NAME.qcow2"

USER_NAME="ubuntu"
USER_PASS=`mkpasswd ubuntu`
USER_HOME=`pwd`

virt-builder "$OS_TYPE" \
    --hostname "$VM_NAME" \
    --network \
    --timezone "`cat /etc/timezone`" \
    --format qcow2 -o "$DISK_IMAGE" \
    --update \
    --install "linux-image-5.19.0.38.34-generic,linux-modules-5.19.0.38.34-generic,linux-modules-extra-5.19.0.38.34-generic,linux-tools-5.19.0.38.34-generic" \
    --run-command "useradd -p $USER_PASS -s /bin/bash -m -d $USER_HOME -G sudo $USER_NAME" \
    --edit '/etc/sudoers:s/^%sudo.*/%sudo	ALL=(ALL) NOPASSWD:ALL/' \
    --edit '/etc/default/grub:s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="console=tty0 console=ttyS0,115200n8"/' \
    --run-command update-grub \
    --upload netcfg.yaml:/etc/netplan/netcfg.yaml \
    --run-command "chown root:root /etc/netplan/netcfg.yaml" \
    --run-command 'echo "runner '"$USER_HOME"' 9p defaults,_netdev 0 0" >> /etc/fstab' \
    --firstboot-command "dpkg-reconfigure openssh-server"

mv "$DISK_IMAGE" "$DISK_IMAGE.old"
qemu-img convert -O qcow2 -c "$DISK_IMAGE.old" "$DISK_IMAGE"
rm -f "$DISK_IMAGE.old"