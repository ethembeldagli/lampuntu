#!/bin/bash

set -e                 # exit on error
set -o pipefail        # exit on pipeline error
set -u                 # treat unset variable as error

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

CMD=(setup_host debootstrap run_chroot build_iso)

DATE=`TZ="UTC" date +"%y%m%d-%H%M%S"`

function help() {
    if [ -z ${1+x} ]; then
        echo -e "This script builds a bootable ubuntu ISO image"
        echo -e
    else
        echo -e $1
        echo
    fi
    echo -e "Supported commands : ${CMD[*]}"
    echo -e
    echo -e "Syntax: $0 [start_cmd] [-] [end_cmd]"
    echo -e "\trun from start_cmd to end_end"
    echo -e "\tif start_cmd is omitted, start from first command"
    echo -e "\tif end_cmd is omitted, end with last command"
    echo -e "\tenter single cmd to run the specific command"
    echo -e "\tenter '-' as only argument to run all commands"
    echo -e
    exit 0
}

function find_index() {
    local ret;
    local i;
    for ((i=0; i<${#CMD[*]}; i++)); do
        if [ "${CMD[i]}" == "$1" ]; then
            index=$i;
            return;
        fi
    done
    help "Command not found : $1"
}

function chroot_enter_setup() {
    sudo mount --bind /dev chroot/dev
    sudo mount --bind /run chroot/run
    sudo mount -t proc /proc chroot/proc
    sudo mount -t sysfs /sys chroot/sys
}

function chroot_exit_setup() {
    sudo umount -l chroot/dev || true
    sudo umount -l chroot/run || true
    sudo umount -l chroot/proc || true
    sudo umount -l chroot/sys || true
}

function setup_host() {
    echo "=========================================="
    echo " 1. SETTING UP HOST DEPENDENCIES         "
    echo "=========================================="
    sudo apt update
    sudo apt install -y \
        debootstrap \
        squashfs-tools \
        xorriso \
        grub-pc-bin \
        grub-efi-amd64-bin \
        mtools \
        dosfstools
}

function debootstrap() {
    echo "=========================================="
    echo " 2. RUNNING DEBOOTSTRAP                  "
    echo "=========================================="
    source "${SCRIPT_DIR}/config.sh"
    
    mkdir -p "${SCRIPT_DIR}/work"
    cd "${SCRIPT_DIR}/work"

    sudo debootstrap \
        --arch=amd64 \
        --variant=minbase \
        "${TARGET_UBUNTU_VERSION}" \
        chroot \
        "${TARGET_UBUNTU_MIRROR}"
}

function run_chroot() {
    echo "=========================================="
    echo " 3. CUSTOMIZING CHROOT SYSTEM             "
    echo "=========================================="
    source "${SCRIPT_DIR}/config.sh"

    cd "${SCRIPT_DIR}/work"

    # Copy make-lampuntu.sh into chroot root dir if it exists locally
    if [ -f "${SCRIPT_DIR}/make-lampuntu.sh" ]; then
        sudo cp "${SCRIPT_DIR}/make-lampuntu.sh" chroot/root/make-lampuntu.sh
        sudo chmod +x chroot/root/make-lampuntu.sh
    fi

    chroot_enter_setup

    # Execute custom commands inside chroot
    sudo chroot chroot /bin/bash -s << 'EOF_CHROOT'
set -e

source /etc/environment
export HOME=/root
export LC_ALL=C

# Setup sources list
cat << 'EOF_SOURCES' > /etc/apt/sources.list
deb http://us.archive.ubuntu.com/ubuntu/ noble main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu/ noble-updates main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu/ noble-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu noble-security main restricted universe multiverse
EOF_SOURCES

apt-get update
apt-get install -y systemd-sysv dbus

# Import functions and run customization
EOF_CHROOT

    # Run the customization function defined in config.sh inside chroot
    sudo chroot chroot /bin/bash -c "$(declare -f customize_image); customize_image"

    chroot_exit_setup
}

function build_iso() {
    echo "=========================================="
    echo " 4. BUILDING LAMPUNTU ISO                 "
    echo "=========================================="
    source "${SCRIPT_DIR}/config.sh"

    cd "${SCRIPT_DIR}/work"

    mkdir -p image/casper
    mkdir -p image/isolinux

    # Install kernel and casper in chroot
    chroot_enter_setup
    sudo chroot chroot apt-get install -y "${TARGET_KERNEL_PACKAGE}" casper grub-efi-amd64-signed
    chroot_exit_setup

    # Copy Kernel and Initrd
    sudo cp chroot/boot/vmlinuz-* image/casper/vmlinuz
    sudo cp chroot/boot/initrd.img-* image/casper/initrd

    # Create SquashFS filesystem
    sudo rm -f image/casper/filesystem.squashfs
    sudo mksquashfs chroot image/casper/filesystem.squashfs -e boot

    # Size calculation
    printf $(du -sx --block-size=1 chroot | cut -f1) > image/casper/filesystem.size

    # Configure GRUB
    cat << EOF_GRUB > image/isolinux/grub.cfg
search --set=root --file /casper/vmlinuz
insmod all_video

set default="0"
set timeout=10

menuentry "${GRUB_LIVEBOOT_LABEL}" {
    linux /casper/vmlinuz boot=casper quiet splash ---
    initrd /casper/initrd
}

menuentry "${GRUB_INSTALL_LABEL}" {
    linux /casper/vmlinuz boot=casper only-ubiquity quiet splash ---
    initrd /casper/initrd
}
EOF_GRUB

    # Generate EFI boot images
    mkdir -p image/EFI/boot
    grub-mkstandalone \
        --format=x86_64-efi \
        --output=image/isolinux/bootx64.efi \
        --locales="" \
        --fonts="" \
        "boot/grub/grub.cfg=image/isolinux/grub.cfg"

    cd image/isolinux
    dd if=/dev/zero of=efiboot.img bs=1M count=10
    mkfs.vfat efiboot.img
    mmd -i efiboot.img ::EFI
    mmd -i efiboot.img ::EFI/BOOT
    mcopy -i efiboot.img bootx64.efi ::EFI/BOOT/BOOTX64.EFI
    cd ../..

    # Create ISO file
    ISO_NAME="${TARGET_NAME}-${TARGET_UBUNTU_VERSION}-amd64-${DATE}.iso"

    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso-ribbon \
        -volid "LAMPUNTU_LIVE" \
        -output "../${ISO_NAME}" \
        -eltorito-boot isolinux/efiboot.img \
        -no-emul-boot \
        -eltorito-catalog isolinux/boot.cat \
        image

    echo "=========================================="
    echo " ISO CREATED SUCCESSFULLY: ${ISO_NAME}   "
    echo "=========================================="
}

# Command Line Parsing
if [ $# -eq 0 ]; then
    help
fi

if [ "$1" == "-" ]; then
    start_idx=0
    end_idx=$((${#CMD[*]} - 1))
else
    find_index "$1"
    start_idx=$index
    if [ $# -ge 2 ] && [ "$2" == "-" ]; then
        if [ $# -eq 3 ]; then
            find_index "$3"
            end_idx=$index
        else
            end_idx=$((${#CMD[*]} - 1))
        fi
    else
        end_idx=$start_idx
    fi
fi

for ((i=$start_idx; i<=$end_idx; i++)); do
    ${CMD[i]}
done
