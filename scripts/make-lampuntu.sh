#!/bin/bash
set -e

echo "=========================================="
echo "      STARTING LAMPUNTU REBRANDING        "
echo "=========================================="

# --------------------------------------------------
# 1. ASSET URLS FROM VERCEL
# --------------------------------------------------
LAMP_LOGO_PNG="https://0sa89df00a9sd8fa9sdfas8df9a8s0df98a.vercel.app/images/lampuntu-logo.png"
LAMP_WALLPAPER_PNG="https://0sa89df00a9sd8fa9sdfas8df9a8s0df98a.vercel.app/images/lampuntu-wallpaper.png"
LAMP_MOO_OGA="https://0sa89df00a9sd8fa9sdfas8df9a8s0df98a.vercel.app/audio/moo.oga"

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
echo -e "Welcome to Lampuntu 24.04 LTS \n \l" > /etc/issue
echo -e "Welcome to Lampuntu 24.04 LTS \n \l" > /etc/issue.net

# Network hostname
echo "lampuntu-pc" > /etc/hostname

# --------------------------------------------------
# 3. DISPLAY COLORED ANSI ART ON TERMINAL LAUNCH
# --------------------------------------------------
mkdir -p /etc/profile.d/

cat << 'EOF' > /etc/profile.d/lampuntu-welcome.sh
#!/bin/bash
if [ -t 0 ] && [ -f /etc/lampuntu-logo.ansi.txt ]; then
    echo ""
    cat /etc/lampuntu-logo.ansi.txt
    echo ""
    echo -e "\e[1;96mWelcome to Lampuntu 24.04 LTS!\e[0m"
    echo ""
fi
EOF

chmod +x /etc/profile.d/lampuntu-welcome.sh

# --------------------------------------------------
# 4. REPLACE SYSTEM LOGOS & ICONS EVERYWHERE
# --------------------------------------------------
ICON_PATHS=(
    "/usr/share/icons/hicolor/scalable/apps"
    "/usr/share/icons/hicolor/512x512/apps"
    "/usr/share/icons/hicolor/256x256/apps"
    "/usr/share/icons/hicolor/128x128/apps"
    "/usr/share/icons/hicolor/48x48/apps"
    "/usr/share/pixmaps"
    "/usr/share/gnome-control-center/pixmaps"
)

for path in "${ICON_PATHS[@]}"; do
    mkdir -p "$path"
    wget -O "$path/ubuntu-logo.png" "$LAMP_LOGO_PNG" || true
    wget -O "$path/distributor-logo.png" "$LAMP_LOGO_PNG" || true
    wget -O "$path/lampuntu-logo.png" "$LAMP_LOGO_PNG" || true
    wget -O "$path/ubuntu-logo-icon.png" "$LAMP_LOGO_PNG" || true
    wget -O "$path/system-logo-ubuntu.png" "$LAMP_LOGO_PNG" || true
done

if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache -f /usr/share/icons/hicolor/ || true
fi

# --------------------------------------------------
# 5. REPLACE PLYMOUTH BOOT SCREEN LOGO
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
# 6. SET CUSTOM DEFAULT WALLPAPER & DOCK
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

[org.gnome.shell]
favorite-apps=['firefox.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop']
EOF

glib-compile-schemas /etc/glib-2.0/schemas/

# --------------------------------------------------
# 7. REPLACE TEXT IN INSTALLER SLIDESHOW & MOTD
# --------------------------------------------------
if [ -d "/usr/share/ubiquity-slideshow-ubuntu" ]; then
    find /usr/share/ubiquity-slideshow-ubuntu/ -type f -exec sed -i 's/Ubuntu/Lampuntu/g' {} + || true
fi

if [ -d "/etc/update-motd.d/" ]; then
    find /etc/update-motd.d/ -type f -exec sed -i 's/Ubuntu/Lampuntu/g' {} + || true
    find /etc/update-motd.d/ -type f -exec sed -i 's/ubuntu/lampuntu/g' {} + || true
fi

# --------------------------------------------------
# 8. COW AUDIO EFFECTS (ERROR MOO & SYSTEM BELL)
# --------------------------------------------------

# Terminal command error moo trigger
cat << 'EOF' >> /etc/bash.bashrc

# Play a moo sound on command error
PROMPT_COMMAND='if [ $? -ne 0 ]; then (speaker-test -t sine -f 120 -l 1 >/dev/null 2>&1 & sleep 0.15 && kill $!) 2>/dev/null; fi'
EOF

# GNOME alert bell sound replacement
mkdir -p /usr/share/sounds/freedesktop/stereo/
wget -O /usr/share/sounds/freedesktop/stereo/bell.oga "$LAMP_MOO_OGA" || true

echo "=========================================="
echo "      LAMPUNTU REBRANDING COMPLETE        "
echo "=========================================="
