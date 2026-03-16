# Komponenttilista (BOM)

## Lite-dongle (AirPlay, 1080p) — Pi Zero 2 W

| # | Komponentti | Tuote | Kpl | Hinta (€) | Huomiot |
|---|-------------|-------|-----|-----------|---------|
| 1 | Raspberry Pi Zero 2 W | Headerless-versio | 1 | ~18 | Quad A53 1 GHz, 512 MB, Wi-Fi |
| 2 | microSD-kortti | SanDisk Ultra 32 GB Class 10 A1 | 1 | ~10 | 16 GB minimi |
| 3 | Mini-HDMI → HDMI -adapteri | UGREEN flat / CY 90° kulma | 1 | ~8 | Tarkista HDMI-portin suunta ennen ostoa |
| 4 | Micro-USB-virtakaapeli | 30 cm kulma, esim. StarTech | 1 | ~6 | Kulmaliitin pitää profiilin matalana |
| 5 | Jäähdytyslevy | Kupari/alumiini 14×14×3 mm | 1 | ~3 | Estää lämpökuristuksen |
| 6 | 3D-tulostettu kotelo | PLA tai PETG | 1 | ~3 | Tuuletusaukot, microSD-aukko |

| | **Lite yhteensä: ~48 €** |
|---|---|

## 4K Dual -dongle (NDI, 2× 4K) — Pi 4

Yksi Pi 4 ajaa kaksi 4K-näyttöä (HDMI 0 + HDMI 1, kloonaus).

| # | Komponentti | Tuote | Kpl | Hinta (€) | Huomiot |
|---|-------------|-------|-----|-----------|---------|
| 1 | Raspberry Pi 4 (2 GB) | Pi 4 Model B | 1 | ~45 | H.265 4K60 HW-dekoodaus, 2× micro-HDMI |
| 2 | microSD-kortti | SanDisk Ultra 32 GB Class 10 A1 | 1 | ~10 | 16 GB minimi |
| 3 | Micro-HDMI → HDMI -adapteri | UGREEN flat / CY 90° kulma | **2** | ~16 | Yksi per HDMI-portti |
| 4 | USB-C-virtakaapeli | 30 cm, 5V/3A | 1 | ~8 | Pi 4 vaatii USB-C |
| 5 | Jäähdytyslevy + tuuletin | Alumiinikotelo tai aktiivijäähdytys | 1 | ~8 | 4K-dekoodaus kuumentaa |
| 6 | 3D-tulostettu kotelo | PETG (lämmönkesto) | 1 | ~5 | Isompi kuin Lite, tuuletusaukot |

**Huomio:** Pi 4 suositellaan Pi 5:n sijaan — Pi 4:ssä on H.265 HW-dekooderi, Pi 5:ssä ei.

| | **4K Dual yhteensä: ~92 €** |
|---|---|

## Valinnainen

| # | Komponentti | Tuote | Kpl | Hinta (€) | Huomiot |
|---|-------------|-------|-----|-----------|---------|
| 7 | HDMI → DVI -adapteri | UGREEN HDMI F → DVI-D M | 1 | ~8 | DVI-näyttöjä varten. Ei ääntä. |
| 8 | USB-virtalähde | 5V/3A USB-C seinälaturi | 1 | ~12 | Jos monitorin USB ei riitä |

## Mac Mini -puoli

| Komponentti | Hinta | Huomiot |
|---|---|---|
| NDI Tools | Ilmainen | `brew install --cask ndi-tools` |
| 5 GHz Wi-Fi -reititin | (oletetaan olemassa) | 5 GHz pakollinen 4K-striimaukseen |

## Kokonaiskustannus

| Kokoonpano | Laitteet | Hinta |
|---|---|---|
| 1× Lite (läppäri → 1080p) | Pi Zero 2 W | ~48 € |
| 1× 4K Dual (Mac Mini → 2× 4K) | Pi 4 | ~92 € |
| **Yhteensä** | **2 Pi:tä, 3 näyttöä** | **~140 €** |

Säästö edelliseen (2× Pi 4): **~76 €**
