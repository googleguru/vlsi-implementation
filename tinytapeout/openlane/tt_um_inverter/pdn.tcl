# ============================================================
# Power Distribution Network — tt_um_inverter / SKY130HD
# Matches sky130hd platform straps; tuned for 160×100 µm tile.
# ============================================================

# ── Global net connections ────────────────────────────────────
# Connects standard-cell VPWR/VGND pins to the VDD/VSS nets
add_global_connection -net {VDD} -inst_pattern {.*} -pin_pattern {^VPWR$} -power
add_global_connection -net {VDD} -inst_pattern {.*} -pin_pattern {^VPB$}
add_global_connection -net {VDD} -inst_pattern {.*} -pin_pattern {^VDDPE$}
add_global_connection -net {VDD} -inst_pattern {.*} -pin_pattern {^VDDCE$}
add_global_connection -net {VSS} -inst_pattern {.*} -pin_pattern {^VGND$} -ground
add_global_connection -net {VSS} -inst_pattern {.*} -pin_pattern {^VNB$}
add_global_connection -net {VSS} -inst_pattern {.*} -pin_pattern {^VSSE$}
global_connect

# ── Voltage domain ────────────────────────────────────────────
set_voltage_domain -name CORE -power VDD -ground VSS

# ── Standard-cell grid ────────────────────────────────────────
# met1  followpin rails (VDD/VSS alternating rows, 0.48 µm wide)
# met4  vertical straps  (1.6 µm wide, 27.14 µm pitch)
# met5  horizontal straps (1.6 µm wide, 27.20 µm pitch)
define_pdn_grid \
    -name      grid \
    -voltage_domains CORE

add_pdn_stripe \
    -grid   grid \
    -layer  met1 \
    -width  0.48 \
    -pitch  5.44 \
    -offset 0 \
    -followpins

add_pdn_stripe \
    -grid   grid \
    -layer  met4 \
    -width  1.600 \
    -pitch  27.140 \
    -offset 13.570

add_pdn_stripe \
    -grid   grid \
    -layer  met5 \
    -width  1.600 \
    -pitch  27.200 \
    -offset 13.600

add_pdn_connect -grid grid -layers {met1 met4}
add_pdn_connect -grid grid -layers {met4 met5}
