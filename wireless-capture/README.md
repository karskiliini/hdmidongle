# Wireless Capture Device

Langaton kuvankaappari retrotietokoneille. Kaappaa videosignaalin ja välittää sen langattomasti HDMI-vastaanottimelle — alkuperäinen näyttö jatkaa normaalisti.

## Konsepti

```
Retrokone ──→ [Wireless Capture] ──→ Alkuperäinen näyttö (CRT/monitor)
                    │
               Wi-Fi (RETRO-protokolla)
                    │
              Vastaanotin ──HDMI──→ Moderni näyttö / tallennin
```

## Miksi pass-through?

- Pelaa alkuperäisellä CRT-näytöllä (paras latenssi, aito kokemus)
- Samalla striimaa/tallenna modernille näytölle tai tietokoneelle
- Demo-esitykset: yleisö näkee projektorilta, esiintyjä CRT:ltä
- Speedrun-striimaus: pelaaja käyttää CRT:tä, katsojat näkevät HDMI-kaappauksen

## Tuetut koneet

| Kone | Liitin sisään | Liitin ulos | Kaappaustapa | Pass-through |
|---|---|---|---|---|
| C64 | Expansion port | (ei vaikuta videoon) | Bus snoop | Automaattinen — signaali ei katkea |
| Amiga 500/1200 | DB23 naaras | DB23 uros | RGB buffer + ADC/PIO | Aktiivinen puskuroitu jakaja |
| CPC 464/664/6128 | 6-pin DIN naaras | 6-pin DIN uros | Komparaattorit + buffer | Aktiivinen puskuroitu jakaja |

## Arkkitehtuuri

### C64 (jo pass-through)

```
C64 expansion port ──→ Snooper-kortti (passiivinen kuuntelu)
C64 video out ──→ CRT-näyttö (ei muutosta)
```

Bus snooper ei koske videosignaaliin — C64:n oma video-ulostulo toimii normaalisti.

### Amiga

```
                    ┌─────────────────────────────────┐
Amiga DB23 (uros) ──→│  PASS-THROUGH CAPTURE DEVICE     │──→ DB23 (naaras) → Näyttö
                    │                                   │
                    │  RGB buffer (THS7316 × 1)         │
                    │  ├─→ Näyttö (puskuroitu, esteetön)│
                    │  └─→ Pico PIO (digitaalinen RGBI) │
                    │      tai ADC (analoginen RGB)      │
                    │                                   │
                    │  Pico ──SPI──→ Pi Zero ──Wi-Fi──→  │
                    └─────────────────────────────────┘
```

Signaalinjakaja:
- **THS7316** (TI triple video buffer/filter) — jakaa RGB:n kahteen suuntaan
  - Ulostulo 1: näytölle (puskuroitu, 75Ω terminoitu)
  - Ulostulo 2: Pico PIO:lle tai ADC:lle (kaappaus)
- CSYNC menee suoraan molempiin (digitaalinen, ei vaimene)
- Yksi IC, ~2 €

### CPC

```
                    ┌─────────────────────────────────┐
CPC 6-pin DIN ────→│  PASS-THROUGH CAPTURE DEVICE     │──→ 6-pin DIN → Näyttö
                    │                                   │
                    │  RGB buffer (THS7316)              │
                    │  ├─→ Näyttö                        │
                    │  └─→ Komparaattorit → Pico PIO     │
                    │                                   │
                    │  Pico ──SPI──→ Pi Zero ──Wi-Fi──→  │
                    └─────────────────────────────────┘
```

Sama periaate kuin Amiga, eri liittimet.

## Miksi THS7316?

| Vaihtoehto | Hinta | Laatu | Huomiot |
|---|---|---|---|
| Passiivinen vastusjakaja | ~0.50 € | Heikko | Vaimentaa signaalia, häiriöherkkä |
| THS7316 (video buffer) | ~2 € | Erinomainen | Aktiivinen, ei vaimenna, 75Ω ajuri |
| AD8013 (triple op-amp) | ~5 € | Hyvä | Ylimitoitettu, kalliimpi |

THS7316 on suunniteltu juuri tähän — retro RGB -signaalin jakamiseen.

## Liitinvaihtoehdot

### Amiga pass-through -kaapeli

```
DB23 uros ──[kaapeli 15cm]──→ PCB ──[kaapeli 15cm]──→ DB23 naaras
(kiinni Amigassa)              │                      (kiinni näytössä)
                          Capture-elektroniikka
                          + Pi Pico + Pi Zero
```

### CPC pass-through -kaapeli

```
6-pin DIN uros ──[kaapeli]──→ PCB ──[kaapeli]──→ 6-pin DIN naaras
(kiinni CPC:ssä)                │                (kiinni näytössä)
                          Capture-elektroniikka
```

## BOM

### Amiga Wireless Capture (pass-through)

| # | Komponentti | Kpl | Hinta (€) | Huomiot |
|---|-------------|-----|-----------|---------|
| 1 | Pi Pico (RP2040) | 1 | ~5 | PIO kaappaus + SPI |
| 2 | Pi Zero 2 W | 1 | ~18 | Wi-Fi TX |
| 3 | THS7316 (video buffer) | 1 | ~2 | RGB pass-through jakaja |
| 4 | DB23-liitin naaras (sisään) | 1 | ~5 | Amigasta sisään |
| 5 | DB23-liitin uros (ulos) | 1 | ~5 | Näytölle ulos |
| 6 | PCB | 1 | ~3 | |
| | **Yhteensä** | | **~38 €** | |

### CPC Wireless Capture (pass-through)

| # | Komponentti | Kpl | Hinta (€) | Huomiot |
|---|-------------|-----|-----------|---------|
| 1 | Pi Pico (RP2040) | 1 | ~5 | PIO kaappaus + SPI |
| 2 | Pi Zero 2 W | 1 | ~18 | Wi-Fi TX |
| 3 | THS7316 (video buffer) | 1 | ~2 | RGB pass-through jakaja |
| 4 | 2× LM339 (komparaattorit) | 2 | ~1 | 3-tasoinen RGB digitointi |
| 5 | 6-pin DIN uros (sisään) | 1 | ~2 | CPC:stä sisään |
| 6 | 6-pin DIN naaras (ulos) | 1 | ~2 | Näytölle ulos |
| 7 | Vastukset | 6 | ~0.50 | Jännitejaot |
| 8 | PCB | 1 | ~3 | |
| | **Yhteensä** | | **~33.50 €** | |

### C64 Wireless Capture

Sama kuin c64-transmitter (~35 €). Bus snoop on jo pass-through — ei lisäkomponentteja.
