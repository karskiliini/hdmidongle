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
import re
from pathlib import Path
from flask import Flask, request, jsonify, send_file
from dongle_security import valid_token, same_origin

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 16384


@app.before_request
def authenticate():
    token = os.environ.get("DONGLE_ADMIN_TOKEN")
    if not token or len(token) < 32:
        return jsonify({"error": "DONGLE_ADMIN_TOKEN must be configured (32+ characters)"}), 503
    if not valid_token(request.headers, token):
        return jsonify({"error": "Authentication required"}), 401, {"WWW-Authenticate": 'Basic realm="Dongle", charset="UTF-8"'}
    if not same_origin(request.headers, request.scheme):
        return jsonify({"error": "Origin rejected"}), 403


def public_config(config):
    # The client may replace a Wi-Fi password, but must never read it back.
    return {**config, "wifi_password": ""}


def valid_config_input(data):
    if not isinstance(data, dict) or not data:
        return False
    for key, allowed in {"mode": {"auto", "airplay", "ndi", "retro"}, "resolution": {"auto", "1080p", "720p"}}.items():
        if key in data and (not isinstance(data[key], str) or data[key] not in allowed):
            return False
    for key, limit in [("dongle_name", 64), ("wifi_ssid", 32), ("wifi_password", 64)]:
        if key in data and (not isinstance(data[key], str) or len(data[key].encode("utf-8")) > limit or any(ord(c) < 32 for c in data[key])):
            return False
    if "wifi_country" in data and (not isinstance(data["wifi_country"], str) or not re.fullmatch("[A-Z]{2}", data["wifi_country"])):
        return False
    return True

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
        "mode": "auto",  # auto | airplay | ndi | retro
        "resolution": "auto",  # auto | 1080p | 720p
        "render_mode": "pixel",  # pixel | smooth | crt
        "crt_scanlines": True,
        "crt_bloom": 0.3,  # 0.0–1.0
        "crt_curvature": 0.0,  # 0.0–1.0 (0 = flat)
    }
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE) as f:
            saved = json.load(f)
            defaults.update(saved)
    return defaults


def save_config(config):
    """Tallenna konfiguraatio."""
    os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
    fd = os.open(CONFIG_FILE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(fd, 0o600)
    with os.fdopen(fd, "w") as f:
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
        "config": public_config(load_config()),
        "system": get_system_info(),
    })


@app.route("/api/config", methods=["POST"])
def update_config():
    """Päivitä konfiguraatio."""
    data = request.get_json()
    if not valid_config_input(data):
        return jsonify({"error": "Virheelliset asetukset"}), 400

    config = load_config()
    errors = []

    # Päivitä nimi
    if "dongle_name" in data:
        config["dongle_name"] = data["dongle_name"]
        apply_dongle_name(data["dongle_name"])

    # Päivitä Wi-Fi
    if "wifi_ssid" in data:
        config["wifi_ssid"] = data["wifi_ssid"]
        # An empty password field retains the stored secret for the same SSID.
        old = load_config()
        config["wifi_password"] = data.get("wifi_password") or (old["wifi_password"] if old["wifi_ssid"] == data["wifi_ssid"] else "")
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
        "config": public_config(config),
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
    app.run(host=os.environ.get("DONGLE_BIND_HOST", "127.0.0.1"), port=8080, debug=False)
