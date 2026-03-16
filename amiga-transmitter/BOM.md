# Amiga Wireless Transmitter — BOM

Lähettää Amiga 500/1200:n kuvan langattomasti vastaanotin-donglelle.
Kaappaa analogisen RGB:n DB23-portista rivi kerrallaan, pipeline-mallilla.

## Yhteensopivuus

| Amiga | Toimii | Värisyvyys | Huomiot |
|---|---|---|---|
| A500 (OCS/ECS) | Kyllä | 12-bit (4096 väriä) | Täydellinen |
| A1200 (AGA) | Kyllä | 12-bit digitaalisista pinneistä | AGA 24-bit vaatii ADC-lisäkortin |
| A600, A2000, A3000, A4000 | Kyllä | Sama DB23-liitin | Testattu vain A500/A1200 |

## Komponentit

| # | Komponentti | Tuote | Kpl | Hinta (€) | Huomiot |
|---|-------------|-------|-----|-----------|---------|
| 1 | Raspberry Pi Pico | RP2040 | 1 | ~5 | Dual core: PIO kaappaus + SPI lähetys |
| 2 | DB23-liitin (naaras) | Amiga video connector | 1 | ~5 | Suoraan Amigan videoporttiin |
| 3 | Raspberry Pi Zero 2 W | Headerless | 1 | ~18 | Wi-Fi TX, UDP RETRO-protokolla |
| 4 | PCB / kytkentälevy | Protoboard tai custom | 1 | ~3 | |

| | **Yhteensä: ~31 €** |
|---|---|

## Signaalit (DB23 → Pico)

### Digitaalinen kaappaus (oletus, riittää A500 + useimpiin A1200-peleihin)

| DB23 pinni | Signaali | Pico GPIO | Huomiot |
|---|---|---|---|
| 9 | Digital Red | GP2 | TTL-taso, ei level shifteriä |
| 8 | Digital Green | GP3 | |
| 7 | Digital Blue | GP4 | |
| 6 | Digital Intensity | GP5 | 4. bitti per kanava |
| 10 | CSYNC | GP6 | Rivin/framen synkronointi |
| 15 | C1 (pixel clock) | GP7 | PIO:n kellolähde |
| 16–20 | GND | GND | |

4 bittiä RGBI → 16 väriä per rivi, Pico:n PIO lukee pikselikellolla.

### Analoginen kaappaus (valinnainen lisäkortti, täysi AGA 24-bit)

| DB23 pinni | Signaali | ADC-kanava |
|---|---|---|
| 3 | Analog Red | ADC CH0 |
| 4 | Analog Green | ADC CH1 |
| 5 | Analog Blue | ADC CH2 |
| 10 | CSYNC | Digitaalinen trigeri |

Vaatii 3× 8-bit ADC @ 28+ MHz (esim. AD9283). Lisätään myöhemmin tarvittaessa.

## Arkkitehtuuri

```
Amiga DB23 ──→ Pico (RP2040) ──SPI 20MHz──→ Pi Zero 2W ──Wi-Fi──→ Vastaanotin
                │                             │
                │ Ydin 0: PIO kaappaa         │ UDP RETRO-protokolla
                │ Ydin 1: DMA+SPI lähettää    │ rivi kerrallaan
                │ Tuplapuskuri A/B             │
                └─────────────────────────────┘

Pipeline (limitetty):
  Rivi N:    PIO kaappaa → puskuri A     DMA lähettää puskuri B → SPI
  HBlank:    vaihda A ↔ B
  Rivi N+1:  PIO kaappaa → puskuri B     DMA lähettää puskuri A → SPI
```

## Ajoitus (PAL lores 320×256)

| Vaihe | Data | Aika |
|---|---|---|
| PIO kaappaa 320 pikseliä | 320 tavua | ~46 µs (rinnakkain) |
| SPI lähettää edellinen rivi | 320 tavua @ 20 MHz | ~13 µs (rinnakkain) |
| Yksi rasteririvi | | 64 µs |
| **Pipeline-viive** | | **1 rivi = 64 µs** |
