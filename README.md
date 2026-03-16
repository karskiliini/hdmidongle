# Wireless Display Dongle

Raspberry Pi -pohjaisia langattomia näyttödongleja ja lähettimiä.

## Rakenne

```
hdmidongle/
├── receiver/           ← Vastaanotin-dongle (Pi Zero 2W / Pi 4)
├── c64-transmitter/    ← C64 langaton lähetin (Pico + Pi Zero)
├── app/                ← Mac-konfigurointisovellus (SwiftUI)
├── case/               ← 3D-kotelomallit (OpenSCAD)
└── docs/               ← Dokumentaatio ja pitch
```

## Järjestelmä

```
C64 ──bus──→ Pico + Pi Zero ──Wi-Fi──┐
MacBook ──AirPlay 1080p──Wi-Fi──┐    │
Mac Mini ──NDI 4K──Wi-Fi──┐     ▼    ▼
                           ▼    Pi Zero 2W ──HDMI──→ 1080p
                          Pi 4 ──HDMI 0──→ 4K Display 1
                               ──HDMI 1──→ 4K Display 2
```

Vastaanotin-dongle tukee kolmea protokollaa automaattisella priorisoinnilla:
NDI (4K) > C64 raw UDP > AirPlay (1080p)

## Komponentit

| Moduuli | Alusta | Hinta |
|---|---|---|
| Vastaanotin Lite (1080p) | Pi Zero 2 W | [~48 €](BOM.md) |
| Vastaanotin 4K Dual | Pi 4 | [~92 €](BOM.md) |
| C64-lähetin | Pico + Pi Zero 2W | [~35 €](c64-transmitter/BOM.md) |

## Asennus

### Vastaanotin-dongle

```bash
cd receiver
chmod +x install.sh
sudo ./install.sh "Olohuone"
sudo reboot
```

### Konfigurointi (3 tapaa)

1. **HDMI** — ohjeet näytöllä kun dongle on alustamaton
2. **Puhelin** — yhdistä Dongle-XXXX Wi-Fi → selain → konfiguroi
3. **Mac USB** — DongleConfig-appi aukeaa automaattisesti

### Mac Mini (4K NDI -lähde)

```bash
brew install --cask ndi-tools
# NDI Screen Capture → valitse näyttö → 4K
```

### MacBook (1080p AirPlay)

```
Ohjauskeskus → Näytön peilaus → "Olohuone"
```

## Laitteisto

Katso [BOM.md](BOM.md) — kokonaiskomponenttilista ja hinnat.
