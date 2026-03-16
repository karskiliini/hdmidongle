#!/usr/bin/env python3
"""
Dongle Configuration Server
HTTP API + Web UI joka pyörii Pi:llä.

Käyttötavat:
  1. USB-gadget: Mac-appi → http://10.42.0.1:8080
  2. Wi-Fi AP:  Puhelin → http://192.168.4.1:8080 (captive portal)
  3. Sisäverkko: Selain → http://<donglen-ip>:8080
"""

import json
import subprocess
import os
from pathlib import Path
from flask import Flask, request, jsonify, send_file

app = Flask(__name__)

WEB_UI_PATH = "/usr/local/share/dongle/web-ui.html"

CONFIG_FILE = "/etc/dongle/config.json"
UXPLAY_RC = "/home/pi/.uxplayrc"


def load_config():
    """Lataa nykyinen konfiguraatio."""
    defaults = {
        "dongle_name": "Dongle",
        "wifi_ssid": "",
        "wifi_password": "",
        "wifi_country": "FI",
        "mode": "auto",  # auto | airplay | ndi
        "resolution": "auto",  # auto | 1080p | 720p
    }
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE) as f:
            saved = json.load(f)
            defaults.update(saved)
    return defaults


def save_config(config):
    """Tallenna konfiguraatio."""
    os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
    with open(CONFIG_FILE, "w") as f:
        json.dump(config, f, indent=2)


def apply_wifi(ssid, password, country):
    """Konfiguroi Wi-Fi NetworkManagerilla."""
    if not ssid:
        return False, "SSID puuttuu"

    try:
        # Poista vanha yhteys jos olemassa
        subprocess.run(
            ["nmcli", "connection", "delete", "dongle-wifi"],
            capture_output=True,
        )
        # Luo uusi
        cmd = [
            "nmcli", "connection", "add",
            "type", "wifi",
            "con-name", "dongle-wifi",
            "ssid", ssid,
            "wifi-sec.key-mgmt", "wpa-psk",
            "wifi-sec.psk", password,
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            return False, result.stderr

        # Aseta maakoodi
        subprocess.run(
            ["iw", "reg", "set", country],
            capture_output=True,
        )
        return True, "Wi-Fi konfiguroitu"
    except Exception as e:
        return False, str(e)


def apply_dongle_name(name):
    """Päivitä UxPlay-nimi."""
    if not os.path.exists(UXPLAY_RC):
        return

    lines = Path(UXPLAY_RC).read_text().splitlines()
    new_lines = []
    found = False
    for line in lines:
        if line.startswith("n "):
            new_lines.append(f"n {name}")
            found = True
        else:
            new_lines.append(line)
    if not found:
        new_lines.insert(0, f"n {name}")

    Path(UXPLAY_RC).write_text("\n".join(new_lines) + "\n")


def get_system_info():
    """Kerää järjestelmätiedot."""
    info = {}

    # Pi-malli
    try:
        info["model"] = Path("/proc/device-tree/model").read_text().strip("\x00")
    except Exception:
        info["model"] = "unknown"

    # IP-osoitteet
    try:
        result = subprocess.run(
            ["hostname", "-I"], capture_output=True, text=True
        )
        info["ip_addresses"] = result.stdout.strip().split()
    except Exception:
        info["ip_addresses"] = []

    # Wi-Fi-tila
    try:
        result = subprocess.run(
            ["nmcli", "-t", "-f", "ACTIVE,SSID", "dev", "wifi"],
            capture_output=True, text=True,
        )
        for line in result.stdout.strip().split("\n"):
            if line.startswith("yes:"):
                info["wifi_connected"] = True
                info["wifi_ssid"] = line.split(":", 1)[1]
                break
        else:
            info["wifi_connected"] = False
    except Exception:
        info["wifi_connected"] = False

    # Dongle-palvelun tila
    try:
        result = subprocess.run(
            ["systemctl", "is-active", "dongle"],
            capture_output=True, text=True,
        )
        info["dongle_service"] = result.stdout.strip()
    except Exception:
        info["dongle_service"] = "unknown"

    # Lämpötila
    try:
        temp = Path("/sys/class/thermal/thermal_zone0/temp").read_text().strip()
        info["temperature_c"] = round(int(temp) / 1000, 1)
    except Exception:
        info["temperature_c"] = None

    return info


# === API-reitit ===

@app.route("/", methods=["GET"])
def web_ui():
    """Web UI — toimii selaimella puhelimelta ja tietokoneelta."""
    return send_file(WEB_UI_PATH)


@app.route("/api/status", methods=["GET"])
def status():
    """Palauttaa donglen tilan ja konfiguraation."""
    return jsonify({
        "config": load_config(),
        "system": get_system_info(),
    })


@app.route("/api/config", methods=["POST"])
def update_config():
    """Päivitä konfiguraatio."""
    data = request.get_json()
    if not data:
        return jsonify({"error": "Ei dataa"}), 400

    config = load_config()
    errors = []

    # Päivitä nimi
    if "dongle_name" in data:
        config["dongle_name"] = data["dongle_name"]
        apply_dongle_name(data["dongle_name"])

    # Päivitä Wi-Fi
    if "wifi_ssid" in data:
        config["wifi_ssid"] = data["wifi_ssid"]
        config["wifi_password"] = data.get("wifi_password", "")
        config["wifi_country"] = data.get("wifi_country", "FI")
        ok, msg = apply_wifi(
            config["wifi_ssid"],
            config["wifi_password"],
            config["wifi_country"],
        )
        if not ok:
            errors.append(f"Wi-Fi: {msg}")

    # Päivitä tila
    if "mode" in data:
        config["mode"] = data["mode"]

    if "resolution" in data:
        config["resolution"] = data["resolution"]

    save_config(config)

    return jsonify({
        "success": len(errors) == 0,
        "errors": errors,
        "config": config,
    })


@app.route("/api/wifi/scan", methods=["GET"])
def wifi_scan():
    """Skannaa läheiset Wi-Fi-verkot."""
    try:
        result = subprocess.run(
            ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "yes"],
            capture_output=True, text=True,
        )
        networks = []
        seen = set()
        for line in result.stdout.strip().split("\n"):
            parts = line.split(":")
            if len(parts) >= 3 and parts[0] and parts[0] not in seen:
                seen.add(parts[0])
                networks.append({
                    "ssid": parts[0],
                    "signal": int(parts[1]) if parts[1].isdigit() else 0,
                    "security": parts[2],
                })
        networks.sort(key=lambda x: x["signal"], reverse=True)
        return jsonify({"networks": networks})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/restart", methods=["POST"])
def restart_service():
    """Käynnistä dongle-palvelu uudelleen."""
    subprocess.Popen(["systemctl", "restart", "dongle"])
    return jsonify({"success": True, "message": "Palvelu käynnistetään uudelleen"})


@app.route("/api/reboot", methods=["POST"])
def reboot():
    """Käynnistä Pi uudelleen."""
    subprocess.Popen(["shutdown", "-r", "now"])
    return jsonify({"success": True, "message": "Käynnistetään uudelleen..."})


if __name__ == "__main__":
    # Kuuntele kaikissa osoitteissa (USB, AP, sisäverkko)
    app.run(host="0.0.0.0", port=8080, debug=False)
