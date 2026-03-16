#!/bin/bash
set -euo pipefail

# USB Gadget -tilan konfigurointi
# Kun Pi kytketään Maciin USB:llä, se näkyy verkkoadapterina (ECM/RNDIS)
# ja ajaa HTTP-palvelimen konfigurointia varten.

if [ "$EUID" -ne 0 ]; then
    echo "Suorita root-oikeuksilla: sudo ./usb-gadget-setup.sh"
    exit 1
fi

echo "=== USB Gadget -tilan asennus ==="

# 1. Ota dwc2-overlay käyttöön
CONFIG="/boot/firmware/config.txt"
if ! grep -q "dtoverlay=dwc2" "$CONFIG"; then
    echo "dtoverlay=dwc2" >> "$CONFIG"
    echo "→ dwc2-overlay lisätty config.txt:iin"
fi

# 2. Lataa moduulit bootissa
if ! grep -q "dwc2" /etc/modules; then
    echo "dwc2" >> /etc/modules
    echo "libcomposite" >> /etc/modules
    echo "→ dwc2 + libcomposite lisätty /etc/modules"
fi

# 3. USB Gadget -konfiguraatioskripti (ajetaan bootissa)
cat > /usr/local/bin/usb-gadget-init.sh << 'GADGET_EOF'
#!/bin/bash
# Konfiguroi Pi USB ECM -verkkolaitteeksi (Mac-yhteensopiva)

GADGET_DIR="/sys/kernel/config/usb_gadget/dongle"

# Jos gadget on jo konfiguroitu, ei tehdä uudelleen
if [ -d "$GADGET_DIR" ]; then
    exit 0
fi

modprobe libcomposite

mkdir -p "$GADGET_DIR"
cd "$GADGET_DIR"

# Laitetiedot
echo 0x1d6b > idVendor   # Linux Foundation
echo 0x0104 > idProduct   # Multifunction Composite Gadget
echo 0x0100 > bcdDevice
echo 0x0200 > bcdUSB

# Kielitiedot
mkdir -p strings/0x409
echo "fedcba9876543210"    > strings/0x409/serialnumber
echo "WirelessDisplayDongle" > strings/0x409/manufacturer
echo "Display Dongle"       > strings/0x409/product

# ECM (Ethernet) -funktio — Mac tunnistaa natiivisti
mkdir -p functions/ecm.usb0
echo "DE:AD:BE:EF:00:01" > functions/ecm.usb0/host_addr
echo "DE:AD:BE:EF:00:02" > functions/ecm.usb0/dev_addr

# Konfiguraatio
mkdir -p configs/c.1/strings/0x409
echo "ECM Network" > configs/c.1/strings/0x409/configuration
echo 250 > configs/c.1/MaxPower

# Linkitä funktio konfiguraatioon
ln -sf functions/ecm.usb0 configs/c.1/

# Aktivoi gadget
UDC=$(ls /sys/class/udc | head -1)
if [ -n "$UDC" ]; then
    echo "$UDC" > UDC
fi

# Konfiguroi IP-osoite USB-verkkoadapterille
sleep 1
ifconfig usb0 10.42.0.1 netmask 255.255.255.0 up 2>/dev/null || \
    ip addr add 10.42.0.1/24 dev usb0 && ip link set usb0 up

echo "USB Gadget aktiivinen: 10.42.0.1"
GADGET_EOF
chmod +x /usr/local/bin/usb-gadget-init.sh

# 4. Systemd-palvelu gadget-alustukselle
cat > /etc/systemd/system/usb-gadget.service << 'EOF'
[Unit]
Description=USB Gadget Configuration Mode
After=sysinit.target
Before=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/usb-gadget-init.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable usb-gadget.service

# 5. Asenna config-palvelin
echo "--- Asennetaan config-palvelin ---"
apt install -y python3 python3-pip
pip3 install flask 2>/dev/null || apt install -y python3-flask

cp "$(dirname "$0")/config-server.py" /usr/local/bin/dongle-config-server.py
chmod +x /usr/local/bin/dongle-config-server.py

# Systemd-palvelu config-palvelimelle
cat > /etc/systemd/system/dongle-config.service << 'EOF'
[Unit]
Description=Dongle Configuration HTTP Server
After=usb-gadget.service
Wants=usb-gadget.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/dongle-config-server.py
Restart=on-failure
RestartSec=3
Environment=FLASK_ENV=production

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable dongle-config.service

echo ""
echo "=== USB Gadget -tila asennettu ==="
echo "Pi näkyy verkkoadapterina (10.42.0.1) kun kytketään Maciin USB:llä"
echo "Config-palvelin: http://10.42.0.1:8080"
