#!/bin/bash
# This script should only be used to make a disk in the red hat demo environment when deploying the Image Mode Workshop

DISK=$(lsblk | grep G | grep -Ev 'vda|loop' | awk '{print $1}')
echo 'type=83' | sudo sfdisk /dev/${DISK}
sudo mkfs.xfs /dev/${DISK}1
echo "/dev/${DISK}1 /var/lib/libvirt/images xfs defaults 0 0" | sudo tee -a /etc/fstab
sudo systemctl daemon-reload
sudo mkdir -p /var/lib/libvirt/images
sudo mount -a
