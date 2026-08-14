#!/bin/bash
set -e

echo "=========================================="
echo "      STARTING LAMPUNTU REBRANDING        "
echo "=========================================="

# --------------------------------------------------
# 1. CHANGE OS NAME & DOMAINS IN IDENTITY FILES
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

# --------------------------------------------------
# 2. REPLACE SYSTEM LOGOS & ICONS FROM VERCEL
# --------------------------------------------------
LAMP_ICON_URL="https://0sa89df00a9sd8fa9sdfas8df9a8s0df98a.vercel.app/images/lampuntu-logo.png"

mkdir -p /usr/share/icons/hicolor/scalable/apps/
mkdir -p /usr/share/icons/hicolor/512x512/apps/
mkdir -p /usr/share/icons/hicolor/256x256/apps/
mkdir -p /usr/share/icons/hicolor/48x48/apps/

# Download logo into system icon directories
wget -O /usr/share/icons/hicolor/512x512/apps/ubuntu-logo.png "$LAMP_ICON_URL" || true
wget -O /usr/share/icons/hicolor/512x512/apps/distributor-logo.png "$LAMP_ICON_URL" || true
wget -O /usr/share/icons/hicolor/512x512/apps/lampuntu-logo.png "$LAMP_ICON_URL" || true

# Update GTK icon cache
if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache -f /usr/share/icons/hicolor/ || true
fi

# --------------------------------------------------
# 3. SET CUSTOM WALLPAPER FROM VERCEL
# --------------------------------------------------
mkdir -p /usr/share/backgrounds/lampuntu/
mkdir -p /etc/glib-2.0/schemas/

LAMP_WALLPAPER_URL="https://0sa89df00a9sd8fa9sdfas8df9a8s0df98a.vercel.app/images/lampuntu-wallpaper.png"

# Download custom PNG wallpaper
wget -O /usr/share/backgrounds/lampuntu/lampuntu-wallpaper.png "$LAMP_WALLPAPER_URL" || true

# Override GNOME Desktop background schema for 24.04 LTS (Light and Dark mode)
cat << 'EOF' > /etc/glib-2.0/schemas/10_lampuntu_wallpaper.gschema.override
[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/lampuntu/lampuntu-wallpaper.png'
picture-uri-dark='file:///usr/share/backgrounds/lampuntu/lampuntu-wallpaper.png'
picture-options='zoom'

[org.gnome.desktop.screensaver]
picture-uri='file:///usr/share/backgrounds/lampuntu/lampuntu-wallpaper.png'
EOF

# Compile schema overrides into GNOME database
glib-compile-schemas /etc/glib-2.0/schemas/

# --------------------------------------------------
# 4. REPLACE TEXT IN INSTALLER SLIDESHOW
# --------------------------------------------------
if [ -d "/usr/share/ubiquity-slideshow-ubuntu" ]; then
    find /usr/share/ubiquity-slideshow-ubuntu/ -type f -exec sed -i 's/Ubuntu/Lampuntu/g' {} +
fi

echo "=========================================="
echo "      LAMPUNTU REBRANDING COMPLETE        "
echo "=========================================="

# --------------------------------------------------
# 5. ADDITIONAL TEXT & SYSTEM BRANDING SWAPS
# --------------------------------------------------

# Update MOTD (Message of the Day displayed when opening terminal sessions)
if [ -d "/etc/update-motd.d/" ]; then
    find /etc/update-motd.d/ -type f -exec sed -i 's/Ubuntu/Lampuntu/g' {} +
    find /etc/update-motd.d/ -type f -exec sed -i 's/ubuntu/lampuntu/g' {} +
fi

# Update default shell prompt / profile hints if present
if [ -f "/etc/bash.bashrc" ]; then
    sed -i 's/Ubuntu/Lampuntu/g' /etc/bash.bashrc
fi

# Override GNOME Shell name if stored in desktop entry files
if [ -d "/usr/share/applications" ]; then
    find /usr/share/applications/ -name "*ubuntu*" -exec rename 's/ubuntu/lampuntu/' {} + || true
fi
