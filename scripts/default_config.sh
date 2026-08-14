#!/bin/bash

# Configuration file version
export CONFIG_FILE_VERSION="0.4"

# Target OS Name
export TARGET_NAME="lampuntu"

# Target Ubuntu version (24.04 LTS Noble Numbat)
export TARGET_UBUNTU_VERSION="noble"

# Ubuntu Mirror
export TARGET_UBUNTU_MIRROR="http://us.archive.ubuntu.com/ubuntu/"

# Linux Kernel Package
export TARGET_KERNEL_PACKAGE="linux-generic"

# GRUB boot menu labels
export GRUB_LIVEBOOT_LABEL="Try Lampuntu 24.04 LTS without installing"
export GRUB_INSTALL_LABEL="Install Lampuntu 24.04 LTS"

# Packages to remove after installation
export TARGET_PACKAGE_REMOVE="
    ubiquity \
    casper \
    discover \
    laptop-detect \
    os-prober \
"

# Package customization function
function customize_image() {
    # Install graphics and minimal desktop
    apt-get install -y \
        plymouth-themes \
        ubuntu-desktop-minimal \
        ubuntu-wallpapers

    # Install necessary tools
    apt-get install -y \
        apt-transport-https \
        curl \
        wget \
        vim \
        nano \
        less

    # Execute custom Lampuntu rebrand script inside chroot
    if [ -f "/root/make-lampuntu.sh" ]; then
        bash /root/make-lampuntu.sh
    fi

    # Purge unused default applications
    apt-get purge -y \
        transmission-gtk \
        transmission-common \
        gnome-mahjongg \
        gnome-mines \
        gnome-sudoku \
        aisleriot \
        hitori
}
