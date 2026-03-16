# RETRO Protocol v1

Geneerinen UDP-protokolla retrotietokoneiden kuvan langattomaan siirtoon rivi kerrallaan.

## Yleiskuva

```
Retrokone ──→ Snooper ──→ Pi Zero ──UDP──→ Vastaanotin ──HDMI──→ Näyttö
                                   port 5064
```

Lähettimen ei tarvitse tuntea vastaanotinta. Vastaanotin oppii lähteen ominaisuudet HELLO-paketista.

## Pakettityypit

### HELLO (0x00)

Lähetetään:
- Kerran käynnistyksessä
- 2 sekunnin välein (heartbeat)
- Kun konfiguraatio muuttuu (esim. Amigan screen mode vaihtuu)

```
Offset  Koko   Tyyppi      Kenttä
──────  ─────  ──────      ──────
0       5      char[5]     magic = "RETRO"
5       1      uint8       type = 0x00
6       1      uint8       version = 1
7       1      uint8       machine
8       2      uint16 LE   width (pikseleinä)
10      2      uint16 LE   height (pikseleinä)
12      1      uint8       fps
13      1      uint8       palette_size (N)
14      N×3    uint8[N×3]  palette (R, G, B per väri)
14+N×3  var    char[]      name (null-terminated, max 32 merkkiä)
```

### ROW (0x01)

Yksi rasteririvi. Lähetetään reaaliajassa rivi kerrallaan.

```
Offset  Koko   Tyyppi      Kenttä
──────  ─────  ──────      ──────
0       5      char[5]     magic = "RETRO"
5       1      uint8       type = 0x01
6       2      uint16 LE   frame (juokseva laskuri, wrappaa 65535 → 0)
8       2      uint16 LE   row (0-indexed)
10      1      uint8       palette_changes (N, 0 = ei muutoksia)
11      N×4    uint8[N×4]  palette_deltas: [index, R, G, B] × N
11+N×4  var    uint8[]     pixel_data: width tavua, paletti-indeksejä
```

### EOF (0x02)

Frame valmis. Lähetetään viimeisen rivin jälkeen (VBLANK).

```
Offset  Koko   Tyyppi      Kenttä
──────  ─────  ──────      ──────
0       5      char[5]     magic = "RETRO"
5       1      uint8       type = 0x02
6       2      uint16 LE   frame
```

## Machine ID:t

| ID | Kone | Resoluutio | Paletti | FPS |
|---|---|---|---|---|
| 0x00 | Commodore 64 | 320×200 | 16 väriä | 50 (PAL) |
| 0x01 | Amiga OCS/ECS | 320×256 | 32 väriä (12-bit RGBI) | 50 (PAL) |
| 0x02 | Amiga AGA | 320–640 × 200–512 | 256 väriä (24-bit RGB, ADC) | 50 (PAL) |
| 0x03 | NES | 256×240 | 64 väriä | 60 (NTSC) |
| 0x04 | Atari ST | 320×200 | 16 väriä | 50/60 |
| 0x05 | ZX Spectrum | 256×192 | 16 väriä | 50 (PAL) |
| 0x06–0xFF | Varattu | | | |

## Kaistanvaatimukset

| Kone | Pikselidata/rivi | Rivejä | FPS | Kaista |
|---|---|---|---|---|
| C64 | 320 B | 200 | 50 | **3.2 MB/s** |
| Amiga OCS | 320 B | 256 | 50 | **4.1 MB/s** |
| Amiga AGA | 640 B | 512 | 50 | **16.4 MB/s** |
| NES | 256 B | 240 | 60 | **3.7 MB/s** |

Kaikki mahtuvat Wi-Fi 5 GHz -kaistaan (~30+ MB/s käytännössä).

## Vastaanottimen toiminta

```
1. Kuuntele UDP port 5064
2. HELLO saapuu:
   - Varaa framebuffer (width × height)
   - Lataa paletti
   - Näytä lähteen nimi ja resoluutio
3. ROW saapuu:
   - Päivitä palette_deltas (rasterefektit)
   - Renderöi pixel_data → framebuffer[row]
4. EOF saapuu:
   - Frame valmis (valinnainen, HDMI lukee fb jatkuvasti)
5. HELLO ei saavu 5s:
   - Lähde katosi → näytä "Odotetaan..." → palaa idle
```

## Lähettimen toiminta

```
1. Käynnistyessä: lähetä HELLO
2. Joka 2s: lähetä HELLO (heartbeat)
3. Joka rasteririvi:
   a. Lue koneen video-muistista rivin data
   b. Vertaa edelliseen: jos muuttunut, lähetä ROW
   c. Jos paletti/rekisterit muuttuneet tällä rivillä, liitä palette_deltas
4. VBLANK: lähetä EOF
```

## Delta-optimointi (valinnainen)

Jos rivi ei ole muuttunut edellisestä framesta, sitä ei tarvitse lähettää. Vastaanotin pitää edellisen framen framebufferissa. Tämä vähentää kaistaa merkittävästi staattisissa ruuduissa (esim. tekstieditori, valikko).

## Esimerkkipaketteja

### C64 HELLO
```
52 45 54 52 4F    "RETRO"
00                type = HELLO
01                version = 1
00                machine = C64
40 01             width = 320
C8 00             height = 200
32                fps = 50
10                palette_size = 16
00 00 00          #000000 (musta)
FF FF FF          #FFFFFF (valkoinen)
88 00 00          #880000 (punainen)
AA FF EE          #AAFFEE (syaani)
CC 44 CC          #CC44CC (purppura)
00 CC 55          #00CC55 (vihreä)
00 00 AA          #0000AA (sininen)
EE EE 77          #EEEE77 (keltainen)
DD 88 55          #DD8855 (oranssi)
66 44 00          #664400 (ruskea)
FF 77 77          #FF7777 (vaaleanpunainen)
33 33 33          #333333 (tummanharmaa)
77 77 77          #777777 (harmaa)
AA FF 66          #AAFF66 (vaaleanvihreä)
00 88 FF          #0088FF (vaaleansininen)
BB BB BB          #BBBBBB (vaaleanharmaa)
43 6F 6D 6D 6F   "Commodore 64\0"
64 6F 72 65 20
36 34 00
```

### C64 ROW (rivi 100, rasterbar-efekti)
```
52 45 54 52 4F    "RETRO"
01                type = ROW
2A 00             frame = 42
64 00             row = 100
01                palette_changes = 1
00 88 00 00       palette[0] = #880000 (taustaväri vaihtuu punaiseksi)
[320 tavua]       pixel_data (paletti-indeksejä)
```
