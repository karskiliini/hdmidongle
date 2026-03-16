# C64 Wireless Transmitter — BOM

Lähettää C64:n kuvan langattomasti vastaanotin-donglelle.

## Komponentit

| # | Komponentti | Tuote | Kpl | Hinta (€) | Huomiot |
|---|-------------|-------|-----|-----------|---------|
| 1 | Raspberry Pi Pico | RP2040 | 1 | ~5 | PIO bus snooping, shadow frame buffer |
| 2 | Level shifter | 74LVC245 (8-ch) | 4 | ~2 | 5V C64 → 3.3V Pico (A0-A15, D0-D7, R/W, PHI2, BA) |
| 3 | C64 expansion port -liitin | 44-pin edge connector | 1 | ~5 | Passiivinen kuuntelu |
| 4 | Raspberry Pi Zero 2 W | Headerless | 1 | ~18 | Wi-Fi TX, UDP row-by-row |
| 5 | PCB / kytkentälevy | Protoboard tai custom PCB | 1 | ~5 | Pico + level shifterit + liitin |

| | **Yhteensä: ~35 €** |
|---|---|

## Signaalit (C64 → Pico via 74LVC245)

| Signaali | Pinnit | 74LVC245 IC |
|---|---|---|
| A0–A7 | 8 linjaa | IC1 |
| A8–A15 | 8 linjaa | IC2 |
| D0–D7 | 8 linjaa | IC3 |
| R/W, PHI2, BA + vara | 3 + 5 linjaa | IC4 |
