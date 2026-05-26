#!/bin/bash
set -euo pipefail

eselect kernel list
printf "Which kernel version to use? "
read -r answer

eselect kernel set "${answer}"

CONFIG=/tmp/mykernel.config

zcat /proc/config.gz > "${CONFIG}"

if grep -q '^CONFIG_LOCALVERSION=' "${CONFIG}"; then
    sed -i "s/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"-$(date +%Y%m%d)\"/" "${CONFIG}"
else
    echo "CONFIG_LOCALVERSION=\"-$(date +%Y%m%d)\"" >> "${CONFIG}"
fi

genkernel --kernel-config="${CONFIG}" all

grub-mkconfig -o /boot/grub/grub.cfg

ls -lah /boot
