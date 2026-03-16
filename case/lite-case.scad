// Wireless Display Dongle — Lite-kotelo (Pi Zero 2 W)
// Mitat perustuvat Raspberry Pi Zero 2 W:n virallisiin mittoihin
//
// Tulosta: PETG tai PLA, 0.2mm layer height, ei tukia tarvita
// Kotelo on kaksiosainen: pohja + kansi snap-fit-lukituksella

/* [Asetukset] */
// Seinämän paksuus (mm)
wall = 1.6;
// Toleranssi (mm) - säädä tulostimen mukaan
tol = 0.3;

/* [Pi Zero 2 W mitat] */
pcb_w = 65.0;    // leveys
pcb_d = 30.0;    // syvyys
pcb_h = 1.0;     // piirilevyn paksuus
comp_h = 3.5;    // komponenttien korkeus piirilevyn yläpuolella
bottom_h = 1.5;  // komponenttien korkeus piirilevyn alapuolella

/* [Liittimet - etäisyydet piirilevyn reunasta] */
// Mini-HDMI: vasen reuna, piirilevyn keskeltä
hdmi_offset_x = 12.4;  // keskikohta vasemmasta reunasta
hdmi_w = 11.2;
hdmi_h = 3.5;

// Micro-USB (virta): vasen reuna
usb_offset_x = 41.4;   // keskikohta vasemmasta reunasta
usb_w = 8.0;
usb_h = 3.0;

// microSD: oikea reuna (pitkä sivu)
sd_offset_y = 16.9;    // keskikohta alareunasta
sd_w = 12.0;
sd_h = 1.5;

/* [Jäähdytys] */
heatsink_w = 14.0;
heatsink_d = 14.0;
heatsink_h = 3.0;

/* [Lasketut mitat] */
inner_w = pcb_w + tol * 2;
inner_d = pcb_d + tol * 2;
inner_h = bottom_h + pcb_h + comp_h + heatsink_h + 1.0;  // +1mm ilmarako

outer_w = inner_w + wall * 2;
outer_d = inner_d + wall * 2;
outer_h = inner_h + wall * 2;

// Snap-fit korvakkeet
snap_w = 3.0;
snap_h = 1.0;
snap_depth = 0.6;

module case_bottom() {
    difference() {
        // Ulkokuori
        rounded_box(outer_w, outer_d, outer_h / 2 + wall, 2);

        // Sisätila
        translate([wall, wall, wall])
            cube([inner_w, inner_d, outer_h]);

        // Mini-HDMI-aukko (vasen pääty)
        translate([-1, wall + tol + hdmi_offset_x - hdmi_w/2, wall + bottom_h])
            cube([wall + 2, hdmi_w, hdmi_h + 2]);

        // Micro-USB-aukko (vasen pääty)
        translate([-1, wall + tol + usb_offset_x - usb_w/2, wall + bottom_h])
            cube([wall + 2, usb_w, usb_h + 2]);

        // microSD-aukko (pitkä sivu, oikea)
        translate([wall + tol + sd_offset_y - sd_w/2, outer_d - wall - 1, wall])
            cube([sd_w, wall + 2, sd_h + bottom_h + 2]);

        // Tuuletusaukot (yläpinta - tässä puolikkaassa sivut)
        for (i = [0:3]) {
            translate([wall + 10 + i * 12, -1, outer_h / 2 - 2])
                cube([8, wall + 2, 1.5]);
            translate([wall + 10 + i * 12, outer_d - wall - 1, outer_h / 2 - 2])
                cube([8, wall + 2, 1.5]);
        }
    }

    // Piirilevyn tuet (4 kulmaa)
    for (x = [wall + tol + 3.5, wall + tol + pcb_w - 3.5])
        for (y = [wall + tol + 3.5, wall + tol + pcb_d - 3.5])
            translate([x, y, wall])
                cylinder(h = bottom_h, r = 1.5, $fn = 20);

    // Snap-fit korvakkeet
    for (y = [outer_d * 0.3, outer_d * 0.7]) {
        translate([-snap_depth, y - snap_w/2, outer_h/2])
            cube([snap_depth, snap_w, snap_h]);
        translate([outer_w, y - snap_w/2, outer_h/2])
            cube([snap_depth, snap_w, snap_h]);
    }
}

module case_top() {
    difference() {
        // Ulkokuori
        rounded_box(outer_w, outer_d, outer_h / 2 + wall, 2);

        // Sisätila
        translate([wall, wall, -1])
            cube([inner_w, inner_d, outer_h]);

        // Tuuletusaukot (yläpinta)
        for (i = [0:2]) {
            translate([wall + 15 + i * 14, wall + 8, outer_h/2])
                cube([10, inner_d - 16, wall + 2]);
        }

        // Snap-fit urat
        for (y = [outer_d * 0.3, outer_d * 0.7]) {
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

// Kansi (siirretty viereen tulostusta varten)
translate([outer_w + 10, 0, outer_h / 2 + wall])
    mirror([0, 0, 1])
        case_top();
