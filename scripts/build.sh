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
        echo -e ""
    else
        echo -e "$1"
        echo ""
    fi
    echo -e "Supported commands : ${CMD[*]}"
    echo -e ""
    echo -e "Syntax: $0 [start_cmd] [-] [end_cmd]"
    echo -e "\trun from start_cmd to end_end"
    echo -e "\tif start_cmd is omitted, start from first command"
    echo -e "\tif end_cmd is omitted, end with last command"
    echo -e "\tenter single cmd to run the specific command"
    echo -e "\tenter '-' as only argument to run all commands"
    echo -e ""
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
    sudo mount --bind /dev chroot/dev || true
    sudo mount --bind /run chroot/run || true
    sudo mount -t proc none chroot/proc 2>/dev/null || true
    sudo mount -t sysfs none chroot/sys 2>/dev/null || true
    sudo mount -t devpts none chroot/dev/pts 2>/dev/null || true
}

function chroot_exit_teardown() {
    sudo umount -l chroot/dev/pts 2>/dev/null || true
    sudo umount -l chroot/proc 2>/dev/null || true
    sudo umount -l chroot/sys 2>/dev/null || true
    sudo umount -l chroot/dev 2>/dev/null || true
    sudo umount -l chroot/run 2>/dev/null || true
}

function check_host() {
    if [ "${GITHUB_ACTIONS:-false}" = "true" ] || [ "${CI:-false}" = "true" ]; then
        return 0
    fi

    local os_ver
    os_ver=`lsb_release -i 2>/dev/null | grep -E "(Ubuntu|Debian)" || true`
    if [[ -z "$os_ver" ]]; then
        echo "WARNING : OS is not Debian or Ubuntu and is untested"
    fi

    if [ $(id -u) -eq 0 ]; then
        echo "This script should not be run as 'root' directly (use sudo when invoking step commands)"
        exit 1
    fi
}

function load_config() {
    if [[ -f "$SCRIPT_DIR/config.sh" ]]; then
        . "$SCRIPT_DIR/config.sh"
    elif [[ -f "$SCRIPT_DIR/default_config.sh" ]]; then
        . "$SCRIPT_DIR/default_config.sh"
    else
        >&2 echo "Unable to find default config file $SCRIPT_DIR/default_config.sh, aborting."
        exit 1
    fi
}

function check_config() {
    local expected_config_version
    expected_config_version="0.4"

    if [[ "$CONFIG_FILE_VERSION" != "$expected_config_version" ]]; then
        >&2 echo "Invalid or old config version $CONFIG_FILE_VERSION, expected $expected_config_version. Please update your configuration file from the default."
        exit 1
    fi
}

function setup_host() {
    echo "=====> running setup_host ..."
    sudo apt update
    sudo apt install -y debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools dosfstools
    sudo mkdir -p chroot
}

function debootstrap() {
    echo "=====> running debootstrap ... will take a couple of minutes ..."
    sudo debootstrap --arch=amd64 --variant=minbase $TARGET_UBUNTU_VERSION chroot $TARGET_UBUNTU_MIRROR
}

function run_chroot() {
    echo "=====> running run_chroot ..."

    chroot_enter_setup

    if [[ -f "$SCRIPT_DIR/make-lampuntu.sh" ]]; then
        sudo cp "$SCRIPT_DIR/make-lampuntu.sh" chroot/root/make-lampuntu.sh
        sudo chmod +x chroot/root/make-lampuntu.sh
    fi

    if [[ -f "$SCRIPT_DIR/lampuntu-logo.ansi.txt" ]]; then
        sudo cp "$SCRIPT_DIR/lampuntu-logo.ansi.txt" chroot/etc/lampuntu-logo.ansi.txt
    fi

    if [[ -f "$SCRIPT_DIR/config.sh" ]]; then
        sudo cp "$SCRIPT_DIR/config.sh" chroot/root/config.sh
    fi

    sudo chroot chroot /bin/bash -c "source /root/config.sh && customize_image"

    chroot_exit_teardown
}

function build_iso() {
    echo "=====> running build_iso ..."

    rm -rf image
    mkdir -p image/casper
    mkdir -p image/boot/grub
    mkdir -p image/EFI/boot

    chroot_enter_setup
    
    sudo chroot chroot apt-get update
    sudo chroot chroot apt-get install -y "${TARGET_KERNEL_PACKAGE}" casper grub-efi-amd64-signed grub-pc-bin

    chroot_exit_teardown

    # Copy Kernel and Initrd
    sudo cp chroot/boot/vmlinuz-* image/casper/vmlinuz
    sudo cp chroot/boot/initrd.img-* image/casper/initrd

    # Create SquashFS
    sudo rm -f image/casper/filesystem.squashfs
    sudo mksquashfs chroot image/casper/filesystem.squashfs \
        -noappend -no-duplicates -no-recovery \
        -wildcards \
        -comp gzip -b 1M \
        -processors $(nproc) \
        -e "var/cache/apt/archives/*" \
        -e "root/*" \
        -e "root/.*" \
        -e "tmp/*" \
        -e "tmp/.*" \
        -e "swapfile"

    printf $(sudo du -sx --block-size=1 chroot | cut -f1) | sudo tee image/casper/filesystem.size

    # GRUB Configuration
    cat << EOF_GRUB > image/boot/grub/grub.cfg
set default="0"
set timeout=10

insmod all_video
insmod gzio
insmod part_gpt
insmod part_msdos
insmod fat
insmod iso9660

menuentry "${GRUB_LIVEBOOT_LABEL}" {
    linux /casper/vmlinuz boot=casper quiet splash ---
    initrd /casper/initrd
}

menuentry "${GRUB_INSTALL_LABEL}" {
    linux /casper/vmlinuz boot=casper only-ubiquity quiet splash ---
    initrd /casper/initrd
}
EOF_GRUB

    # Build UEFI Image (bootx64.efi)
    grub-mkstandalone \
        --format=x86_64-efi \
        --output=image/EFI/boot/bootx64.efi \
        --locales="" \
        --fonts="" \
        "boot/grub/grub.cfg=image/boot/grub/grub.cfg"

    # Create FAT Partition Image for UEFI Boot
    mkdir -p image/boot
    dd if=/dev/zero of=image/boot/efiboot.img bs=1M count=10
    mkfs.vfat image/boot/efiboot.img
    mmd -i image/boot/efiboot.img ::EFI
    mmd -i image/boot/efiboot.img ::EFI/BOOT
    mcopy -i image/boot/efiboot.img image/EFI/boot/bootx64.efi ::EFI/BOOT/BOOTX64.EFI

    # Build Minimal i386-pc Image for Legacy BIOS (Explicitly specify minimal modules to avoid size limit)
    grub-mkstandalone \
        --format=i386-pc \
        --output=image/boot/eltorito.img \
        --install-modules="biosdisk iso9660 part_msdos part_gpt fat normal linux boot configfile tar" \
        --locales="" \
        --fonts="" \
        "boot/grub/grub.cfg=image/boot/grub/grub.cfg"

    ISO_NAME="${TARGET_NAME}-${TARGET_UBUNTU_VERSION}-amd64-${DATE}.iso"

    # Assemble ISO using xorriso
    sudo xorriso -as mkisofs \
        -r -V "LAMPUNTU_LIVE" \
        -J -joliet-long \
        -full-iso9660-filenames \
        -b boot/eltorito.img \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        --eltorito-catalog boot/eltorito.cat \
        -eltorito-alt-boot \
        -e boot/efiboot.img \
        -no-emul-boot \
        -append_partition 2 0xef image/boot/efiboot.img \
        -output "${ISO_NAME}" \
        image

    echo "=========================================="
    echo " ISO CREATED SUCCESSFULLY: ${ISO_NAME}   "
    echo "=========================================="
}

# =============   main  ================

cd $SCRIPT_DIR

load_config
check_config
check_host

if [[ $# == 0 || $# -gt 3 ]]; then help; fi

dash_flag=false
start_index=0
end_index=${#CMD[*]}
for ii in "$@";
do
    if [[ $ii == "-" ]]; then
        dash_flag=true
        continue
    fi
    find_index $ii
    if [[ $dash_flag == false ]]; then
        start_index=$index
    else
        end_index=$(($index+1))
    fi
done
if [[ $dash_flag == false ]]; then
    end_index=$(($start_index + 1))
fi

for ((ii=$start_index; ii<$end_index; ii++)); do
    ${CMD[ii]}
done

echo "$0 - Initial build is done!"
