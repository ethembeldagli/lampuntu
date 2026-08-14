#!/bin/bash
set -e

echo "=========================================="
echo "      STARTING LAMPUNTU REBRANDING        "
echo "=========================================="

# --------------------------------------------------
# 1. URLs FOR LOGOS AND WALLPAPER
# --------------------------------------------------
LAMP_LOGO_PNG="https://0sa89df00a9sd8fa9sdfas8df9a8s0df98a.vercel.app/images/lampuntu-logo.png"
LAMP_WALLPAPER_PNG="https://0sa89df00a9sd8fa9sdfas8df9a8s0df98a.vercel.app/images/lampuntu-wallpaper.png"

# --------------------------------------------------
# 2. CHANGE OS NAME & IDENTITY FILES
# --------------------------------------------------
cat << 'EOF' > /etc/os-release
NAME="Lampuntu"
ID=lampuntu
PRETTY_NAME="Lampuntu GNU/Linux (24.04 LTS)"
VERSION="24.04 LTS (Noble Numbat)"
VERSION_ID="24.04"
VERSION_CODENAME=noble
UBUNTU_CODENAME=noble
HOME_URL="https://lampuntu.ethembeldagli.dev"
DOCUMENTATION_URL="https://lampuntu.ethembeldagli.dev"
SUPPORT_URL="https://lampuntu.ethembeldagli.dev"
BUG_REPORT_URL="https://lampuntu.ethembeldagli.dev"
PRIVACY_POLICY_URL="https://lampuntu.ethembeldagli.dev"
EOF

cat << 'EOF' > /etc/lsb-release
DISTRIB_ID=Lampuntu
DISTRIB_RELEASE=24.04
DISTRIB_CODENAME=noble
DISTRIB_DESCRIPTION="Lampuntu 24.04 LTS"
EOF

# Terminal TTY login greetings
echo "Welcome to Lampuntu 24.04 LTS \n \l" > /etc/issue
echo "Welcome to Lampuntu 24.04 LTS \n \l" > /etc/issue.net

# Network hostname
echo "lampuntu-pc" > /etc/hostname

# Shell & MOTD Branding
if [ -d "/etc/update-motd.d/" ]; then
    find /etc/update-motd.d/ -type f -exec sed -i 's/Ubuntu/Lampuntu/g' {} + || true
    find /etc/update-motd.d/ -type f -exec sed -i 's/ubuntu/lampuntu/g' {} + || true
fi

if [ -f "/etc/bash.bashrc" ]; then
    sed -i 's/Ubuntu/Lampuntu/g' /etc/bash.bashrc || true
fi

# --------------------------------------------------
# 3. REPLACE SYSTEM LOGOS & ICONS EVERYWHERE
# --------------------------------------------------
ICON_PATHS=(
    "/usr/share/icons/hicolor/scalable/apps"
    "/usr/share/icons/hicolor/512x512/apps"
    "/usr/share/icons/hicolor/256x256/apps"
    "/usr/share/icons/hicolor/128x128/apps"
    "/usr/share/icons/hicolor/48x48/apps"
    "/usr/share/pixmaps"
)

for path in "${ICON_PATHS[@]}"; do
    mkdir -p "$path"
    wget -O "$path/ubuntu-logo.png" "$LAMP_LOGO_PNG" || true
    wget -O "$path/distributor-logo.png" "$LAMP_LOGO_PNG" || true
    wget -O "$path/lampuntu-logo.png" "$LAMP_LOGO_PNG" || true
    wget -O "$path/ubuntu-logo-icon.png" "$LAMP_LOGO_PNG" || true
done

if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache -f /usr/share/icons/hicolor/ || true
fi

# --------------------------------------------------
# 4. REPLACE PLYMOUTH BOOT SCREEN LOGO
# --------------------------------------------------
mkdir -p /usr/share/plymouth/
mkdir -p /usr/share/plymouth/themes/spinner/
mkdir -p /usr/share/plymouth/themes/ubuntu-logo/

wget -O /usr/share/plymouth/ubuntu-logo.png "$LAMP_LOGO_PNG" || true
wget -O /usr/share/plymouth/themes/spinner/watermark.png "$LAMP_LOGO_PNG" || true
wget -O /usr/share/plymouth/themes/spinner/bgrt-fallback.png "$LAMP_LOGO_PNG" || true
wget -O /usr/share/plymouth/themes/ubuntu-logo/ubuntu-logo.png "$LAMP_LOGO_PNG" || true

if command -v update-initramfs &> /dev/null; then
    update-initramfs -u -k all || true
fi

# --------------------------------------------------
# 5. SET CUSTOM DEFAULT WALLPAPER
# --------------------------------------------------
mkdir -p /usr/share/backgrounds/lampuntu/
mkdir -p /etc/glib-2.0/schemas/

wget -O /usr/share/backgrounds/lampuntu/lampuntu-wallpaper.png "$LAMP_WALLPAPER_PNG" || true

cat << 'EOF' > /etc/glib-2.0/schemas/10_lampuntu_wallpaper.gschema.override
[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/lampuntu/lampuntu-wallpaper.png'
picture-uri-dark='file:///usr/share/backgrounds/lampuntu/lampuntu-wallpaper.png'
picture-options='zoom'

[org.gnome.desktop.screensaver]
picture-uri='file:///usr/share/backgrounds/lampuntu/lampuntu-wallpaper.png'
EOF

glib-compile-schemas /etc/glib-2.0/schemas/

# --------------------------------------------------
# 6. REPLACE TEXT IN INSTALLER SLIDESHOW
# --------------------------------------------------
if [ -d "/usr/share/ubiquity-slideshow-ubuntu" ]; then
    find /usr/share/ubiquity-slideshow-ubuntu/ -type f -exec sed -i 's/Ubuntu/Lampuntu/g' {} + || true
fi

echo "=========================================="
echo "      LAMPUNTU REBRANDING COMPLETE        "
echo "=========================================="
