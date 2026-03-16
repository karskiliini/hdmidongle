#!/bin/bash
set -euo pipefail

# Dongle Switcher — hallitsee NDI- ja AirPlay-vastaanottoa
#
# Toimintalogiikka:
#   IDLE: etsi NDI → ei löydy → etsi AirPlay → ei löydy → IDLE
#   Aktiivisen yhteyden aikana EI etsitä toista lähdettä
#   Yhteyden katketessa → IDLE → etsi taas NDI ensin

DONGLE_NAME="${DONGLE_NAME:-Dongle}"
POLL_INTERVAL=3
AIRPLAY_PID=""
NDI_PID=""
CURRENT_MODE="idle"  # idle | airplay_listen | airplay_active | ndi

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# --- NDI ---

check_ndi_source() {
    if command -v ndi-find > /dev/null 2>&1; then
        ndi-find -w 1000 2>/dev/null | head -1
    else
        timeout 1 bash -c 'cat < /dev/udp/239.1.1.1/5000 > /dev/null 2>&1' && echo "udp-multicast" || true
    fi
}

start_ndi() {
    local source="$1"
    log "NDI-lähde löytyi: $source"
    log "Käynnistetään NDI-vastaanotto (4K)..."

    if gst-inspect-1.0 ndisrc > /dev/null 2>&1; then
        gst-launch-1.0 \
            ndisrc ndi-name="$source" ! \
            ndisrcdemux name=demux \
            demux.video ! queue ! videoconvert ! v4l2h265dec ! kmssink \
            demux.audio ! queue ! audioconvert ! alsasink &
        NDI_PID=$!
    elif command -v ndi-recv > /dev/null 2>&1; then
        ndi-recv -s "$source" &
        NDI_PID=$!
    else
        log "VAROITUS: NDI-plugin ei löydy, yritetään ffplay..."
        ffplay -fflags nobuffer -flags low_delay -framedrop \
            "udp://239.1.1.1:5000?buffer_size=1000000" &
        NDI_PID=$!
    fi

    CURRENT_MODE="ndi"
    log "NDI aktiivinen (PID: $NDI_PID)"
}

stop_ndi() {
    if [ -n "$NDI_PID" ] && kill -0 "$NDI_PID" 2>/dev/null; then
        log "Pysäytetään NDI..."
        kill "$NDI_PID" 2>/dev/null || true
        wait "$NDI_PID" 2>/dev/null || true
    fi
    NDI_PID=""
}

# --- AirPlay ---

start_airplay_listen() {
    log "Käynnistetään AirPlay-kuuntelu ($DONGLE_NAME)..."
    uxplay &
    AIRPLAY_PID=$!
    CURRENT_MODE="airplay_listen"
    log "AirPlay kuuntelee (PID: $AIRPLAY_PID)"
}

stop_airplay() {
    if [ -n "$AIRPLAY_PID" ] && kill -0 "$AIRPLAY_PID" 2>/dev/null; then
        log "Pysäytetään AirPlay..."
        kill "$AIRPLAY_PID" 2>/dev/null || true
        wait "$AIRPLAY_PID" 2>/dev/null || true
    fi
    AIRPLAY_PID=""
}

airplay_has_client() {
    # UxPlay luo lapsiprosesseja kun striimaus on aktiivinen
    if [ -n "$AIRPLAY_PID" ] && kill -0 "$AIRPLAY_PID" 2>/dev/null; then
        local children
        children=$(pgrep -P "$AIRPLAY_PID" 2>/dev/null | wc -l)
        [ "$children" -gt 0 ]
    else
        return 1
    fi
}

airplay_is_alive() {
    [ -n "$AIRPLAY_PID" ] && kill -0 "$AIRPLAY_PID" 2>/dev/null
}

# --- Cleanup ---

cleanup() {
    log "Sammutetaan..."
    stop_ndi
    stop_airplay
    exit 0
}

trap cleanup SIGTERM SIGINT

# === Pääsilmukka ===

log "=== Dongle Switcher ==="
log "Nimi: $DONGLE_NAME"
log "Kierto: IDLE → etsi NDI → etsi AirPlay → IDLE"
log ""

while true; do
    case "$CURRENT_MODE" in

        idle)
            # 1. Etsi NDI-lähdettä
            NDI_SOURCE=$(check_ndi_source)
            if [ -n "$NDI_SOURCE" ]; then
                start_ndi "$NDI_SOURCE"
            else
                # 2. Ei NDI:tä → käynnistä AirPlay kuuntelemaan
                start_airplay_listen
            fi
            ;;

        airplay_listen)
            if ! airplay_is_alive; then
                # UxPlay kuoli → idle
                log "AirPlay-prosessi kuoli, palataan idle-tilaan..."
                AIRPLAY_PID=""
                CURRENT_MODE="idle"
            elif airplay_has_client; then
                # Asiakas yhdisti → aktiivinen tila
                log "AirPlay-asiakas yhdisti, striimaus aktiivinen"
                CURRENT_MODE="airplay_active"
            else
                # Kuuntelee mutta ei asiakasta → tarkista NDI
                NDI_SOURCE=$(check_ndi_source)
                if [ -n "$NDI_SOURCE" ]; then
                    # NDI löytyi → pysäytä AirPlay, vaihda NDI:hin
                    stop_airplay
                    start_ndi "$NDI_SOURCE"
                fi
            fi
            ;;

        airplay_active)
            if ! airplay_is_alive; then
                # Prosessi kuoli → idle
                log "AirPlay-yhteys katkesi, palataan idle-tilaan..."
                AIRPLAY_PID=""
                CURRENT_MODE="idle"
            elif ! airplay_has_client; then
                # Asiakas katkaisi → pysäytä, palaa idle
                log "AirPlay-asiakas katkaisi yhteyden, palataan idle-tilaan..."
                stop_airplay
                CURRENT_MODE="idle"
            fi
            # Aktiivisen striimauksen aikana EI etsitä NDI:tä
            ;;

        ndi)
            if [ -n "$NDI_PID" ] && kill -0 "$NDI_PID" 2>/dev/null; then
                # NDI aktiivinen — ei tehdä mitään
                :
            else
                # NDI katosi → idle
                log "NDI-yhteys katkesi, palataan idle-tilaan..."
                NDI_PID=""
                CURRENT_MODE="idle"
            fi
            ;;
    esac

    sleep "$POLL_INTERVAL"
done
