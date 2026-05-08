# Power Distribution Network (PDN) — Layer Stack

## PDN structure

```
  Layer   Dir    Width    Pitch     Offset    Purpose
  ──────  ─────  ───────  ────────  ────────  ──────────────────────────
  met5    H      1.60µm   27.20µm   13.60µm   Top-level PDN strap
  met4    V      1.60µm   27.14µm   13.57µm   Vertical strap (VDD/VSS alt)
  met3    H      0.30µm   —         —          Signal routing
  met2    V      0.14µm   —         —          Signal routing
  met1    H      0.48µm   5.44µm    0.00µm    Followpin (abuts std-cell rails)
  li1     H      internal —         —          Intra-cell power (library)
```

## Cross-section view (cut through tile, looking west)

```
  ┌───────────────────────────────────────────────────────────────────┐
  │                          met5  (horizontal)                        │
  │    ████ VDD ████     ░░░░ VSS ░░░░     ████ VDD ████              │
  │                      pitch = 27.20 µm                             │
  └───────────────────────────────────────────────────────────────────┘
            │                 │                 │
  ┌─────────┼─────────────────┼─────────────────┼─────────────────────┐
  │         │      met4 (vertical)               │                     │
  │    ████ VDD               ░░░░ VSS     ████ VDD                    │
  │    pitch = 27.14 µm                                               │
  └─────────────────────────────────────────────────────────────────  ┘
                             via34
  ┌───────────────────────────────────────────────────────────────────┐
  │                  met1  followpin  (horizontal)                     │
  │   ─── VDD rail ──────────────────────────────── VDD rail ───      │
  │   ─── VSS rail ──────────────────────────────── VSS rail ───      │
  │   pitch = row_height / 2 = 1.36 µm                                │
  └───────────────────────────────────────────────────────────────────┘
  ┌───────────────────────────────────────────────────────────────────┐
  │             Standard cells  (sky130_fd_sc_hd)                     │
  │   ████████████████  VDD (li1)  ████████████████                   │
  │   NMOS body │ PMOS body │ logic │ NMOS body │ PMOS body           │
  │   ░░░░░░░░░░░░░░░░  VSS (li1)  ░░░░░░░░░░░░░░░░░░                │
  └───────────────────────────────────────────────────────────────────┘
```

## PDN Tcl commands (pdn.tcl)

```tcl
# met1 followpin rails — connect to standard cell VDD/VSS
add_global_connection -net VDD -pin_pattern "^VDD$" -power
add_global_connection -net VSS -pin_pattern "^VSS$" -ground
set_voltage_domain -power VDD -ground VSS

define_pdn_grid -name "Core" -voltage_domains "Core"

# met1 followpin straps
add_pdn_stripe -followpins -layer met1 -width 0.48

# met4 vertical straps
add_pdn_stripe -layer met4 -width 1.6 -pitch 27.14 -offset 13.57

# met5 horizontal straps
add_pdn_stripe -layer met5 -width 1.6 -pitch 27.20 -offset 13.60

# Connect metal layers through vias
add_pdn_connect -layers {met1 met4}
add_pdn_connect -layers {met4 met5}
```

## Coverage analysis (160 × 100 µm tile)

| Layer | VDD straps | VSS straps | Total strap area |
|-------|-----------|-----------|-----------------|
| met5  | 3         | 3         | ~45.6 µm²       |
| met4  | 3         | 3         | ~45.4 µm²       |
| met1  | 29 (rows) | 29 (rows) | ~134 µm²        |

IR drop estimate (TT / 1.8V): < 5 mV at 1 µA (combinational design, near-zero dynamic power)
