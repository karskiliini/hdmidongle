# CPC 464 Wireless Transmitter — BOM

Lähettää Amstrad CPC 464:n kuvan langattomasti vastaanotin-donglelle.
Kaappaa analogisen RGB:n 6-pin DIN -portista komparaattoreilla.

## Yhteensopivuus

| CPC-malli | Toimii | Huomiot |
|---|---|---|
| CPC 464 | Kyllä | 6-pin DIN video out |
| CPC 664 | Kyllä | Sama liitin |
| CPC 6128 | Kyllä | Sama liitin |

## Komponentit

| # | Komponentti | Tuote | Kpl | Hinta (€) | Huomiot |
|---|-------------|-------|-----|-----------|---------|
| 1 | Raspberry Pi Pico | RP2040 | 1 | ~5 | PIO kaappaus + SPI |
| 2 | 6-pin DIN -liitin (uros) | 240° | 1 | ~2 | Suoraan CPC:n videoporttiin |
| 3 | Komparaattori-IC | 2× LM339 (quad) | 2 | ~1 | 6 komparaattoria (2 per RGB-kanava) |
| 4 | Vastukset | Jännitejakovastukset | 6 | ~0.50 | Kynnysarvot ~0.2V ja ~0.5V |
| 5 | Raspberry Pi Zero 2 W | Headerless | 1 | ~18 | Wi-Fi TX, UDP RETRO-protokolla |
| 6 | PCB / kytkentälevy | Protoboard | 1 | ~3 | |

| | **Yhteensä: ~29.50 €** |
|---|---|

## Signaalit (6-pin DIN → komparaattorit → Pico)

```
CPC pinni 1 (Red)   ──→ 2× komparaattori ──→ 2 bittiä ──→ Pico GP2, GP3
CPC pinni 2 (Green) ──→ 2× komparaattori ──→ 2 bittiä ──→ Pico GP4, GP5
CPC pinni 3 (Blue)  ──→ 2× komparaattori ──→ 2 bittiä ──→ Pico GP6, GP7
CPC pinni 4 (CSYNC) ──→ suoraan (TTL) ──────────────────→ Pico GP8
CPC pinni 5 (GND)   ──→ GND
```

Kukin RGB-kanava on 3-tasoinen (0V / ~0.35V / ~0.7V):
- Komparaattori 1 (kynnys ~0.2V): erottaa 0 muista → bitti 0
- Komparaattori 2 (kynnys ~0.5V): erottaa täyden puolikkaasta → bitti 1

Tulos: 2 bittiä per kanava × 3 kanavaa = 6 bittiä = 64 tasoa → mapataan 27 CPC-väriin.

## Resoluutiot

| Mode | Resoluutio | Värit | Pikselikello |
|---|---|---|---|
| 0 | 160×200 | 16 (27:stä) | ~4 MHz |
| 1 | 320×200 | 4 (27:stä) | ~8 MHz |
| 2 | 640×200 | 2 (27:stä) | ~16 MHz |

PIO kellottaa CSYNC:illä — automaattinen mooditunnistus pikselilaskurin perusteella.
