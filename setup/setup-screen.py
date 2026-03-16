#!/usr/bin/env python3
"""
Näyttää HDMI:n kautta alustusohjeet kun dongle on konfiguroimaton.
Käyttää framebufferia suoraan (ei X11/Wayland).
"""

import os
import sys
import json
import subprocess
import time

CONFIG_FILE = "/etc/dongle/config.json"
FONT_SIZE = 32  # pikseliä


def is_configured():
    """Tarkista onko dongle konfiguroitu."""
    if not os.path.exists(CONFIG_FILE):
        return False
    try:
        with open(CONFIG_FILE) as f:
            config = json.load(f)
        return bool(config.get("wifi_ssid"))
    except Exception:
        return False


def get_ap_name():
    """Hae AP-verkon nimi."""
    try:
        mac = open("/sys/class/net/wlan0/address").read().strip()
        suffix = mac[-5:].replace(":", "")
        return f"Dongle-{suffix}"
    except Exception:
        return "Dongle-XXXX"


def show_setup_screen():
    """Näytä setup-ohjeet HDMI:n kautta framebufferiin."""
    ap_name = get_ap_name()

    # Käytä fbcon:ia tekstin näyttämiseen
    # Tyhjennä näyttö
    try:
        with open("/dev/tty1", "w") as tty:
            tty.write("\033[2J")  # Clear screen
            tty.write("\033[H")   # Cursor home
            tty.write("\033[?25l")  # Hide cursor
    except Exception:
        pass

    lines = [
        "",
        "  ╔═══════════════════════════════════════════════╗",
        "  ║                                               ║",
        "  ║         WIRELESS DISPLAY DONGLE               ║",
        "  ║              Alustamaton                       ║",
        "  ║                                               ║",
        "  ╠═══════════════════════════════════════════════╣",
        "  ║                                               ║",
        f"  ║  1. Yhdista Wi-Fi-verkkoon:                   ║",
        f"  ║     Verkko: {ap_name:<33}║",
        "  ║     Salasana: (ei salasanaa)                  ║",
        "  ║                                               ║",
        "  ║  2. Avaa selain:                              ║",
        "  ║     http://192.168.4.1:8080                   ║",
        "  ║                                               ║",
        "  ║  3. Konfiguroi Wi-Fi ja donglen nimi           ║",
        "  ║                                               ║",
        "  ║  TAI: Kytke USB-kaapelilla Maciin              ║",
        "  ║       DongleConfig-appi aukeaa automaattisesti ║",
        "  ║                                               ║",
        "  ╚═══════════════════════════════════════════════╝",
        "",
        "  Odottaa konfigurointia...",
    ]

    # Kirjoita framebufferiin /dev/tty1:n kautta
    text = "\n".join(lines) + "\n"

    try:
        # Yritä kirjoittaa suoraan tty1:een
        with open("/dev/tty1", "w") as tty:
            tty.write("\033[2J\033[H\033[?25l")  # clear, home, hide cursor
            tty.write(text)
            tty.flush()
    except PermissionError:
        # Fallback: käytä echo:a
        subprocess.run(
            ["bash", "-c", f'echo -e "\\033[2J\\033[H\\033[?25l" > /dev/tty1'],
            check=False,
        )
        for line in lines:
            subprocess.run(
                ["bash", "-c", f'echo "{line}" > /dev/tty1'],
                check=False,
            )

    # Isompi fontti (jos psf-fontit käytettävissä)
    subprocess.run(
        ["setfont", "/usr/share/consolefonts/Lat15-TerminusBold32x16.psf.gz"],
        capture_output=True,
    )


def show_connected_screen():
    """Näytä yhdistetty-tila."""
    try:
        with open(CONFIG_FILE) as f:
            config = json.load(f)
        name = config.get("dongle_name", "Dongle")
    except Exception:
        name = "Dongle"

    # Hae IP
    try:
        result = subprocess.run(
            ["hostname", "-I"], capture_output=True, text=True,
        )
        ip = result.stdout.strip().split()[0] if result.stdout.strip() else "?"
    except Exception:
        ip = "?"

    lines = [
        "",
        f"  {name}",
        f"  Valmis vastaanottamaan",
        "",
        f"  IP: {ip}",
        f"  Asetukset: http://{ip}:8080",
        "",
        "  Odotetaan AirPlay/NDI-yhteytta...",
    ]

    try:
        with open("/dev/tty1", "w") as tty:
            tty.write("\033[2J\033[H\033[?25l")
            tty.write("\n".join(lines) + "\n")
    except Exception:
        pass


def main():
    """Pääsilmukka: näytä oikea ruutu tilan mukaan."""
    shown_state = None

    while True:
        configured = is_configured()

        if configured and shown_state != "connected":
            show_connected_screen()
            shown_state = "connected"
        elif not configured and shown_state != "setup":
            show_setup_screen()
            shown_state = "setup"

        # Tarkista 5s välein
        time.sleep(5)


if __name__ == "__main__":
    main()
