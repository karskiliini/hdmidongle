# Wireless Display Dongle

Avoimen lähdekoodin langaton näyttöjärjestelmä Raspberry Pi -alustalla. Tukee moderneja Maceja (AirPlay, NDI) ja retrotietokoneita (C64, Amiga, CPC) samalla vastaanottimella.

## Järjestelmä

```
┌─── Modernit lähteet ────────────────────┐    ┌─── Vastaanottimet ──────────────────┐
│                                         │    │                                     │
│  MacBook ──AirPlay 1080p──┐             │    │  Pi Zero 2W ──HDMI──→ 1080p näyttö  │
│  Mac Mini ──NDI 4K────────┤             │    │  Pi 4 ──HDMI 0──→ 4K näyttö 1       │
│                            ├──Wi-Fi──→──┤    │       ──HDMI 1──→ 4K näyttö 2       │
│                            │            │    │                                     │
├─── Retro-lähettimet ──────┘             │    │  Sama vastaanotin tukee kaikkia      │
│                                         │    │  protokollia automaattisesti.        │
│  C64 ──expansion port──→ Pico+PiZero ──┘    │                                     │
│  Amiga ──DB23 RGB──→ Pico+PiZero ──────┘    │  Renderöinti: pikselitarkka /        │
│  CPC ──6-pin DIN──→ Pico+PiZero ──────┘    │  bilinear / CRT-simulaatio          │
│                                         │    │                                     │
└─────────────────────────────────────────┘    └─────────────────────────────────────┘
```

## Protokollat

| Protokolla | Lähde | Resoluutio | Latenssi |
|---|---|---|---|
| AirPlay | MacBook (natiivi) | 1080p | ~100–200 ms |
| NDI | Mac Mini (NDI Tools) | 4K | ~16–50 ms |
| RETRO | C64, Amiga, CPC (custom) | 160–640 × 200–512 | ~9 ms avg |

Vastaanotin priorisoi automaattisesti: NDI > RETRO > AirPlay.

## Projektit

### Vastaanotin-dongle (`receiver/`)

HDMI-dongle joka vastaanottaa kaikkia protokollia. Kaksi profiilia:

| Profiili | Alusta | Tuetut protokollat | Hinta |
|---|---|---|---|
| Lite | Pi Zero 2 W | AirPlay + RETRO | [~48 €](BOM.md) |
| 4K Dual | Pi 4 (2× HDMI) | AirPlay + NDI + RETRO | [~92 €](BOM.md) |

Ominaisuudet:
- Automaattinen protokollan tunnistus ja vaihto
- Konfigurointi: HDMI-ohjeet / puhelin (Wi-Fi AP) / Mac USB -appi
- Renderöintimoodit: pikselitarkka, bilinear, CRT-simulaatio (scanlines + bloom + kaarevuus)
- Web UI asetuksille (`http://<ip>:8080`)

### C64-lähetin (`c64-transmitter/`)

Bus snoop Commodore 64:n laajennusportista. Passiivinen — ei vaikuta C64:n toimintaan.

| | |
|---|---|
| Kaappaus | PIO lukee väylää joka PHI2-syklillä, shadow frame buffer |
| Yhteys | Pico → SPI → Pi Zero → Wi-Fi UDP |
| Protokolla | RETRO v1, rivi kerrallaan |
| Hinta | [~35 €](c64-transmitter/BOM.md) |
| Pass-through | Automaattinen (ei koske videosignaaliin) |

### Amiga-lähetin (`amiga-transmitter/`)

RGB-kaappaus Amiga 500/1200:n DB23-portista. Tukee kaikkia resoluutioita automaattisesti.

| | |
|---|---|
| Kaappaus | PIO lukee digitaalista RGBI:tä Amigan pikselikellolla (C1) |
| Pipeline | Tuplapuskuri: kaappaa rivi N, lähetä rivi N-1 (DMA) |
| Tuetut moodit | Lores, hires, interlaced, super hires (autodetect) |
| Hinta | [~31 €](amiga-transmitter/BOM.md) |
| Yhteensopivuus | A500, A600, A1200, A2000, A3000, A4000 (sama DB23) |

### CPC-lähetin (`cpc-transmitter/`)

RGB-kaappaus Amstrad CPC 464/664/6128:n 6-pin DIN -portista.

| | |
|---|---|
| Kaappaus | LM339-komparaattorit digitoivat 3-tasoisen RGB:n, Pico PIO |
| Tuetut moodit | Mode 0 (160×200), Mode 1 (320×200), Mode 2 (640×200) |
| Hinta | [~29.50 €](cpc-transmitter/BOM.md) |

### Langaton kuvankaappari (`wireless-capture/`)

Pass-through-versio Amiga- ja CPC-lähettimistä. Signaali jatkaa alkuperäiselle näytölle (CRT) ja samalla kaapparoidaan langattomasti.

| | |
|---|---|
| Tekniikka | THS7316 video buffer jakaa RGB:n kahtia |
| Käyttö | Pelaa CRT:llä + striimaa/tallenna modernille näytölle |
| Hinta | [~33.50–38 €](wireless-capture/README.md) |

### RETRO-protokolla (`protocol/`)

Geneerinen UDP-protokolla retrotietokoneiden kuvan langattomaan siirtoon. [Spesifikaatio](protocol/RETRO_PROTOCOL.md).

- **HELLO**: metadata (kone, resoluutio, paletti, fps)
- **ROW**: rivi kerrallaan, paletti-deltat (rasterefektit)
- **EOF**: frame valmis
- Delta-optimointi: vain muuttuneet rivit lähetetään
- Tuetut koneet: C64, Amiga OCS/ECS, Amiga AGA, NES, Atari ST, ZX Spectrum

### Mac-konfigurointisovellus (`app/`)

Natiivi SwiftUI-appi (macOS 13+). Tunnistaa donglen automaattisesti kun se kytketään USB:llä.

### 3D-kotelomallit (`case/`)

OpenSCAD-mallit dongle-koteloille. Snap-fit, tuuletusaukot, HDMI/USB-aukot.

| Malli | Alusta | Tiedosto |
|---|---|---|
| Lite | Pi Zero 2 W | `case/lite-case.scad` |
| 4K | Pi 4 | `case/4k-case.scad` |

## Kokonaiskustannus

| Kokoonpano | Hinta |
|---|---|
| Vastaanotin Lite (1080p) | ~48 € |
| Vastaanotin 4K Dual (2× HDMI) | ~92 € |
| C64-lähetin | ~35 € |
| Amiga-lähetin | ~31 € |
| CPC-lähetin | ~29.50 € |
| Amiga wireless capture (pass-through) | ~38 € |
| CPC wireless capture (pass-through) | ~33.50 € |

## Asennus

### Vastaanotin-dongle

```bash
cd receiver
chmod +x install.sh
sudo ./install.sh "Olohuone"
sudo reboot
```

### Konfigurointi (3 tapaa)

1. **HDMI** — alustamaton dongle näyttää ohjeet ruudulla
2. **Puhelin** — yhdistä `Dongle-XXXX` Wi-Fi (ei salasanaa) → selain → `http://192.168.4.1:8080`
3. **Mac USB** — kytke dongle USB:llä → DongleConfig-appi aukeaa automaattisesti

### Mac Mini (4K NDI)

```bash
brew install --cask ndi-tools
# Käynnistä NDI Screen Capture → valitse näyttö → 4K
```

### MacBook (AirPlay)

```
Ohjauskeskus → Näytön peilaus → valitse donglen nimi
```

### Renderöintiasetukset (RETRO)

Web-UI:sta tai Mac-appista:

| Moodi | Kuvaus |
|---|---|
| Pikselitarkka | Nearest neighbor, terävät pikselit |
| Pehmentävä | Bilinear interpolointi |
| CRT-simulaatio | Scanline-raidat, bloom, kaarevuus (säädettävä) |

## Dokumentaatio

| Dokumentti | Kuvaus |
|---|---|
| [BOM.md](BOM.md) | Vastaanottimien komponenttilistat |
| [RETRO_PROTOCOL.md](protocol/RETRO_PROTOCOL.md) | Protokollaspesifikaatio |
| [docs/index.html](docs/index.html) | Projektiyhteenveto (HTML) |
| [docs/c64-wireless-pitch.html](docs/c64-wireless-pitch.html) | C64 Wireless pitch deck |
| [docs/c64-3d.html](docs/c64-3d.html) | 3D-järjestelmänäkymä (interaktiivinen) |

## Rakenne

```
hdmidongle/
├── receiver/              Vastaanotin-dongle
│   ├── install.sh         Asennusskripti (tunnistaa Pi-mallin)
│   ├── dongle-switcher.sh NDI/RETRO/AirPlay-ohjainlogiikka
│   ├── config-server.py   Flask HTTP API + web UI
│   ├── web-ui.html        Mobiili-konfiguraatiosivu
│   ├── setup-screen.py    HDMI-ohjeet alustamattomalle
│   ├── usb-gadget-setup.sh USB ECM (Mac-konfigurointi)
│   └── wifi-ap-setup.sh   Wi-Fi AP (puhelin-konfigurointi)
├── c64-transmitter/       C64 bus snoop -lähetin
│   └── BOM.md
├── amiga-transmitter/     Amiga RGB-kaappauslähetin
│   └── BOM.md
├── cpc-transmitter/       CPC RGB-kaappauslähetin
│   └── BOM.md
├── wireless-capture/      Pass-through-kaappari (Amiga/CPC)
│   └── README.md
├── protocol/              RETRO-protokolla v1
│   └── RETRO_PROTOCOL.md
├── app/                   Mac SwiftUI -konfigurointisovellus
│   └── DongleConfig.swiftpm/
├── case/                  3D-kotelomallit (OpenSCAD)
│   ├── lite-case.scad
│   └── 4k-case.scad
├── docs/                  Dokumentaatio + pitch
│   ├── index.html
│   ├── c64-wireless-pitch.html
│   ├── c64-3d.html
│   └── system-3d.html
├── BOM.md                 Vastaanottimien BOM
└── README.md              Tämä tiedosto
```

## Lisenssi

Open source. Raspberry Pi + unelma vuodelta 1982.
