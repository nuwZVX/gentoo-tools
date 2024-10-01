#!/bin/bash

#sed -i "s/.*CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"-`date "+%Y%m%d"`\"/g" /usr/src/linux/.config

genkernel all && grub-mkconfig -o /boot/grub/grub.cfg

ls -la /boot
