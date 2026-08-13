#!/bin/bash

# ==========================================
# 1. UPDATE PRIMARY OS RELEASE LABELS
# ==========================================
cat << 'EOF' > /etc/os-release
NAME="Lampuntu"
ID=lampuntu
PRETTY_NAME="Lampuntu GNU/Linux (Shedding Light on Open Source)"
VERSION_CODENAME=noble
UBUNTU_CODENAME=noble
HOME_URL="https://lampuntu.ethembeldagli.dev"
EOF

# ==========================================
# 2. UPDATE TERMINAL LOGIN GREETINGS
# ==========================================
echo "Welcome to Lampuntu \n \l" > /etc/issue
echo "Welcome to Lampuntu \n \l" > /etc/issue.net

# ==========================================
# 3. SET THE GLOBAL NETWORK HOSTNAME
# ==========================================
echo "lampuntu-desktop" > /etc/hostname

# ==========================================
# 4. SWAP MENTIONS IN UBIQUITY INSTALLER
# ==========================================
if [ -d "/usr/share/ubiquity-slideshow-ubuntu" ]; then
    find /usr/share/ubiquity-slideshow-ubuntu/ -type f -exec sed -i 's/Ubuntu/Lampuntu/g' {} +
fi

# ==========================================
# 5. CREATE WALLPAPER DIRECTORIES
# ==========================================
mkdir -p /usr/share/backgrounds/lampuntu/
mkdir -p /etc/glib-2.0/schemas/

# ==========================================
# 6. DOWNLOAD DEFAULT LAMP WALLPAPER
# ==========================================
wget -O /usr/share/backgrounds/lampuntu/default-lamp.jpg "https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Desk_lamp.jpg/800px-Desk_lamp.jpg" || true

# ==========================================
# 7. FORCE GNOME DESKTOP WALLPAPER OVERRIDE
# ==========================================
cat << 'EOF' > /etc/glib-2.0/schemas/10_lampuntu_theme.gschema.override
[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/lampuntu/default-lamp.jpg'
picture-uri-dark='file:///usr/share/backgrounds/lampuntu/default-lamp.jpg'
picture-options='zoom'
EOF

# Recompile schemas so GNOME bakes it in natively
glib-compile-schemas /etc/glib-2.0/schemas/
