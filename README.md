# Wireless Display Dongle

Raspberry Pi -pohjainen langaton näyttödongle joka tukee sekä AirPlaytä (1080p) että NDI:tä (4K) automaattisella priorisoinnilla.

## Toimintalogiikka

```
         ┌───────────────────────────────────────────┐
         ▼                                           │
       IDLE                                          │
     (etsi NDI:tä)                                   │
         │                                           │
    NDI löytyy? ──Kyllä──→ NDI 4K ──────katkeaa────→─┘
         │                                           │
        Ei                                           │
         │                                           │
    AirPlay kuuntelee ──NDI löytyy──→ NDI 4K         │
         │                                           │
    asiakas yhdistää                                  │
         │                                           │
    AirPlay aktiivinen ──────────katkeaa────────────→─┘
    (ei etsi NDI:tä)
```

- Idle: etsi NDI ensin (4K priorisoitu)
- Ei NDI:tä → AirPlay kuuntelee, mutta etsii NDI:tä samalla
- AirPlay-asiakas yhdistää → aktiivinen, ei enää etsi NDI:tä
- Yhteys katkeaa → IDLE → etsi taas NDI ensin

## Profiilit

| Alusta | AirPlay (1080p) | NDI (4K) | Hinta |
|---|---|---|---|
| **Pi Zero 2 W** | Kyllä | Ei (HW-rajoitus) | ~48 € |
| **Pi 4** | Kyllä | Kyllä | ~84 € |

## Asennus

### Dongle (yksi skripti, tunnistaa alustan)

```bash
chmod +x setup/install.sh
sudo ./setup/install.sh "Olohuone"
sudo reboot
```

### Mac Mini (4K NDI -lähde)

```bash
brew install --cask ndi-tools
# Käynnistä NDI Screen Capture → valitse näyttö → 4K
```

### MacBook (1080p AirPlay)

```
Ohjauskeskus → Näytön peilaus → "Olohuone"
```

## Käyttö

1. Kytke dongle näytön HDMI-porttiin
2. Kytke USB-virta monitorin USB-porttiin
3. Odota ~30s käynnistystä
4. Dongle toimii automaattisesti:
   - NDI-lähde verkossa → 4K-vastaanotto
   - Ei NDI:tä → AirPlay kuuntelee

DVI-käyttö: passiivinen HDMI→DVI-adapteri donglen ja näytön väliin.

## Laitteisto

Katso [BOM.md](BOM.md) — komponenttilista ja hinnat.
