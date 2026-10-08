// File Path: src/hardware/univac_power_chassis.scad
// =========================================================================
// UNIVAC IX INDUSTRIAL SYSTEMS — HARDENED POWER CHASSIS CONFIGURATION
// Aerospace-Inspired Welded Double Seam Weatherproof Sub-Station Panel
// Mating Boundaries Derived from Project Mercury Pressure Vessel Layouts
// =========================================================================

$fn = 100; // Enforce high-precision circle rendering loops

// --- Physical Unit Conversions & Sizing (Millimeters) ---
inch = 25.4;
chassis_width  = 18.0 * inch; // Standard compact substation footprint (~457mm)
chassis_length = 24.0 * inch; // ~609mm vertical panel run
chassis_depth  = 8.0 * inch;  // ~203mm internal stack depth
wall_thickness = 4.0;         // 4mm Marine-Grade 316 Stainless Steel plate

// --- Welded Double Seam Geometry Arrays ---
seam_width = 3.0;            // Width of individual laser-weld passes
seam_gap   = 4.5;            // Trapped inert gas buffer gap between the twin seams

module main_power_enclosure_housing() {
    difference() {
        // Main outer structural protective block shell
        cube([chassis_width, chassis_length, chassis_depth], center = true);
        
        // Internal hollow bay housing circuit breakers and solid-state drivers
        translate([0, 0, wall_thickness])
            cube([chassis_width - (wall_thickness * 2), 
                  chassis_length - (wall_thickness * 2), 
                  chassis_depth], center = true);
                  
        // Mill the specialized aerospace dual-concentric structural weld tracks
        translate([0, 0, (chassis_depth / 2) - 1])
            welded_double_seam_profile();
    }
}

module welded_double_seam_profile() {
    // Inner primary hermetic laser-weld seam loop line
    difference() {
        square([chassis_width - 8, chassis_length - 8], center = true);
        square([chassis_width - 8 - (seam_width * 2), chassis_length - 8 - (seam_width * 2)], center = true);
    }
    
    // Outer secondary backup safety shield weld seam loop line
    // Traps an inert nitrogen cushion between the seams to eliminate condensation
    difference() {
        square([chassis_width - 8 + (seam_gap * 2), chassis_length - 8 + (seam_gap * 2)], center = true);
        square([chassis_width - 8 + (seam_gap * 2) - (seam_width * 2), chassis_length - 8 + (seam_gap * 2) - (seam_width * 2)], center = true);
    }
}

module internal_power_distribution_rail_layout() {
    // 1. High-Current Solid-State Input Bus Bar (240V AC / 100A Rail)
    color("Gold") translate([0, 8*inch, 0])
        cube([chassis_width - 40, 0.5*inch, 1.5*inch], center = true);
        
    // 2. Automated Solid-State Actuator Dispatches Array
    // Dedicated load points powering utility devices clear of mechanical linkages
    color("DarkDarkGrey") {
        translate([-4*inch, 0, 0]) cube([2*inch, 3*inch, 1*inch], center = true); // Load 01: Door Openers
        translate([-1*inch, 0, 0]) cube([2*inch, 3*inch, 1*inch], center = true); // Load 02: Garage Gates
        translate([2*inch, 0, 0])  cube([2*inch, 3*inch, 1*inch], center = true); // Load 03: Industrial Mixers
        translate([5*inch, 0, 0])  cube([2*inch, 3*inch, 1*inch], center = true); // Load 04: Solenoid Locks
    }
}

// Render the composite structural assembly overview
color("SteelBlue") main_power_enclosure_housing();
internal_power_distribution_rail_layout();
