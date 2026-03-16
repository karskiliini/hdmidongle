#!/bin/bash
set -euo pipefail

# Wireless Display Dongle - yhdistetty asennusskripti
# Asentaa sekä AirPlay (1080p) että NDI (4K) -tuen
# Suorita: sudo ./install.sh [donglen-nimi]

if [ "$EUID" -ne 0 ]; then
    echo "Suorita root-oikeuksilla: sudo ./install.sh [nimi]"
    exit 1
fi

DONGLE_NAME="${1:-Dongle}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Wireless Display Dongle - Asennus ==="
echo "Nimi: $DONGLE_NAME"
echo "Tuetut: AirPlay (1080p) + NDI (4K)"
echo ""

# --- Tunnista alusta ---
PI_MODEL=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "unknown")
echo "Alusta: $PI_MODEL"

IS_PI4=false
if echo "$PI_MODEL" | grep -qi "Pi 4"; then
    IS_PI4=true
    echo "→ Pi 4 tunnistettu: NDI 4K -tuki aktivoidaan"
else
    echo "→ Lite-alusta: AirPlay 1080p, NDI rajoitettu"
fi

# 1. Päivitä järjestelmä
echo ""
echo "--- [1/9] Päivitetään järjestelmä ---"
apt update && apt upgrade -y

# 2. Asenna riippuvuudet (AirPlay + NDI)
echo "--- [2/9] Asennetaan riippuvuudet ---"
apt install -y \
    build-essential cmake pkg-config git \
    libssl-dev libplist-dev libavahi-compat-libdnssd-dev \
    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav gstreamer1.0-tools gstreamer1.0-alsa \
    gstreamer1.0-gl \
    avahi-daemon avahi-utils \
    ffmpeg

# 3. Käännä UxPlay (AirPlay-vastaanotin)
echo "--- [3/9] Käännetään UxPlay ---"
cd /home/pi
if [ -d UxPlay ]; then
    cd UxPlay && git pull
else
    git clone https://github.com/FDH2/UxPlay.git
    cd UxPlay
fi
mkdir -p build && cd build
cmake ..
make -j4
make install
cd "$SCRIPT_DIR"

# 4. UxPlay-konfiguraatio
echo "--- [4/9] Konfiguroidaan UxPlay ---"
mkdir -p /home/pi/.config

if $IS_PI4; then
    # Pi 4: käytä H.265-dekooderia, suurempi resoluutio
    cat > /home/pi/.uxplayrc << EOF
n ${DONGLE_NAME}
vd v4l2h264dec
vs kmssink
as alsasink
fps 30
bt709
EOF
else
    # Pi Zero 2W: kevyemmät asetukset
    cat > /home/pi/.uxplayrc << EOF
n ${DONGLE_NAME}
vd v4l2h264dec
vs kmssink
as alsasink
fps 30
bt709
EOF
fi
chown pi:pi /home/pi/.uxplayrc

# 5. NDI SDK (vain Pi 4)
echo "--- [5/9] NDI-tuki ---"
if $IS_PI4; then
    NDI_DIR="/opt/ndi"
    if [ ! -d "$NDI_DIR" ] || [ -z "$(ls -A "$NDI_DIR" 2>/dev/null)" ]; then
        mkdir -p "$NDI_DIR"
        echo ""
        echo "╔═══════════════════════════════════════════════════════════╗"
        echo "║  NDI SDK (valinnainen, 4K-tuki):                         ║"
        echo "║  1. Mene: https://ndi.video/download-ndi-sdk/            ║"
        echo "║  2. Lataa 'NDI SDK for Linux (ARM)'                      ║"
        echo "║  3. Pura /opt/ndi/ -hakemistoon                          ║"
        echo "║                                                           ║"
        echo "║  Ilman NDI SDK:ta dongle käyttää ffmpeg UDP -vastaanottoa ║"
        echo "║  Mac Minissä: ffmpeg + UDP multicast (ks. README.md)      ║"
        echo "╚═══════════════════════════════════════════════════════════╝"
        echo ""
    else
        echo "NDI SDK löytyi: $NDI_DIR"
    fi
else
    echo "Pi Zero 2W: NDI SDK ohitetaan (AirPlay riittää)"
fi

# 6. Boot-konfiguraatio
echo "--- [6/9] Konfiguroidaan boot ---"
CONFIG="/boot/firmware/config.txt"

if ! grep -q "# Wireless Display Dongle" "$CONFIG"; then
    if $IS_PI4; then
        cat >> "$CONFIG" << 'EOF'

# --- Wireless Display Dongle (Pi 4, 4K) ---
gpu_mem=256
dtoverlay=vc4-kms-v3d
hdmi_force_hotplug=1
hdmi_enable_4kp60=1
hdmi_group=2
hdmi_mode=97
dtoverlay=disable-bt
EOF
    else
        cat >> "$CONFIG" << 'EOF'

# --- Wireless Display Dongle (Pi Zero 2W, 1080p) ---
gpu_mem=128
dtoverlay=vc4-kms-v3d
hdmi_force_hotplug=1
arm_freq=1200
core_freq=500
over_voltage=4
dtoverlay=disable-bt
EOF
    fi
fi

CMDLINE="/boot/firmware/cmdline.txt"
if ! grep -q "consoleblank=0" "$CMDLINE"; then
    if $IS_PI4; then
        sed -i 's/$/ consoleblank=0 vt.global_cursor_default=0 cma=128M/' "$CMDLINE"
    else
        sed -i 's/$/ consoleblank=0 vt.global_cursor_default=0 cma=64M/' "$CMDLINE"
    fi
fi

# 7. Swap
echo "--- [7/9] Konfiguroidaan swap ---"
dphys-swapfile swapoff || true
if $IS_PI4; then
    sed -i 's/^CONF_SWAPSIZE=.*/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile
else
    sed -i 's/^CONF_SWAPSIZE=.*/CONF_SWAPSIZE=512/' /etc/dphys-swapfile
fi
dphys-swapfile setup
dphys-swapfile swapon

# 8. Optimoinnit
echo "--- [8/9] Optimoidaan ---"
systemctl disable bluetooth 2>/dev/null || true
systemctl disable hciuart 2>/dev/null || true
systemctl disable triggerhappy 2>/dev/null || true

cat > /etc/NetworkManager/dispatcher.d/99-wifi-powersave-off << 'WIFIEOF'
#!/bin/sh
iwconfig wlan0 power off 2>/dev/null || true
WIFIEOF
chmod +x /etc/NetworkManager/dispatcher.d/99-wifi-powersave-off

# 9. Asenna palvelut
echo "--- [9/12] Asennetaan dongle-palvelu ---"

cp "$SCRIPT_DIR/dongle-switcher.sh" /usr/local/bin/dongle-switcher
chmod +x /usr/local/bin/dongle-switcher

cat > /etc/systemd/system/dongle.service << EOF
[Unit]
Description=Wireless Display Dongle - ${DONGLE_NAME}
After=network-online.target avahi-daemon.service dongle-wifi-manager.service
Wants=network-online.target avahi-daemon.service

[Service]
Type=simple
User=pi
Environment=DONGLE_NAME=${DONGLE_NAME}
Environment=HOME=/home/pi
Environment=XDG_RUNTIME_DIR=/run/user/1000
ExecStartPre=/bin/sh -c 'echo 0 > /sys/class/graphics/fbcon/cursor_blink; setterm --blank=0 --cursor off > /dev/tty1'
ExecStart=/usr/local/bin/dongle-switcher
Restart=on-failure
RestartSec=5
SupplementaryGroups=video render audio

[Install]
WantedBy=multi-user.target
EOF

# 10. USB Gadget -tila (Mac-konfigurointi)
echo "--- [10/12] USB Gadget -tila ---"
bash "$SCRIPT_DIR/usb-gadget-setup.sh"

# 11. Wi-Fi AP -tila (puhelin-konfigurointi)
echo "--- [11/12] Wi-Fi AP -tila ---"
bash "$SCRIPT_DIR/wifi-ap-setup.sh"

# 12. HDMI setup-näyttö + web UI
echo "--- [12/12] Setup-näyttö ja web UI ---"

mkdir -p /usr/local/share/dongle
cp "$SCRIPT_DIR/web-ui.html" /usr/local/share/dongle/web-ui.html
cp "$SCRIPT_DIR/setup-screen.py" /usr/local/bin/dongle-setup-screen.py
chmod +x /usr/local/bin/dongle-setup-screen.py

# HDMI setup-näytön palvelu
cat > /etc/systemd/system/dongle-setup-screen.service << 'EOF'
[Unit]
Description=Dongle HDMI Setup Screen
After=dongle-wifi-manager.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/dongle-setup-screen.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable avahi-daemon
systemctl enable dongle.service
systemctl enable dongle-setup-screen.service

# Poista vanhat palvelut
systemctl disable uxplay.service 2>/dev/null || true
systemctl disable ndi-receiver.service 2>/dev/null || true

echo ""
echo "=== Asennus valmis! ==="
echo ""
echo "Donglen nimi: $DONGLE_NAME"
echo "Alusta:      $PI_MODEL"
echo ""
echo "Konfigurointi (3 tapaa):"
echo "  1. HDMI: Kytke näyttöön → ohjeet näkyvät ruudulla"
echo "  2. Puhelin: Yhdistä 'Dongle-XXXX' Wi-Fi → selain → konfiguroi"
echo "  3. Mac USB: Kytke USB → DongleConfig-appi aukeaa"
echo ""
echo "Kun konfiguroitu:"
echo "  - AirPlay (1080p) — MacBook → Ohjauskeskus → Näytön peilaus"
echo "  - NDI (4K) — Mac Mini → NDI Screen Capture"
echo "  - Asetukset: http://<donglen-ip>:8080"
echo ""
echo "Käynnistä uudelleen: sudo reboot"
