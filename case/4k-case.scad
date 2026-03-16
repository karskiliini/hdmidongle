// Wireless Display Dongle — 4K-kotelo (Pi 4 Model B)
// Mitat perustuvat Raspberry Pi 4 Model B:n virallisiin mittoihin
//
// Tulosta: PETG (lämmönkesto), 0.2mm layer height
// Kotelo on kaksiosainen: pohja + kansi snap-fit-lukituksella

/* [Asetukset] */
wall = 2.0;       // seinämän paksuus - paksumpi kuin lite (lämpö)
tol = 0.3;        // toleranssi

/* [Pi 4 Model B mitat] */
pcb_w = 85.0;     // leveys
pcb_d = 56.0;     // syvyys
pcb_h = 1.4;      // piirilevyn paksuus
comp_h = 5.0;     // komponenttien korkeus yläpuolella
bottom_h = 2.5;   // komponenttien korkeus alapuolella (SD-kortin lukija)

/* [Liittimet - Pi 4:n vasemmasta reunasta mitattuna] */
// Micro-HDMI 0: vasen pääty (USB-C:n puoli)
hdmi0_offset = 25.0;
hdmi0_w = 7.5;
hdmi0_h = 3.5;

// Micro-HDMI 1:
hdmi1_offset = 38.5;
hdmi1_w = 7.5;
hdmi1_h = 3.5;

// USB-C (virta): vasen pääty
usbc_offset = 11.2;
usbc_w = 9.5;
usbc_h = 3.5;

// USB-A portit: oikea pääty (ei aukkoa - ei tarvita)

// Ethernet: oikea pääty (ei aukkoa - ei tarvita)

// microSD: vasen pääty, piirilevyn alapuolella
sd_offset = 2.0;   // reunasta
sd_w = 14.0;
sd_h = 2.0;

// GPIO: pitkä sivu, yläpuoli (ei aukkoa)

/* [Jäähdytys] */
// Pi 4 tarvitsee tehokkaampaa jäähdytystä
heatsink_h = 5.0;
fan_diameter = 25.0;  // valinnainen 25mm tuuletin

/* [Lasketut mitat] */
inner_w = pcb_w + tol * 2;
inner_d = pcb_d + tol * 2;
inner_h = bottom_h + pcb_h + comp_h + heatsink_h + 2.0;

outer_w = inner_w + wall * 2;
outer_d = inner_d + wall * 2;
outer_h = inner_h + wall * 2;

snap_w = 4.0;
snap_h = 1.2;
snap_depth = 0.8;

module case_bottom() {
    difference() {
        rounded_box(outer_w, outer_d, outer_h / 2 + wall, 3);

        // Sisätila
        translate([wall, wall, wall])
            cube([inner_w, inner_d, outer_h]);

        // Micro-HDMI 0 -aukko
        translate([-1, wall + tol + hdmi0_offset - hdmi0_w/2, wall + bottom_h])
            cube([wall + 2, hdmi0_w, hdmi0_h + 2]);

        // Micro-HDMI 1 -aukko
        translate([-1, wall + tol + hdmi1_offset - hdmi1_w/2, wall + bottom_h])
            cube([wall + 2, hdmi1_w, hdmi1_h + 2]);

        // USB-C virta-aukko
        translate([-1, wall + tol + usbc_offset - usbc_w/2, wall + bottom_h])
            cube([wall + 2, usbc_w, usbc_h + 2]);

        // microSD-aukko (alapuoli, vasen pääty)
        translate([-1, wall + tol + sd_offset, -1])
            cube([wall + 2, sd_w, wall + sd_h + 1]);

        // Sivujen tuuletusaukot
        for (i = [0:4]) {
            translate([wall + 10 + i * 14, -1, outer_h / 2 - 3])
                cube([10, wall + 2, 2]);
            translate([wall + 10 + i * 14, outer_d - wall - 1, outer_h / 2 - 3])
                cube([10, wall + 2, 2]);
        }
    }

    // Piirilevyn tuet (Pi 4:n kiinnitysreiät)
    // Reiät: 3.5mm reunasta, 58mm ja 49mm välit
    hole_positions = [
        [3.5, 3.5],
        [3.5 + 58, 3.5],
        [3.5, 3.5 + 49],
        [3.5 + 58, 3.5 + 49]
    ];
    for (pos = hole_positions)
        translate([wall + tol + pos[0], wall + tol + pos[1], wall])
            difference() {
                cylinder(h = bottom_h, r = 3.0, $fn = 20);
                cylinder(h = bottom_h + 1, r = 1.3, $fn = 20);  // M2.5 ruuvi
            }

    // Snap-fit korvakkeet
    for (y = [outer_d * 0.25, outer_d * 0.5, outer_d * 0.75]) {
        translate([-snap_depth, y - snap_w/2, outer_h/2])
            cube([snap_depth, snap_w, snap_h]);
        translate([outer_w, y - snap_w/2, outer_h/2])
            cube([snap_depth, snap_w, snap_h]);
    }
}

module case_top() {
    difference() {
        rounded_box(outer_w, outer_d, outer_h / 2 + wall, 3);

        // Sisätila
        translate([wall, wall, -1])
            cube([inner_w, inner_d, outer_h]);

        // Tuuletusaukot yläpinnalla (ristikko)
        for (i = [0:3])
            for (j = [0:2])
                translate([wall + 12 + i * 18, wall + 10 + j * 16, outer_h/2])
                    cube([12, 10, wall + 2]);

        // Valinnainen tuuletinaukko (25mm, SoC:n yläpuolella)
        translate([wall + tol + 30, wall + tol + 28, outer_h/2])
            cylinder(h = wall + 2, d = fan_diameter + 1, $fn = 40);

        // Snap-fit urat
        for (y = [outer_d * 0.25, outer_d * 0.5, outer_d * 0.75]) {
            translate([-1, y - snap_w/2 - tol, -snap_h - tol])
                cube([wall + 1 + snap_depth + tol, snap_w + tol*2, snap_h + tol]);
            translate([outer_w - wall - snap_depth - tol, y - snap_w/2 - tol, -snap_h - tol])
                cube([wall + 1 + snap_depth + tol, snap_w + tol*2, snap_h + tol]);
        }
    }
}

module rounded_box(w, d, h, r) {
    hull() {
        for (x = [r, w - r])
            for (y = [r, d - r])
                translate([x, y, 0])
                    cylinder(h = h, r = r, $fn = 20);
    }
}

// --- Renderöinti ---
// Pohja
case_bottom();

// Kansi (siirretty viereen)
translate([outer_w + 15, 0, outer_h / 2 + wall])
    mirror([0, 0, 1])
        case_top();
