#!/bin/bash
set -euo pipefail

# Wi-Fi AP -tila konfiguroimattomalle donglelle
#
# Logiikka:
#   1. Bootissa tarkista onko Wi-Fi konfiguroitu
#   2. Ei → avaa salasanaton hotspot "Dongle-XXXX" + captive portal
#   3. Kyllä → yhdistä normaalisti, pidä config-palvelin päällä sisäverkossa
#
# Puhelimella: yhdistä "Dongle-XXXX" → selain avautuu → konfiguroi

if [ "$EUID" -ne 0 ]; then
    echo "Suorita root-oikeuksilla"
    exit 1
fi

echo "=== Wi-Fi AP -tilan asennus ==="

# 1. Asenna riippuvuudet
apt install -y dnsmasq hostapd python3-flask

# 2. AP-hallintaskripti
cat > /usr/local/bin/dongle-wifi-manager.sh << 'WIFIMGR_EOF'
#!/bin/bash
# Hallitsee Wi-Fi-tilaa: AP (konfiguroimaton) tai client (konfiguroitu)

CONFIG_FILE="/etc/dongle/config.json"
AP_SSID="Dongle-$(cat /sys/class/net/wlan0/address 2>/dev/null | tail -c 6 | tr -d ':')"
AP_IP="192.168.4.1"

log() {
    echo "[$(date '+%H:%M:%S')] wifi-manager: $1"
}

start_ap_mode() {
    log "Käynnistetään AP-tila: $AP_SSID (ei salasanaa)"

    # Pysäytä normaali Wi-Fi
    nmcli device disconnect wlan0 2>/dev/null || true
    nmcli radio wifi off 2>/dev/null || true
    sleep 1
    nmcli radio wifi on

    # Konfiguroi hostapd
    cat > /tmp/hostapd.conf << HAPD
interface=wlan0
driver=nl80211
ssid=${AP_SSID}
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
wpa=0
HAPD

    # Konfiguroi dnsmasq (DHCP + DNS captive portal)
    cat > /tmp/dnsmasq-ap.conf << DNS
interface=wlan0
dhcp-range=192.168.4.10,192.168.4.50,255.255.255.0,24h
address=/#/${AP_IP}
DNS

    # Aseta IP
    ip addr flush dev wlan0
    ip addr add ${AP_IP}/24 dev wlan0
    ip link set wlan0 up

    # Käynnistä palvelut
    hostapd -B /tmp/hostapd.conf
    dnsmasq -C /tmp/dnsmasq-ap.conf --no-daemon &

    log "AP aktiivinen: $AP_SSID @ $AP_IP"
    log "Config-sivu: http://$AP_IP:8080"
}

start_client_mode() {
    log "Käynnistetään client-tila (normaali Wi-Fi)"

    # Tapa AP-prosessit
    killall hostapd 2>/dev/null || true
    killall dnsmasq 2>/dev/null || true

    # Palauta normaali Wi-Fi
    ip addr flush dev wlan0 2>/dev/null || true
    nmcli radio wifi on
    sleep 2

    # Yhdistä tallennettuun verkkoon
    nmcli connection up dongle-wifi 2>/dev/null || {
        log "VAROITUS: Wi-Fi-yhteys epäonnistui, palataan AP-tilaan"
        start_ap_mode
        return
    }

    log "Wi-Fi yhdistetty"
}

is_wifi_configured() {
    # Tarkista onko Wi-Fi-verkko konfiguroitu
    if [ -f "$CONFIG_FILE" ]; then
        SSID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('wifi_ssid',''))" 2>/dev/null)
        [ -n "$SSID" ]
    else
        return 1
    fi
}

# === Päälogiikka ===

if is_wifi_configured; then
    start_client_mode
else
    start_ap_mode
fi

# Pidä prosessi elossa (systemd odottaa)
wait
WIFIMGR_EOF
chmod +x /usr/local/bin/dongle-wifi-manager.sh

# 3. Systemd-palvelu
cat > /etc/systemd/system/dongle-wifi-manager.service << 'EOF'
[Unit]
Description=Dongle Wi-Fi Manager (AP / Client)
Before=dongle.service dongle-config.service
After=network-pre.target
Wants=network-pre.target

[Service]
Type=simple
ExecStart=/usr/local/bin/dongle-wifi-manager.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable dongle-wifi-manager.service

echo ""
echo "=== Wi-Fi AP -tila asennettu ==="
echo "Konfiguroimaton dongle avaa hotspotin: Dongle-XXXX"
echo "Yhdistä puhelimella → selain aukeaa → konfiguroi Wi-Fi"
echo "Konfiguroitu dongle yhdistää normaalisti ja näkyy sisäverkossa"
