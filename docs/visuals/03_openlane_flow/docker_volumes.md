# Docker Setup — Volume Mounts & Environment Variables

## Volume mount diagram

```
  ╔══════════════════════════════════════════════════════════════════╗
  ║  HOST FILESYSTEM                                                 ║
  ║                                                                  ║
  ║  ~/vlsi-implementation/tinytapeout/  ──────────────────────────► /project
  ║  │  src/          RTL sources                                    ║
  ║  │  openlane/     OpenLane configs                               ║
  ║  │  scripts/      run_flow.sh, run_checks.sh                     ║
  ║  │  Makefile      per-stage targets                              ║
  ║  │  Dockerfile    extends efabless/openlane image                ║
  ║  └─ docker-compose.yml                                           ║
  ║                                                                  ║
  ║  ~/.pdks/  (PDK_ROOT)  ────────────────────────────────────────► /pdks
  ║     sky130A/                                                      ║
  ║       libs.ref/                                                  ║
  ║         sky130_fd_sc_hd/                                         ║
  ║           lib/          timing models (.lib)                     ║
  ║           lef/          abstract LEF                             ║
  ║           gds/          std-cell GDS library                     ║
  ║       libs.tech/                                                 ║
  ║         magic/          sky130A.tech                             ║
  ║         klayout/        sky130A.lyt                              ║
  ║         netgen/         setup.tcl                                ║
  ╚══════════════════════════════════════════════════════════════════╝
                │                                │
                ▼                                ▼
  ╔══════════════════════════════════════════════════════════════════╗
  ║  DOCKER CONTAINER  efabless/openlane:2023.07.19-1               ║
  ║                                                                  ║
  ║  /project    → project files (read/write)                        ║
  ║  /pdks       → PDK (read-only)                                   ║
  ║                                                                  ║
  ║  /openlane/  → OpenLane installation (in image)                  ║
  ║     flow.tcl             main flow entry point                   ║
  ║     scripts/             per-stage Tcl scripts                   ║
  ║     designs/ ← symlink: /project/openlane/tt_um_inverter         ║
  ║                                                                  ║
  ║  Environment variables:                                          ║
  ║    PDK_ROOT=/pdks                                                ║
  ║    PDK=sky130A                                                   ║
  ║    STD_CELL_LIBRARY=sky130_fd_sc_hd                             ║
  ║    DESIGN_NAME=tt_um_inverter                                    ║
  ╚══════════════════════════════════════════════════════════════════╝
```

## docker run command (make flow)

```bash
docker run --rm \
  -v "$(pwd)":/project \
  -v "$HOME/.pdks":/pdks \
  -e PDK_ROOT=/pdks \
  -e PDK=sky130A \
  -e STD_CELL_LIBRARY=sky130_fd_sc_hd \
  efabless/openlane:2023.07.19-1 \
  bash -c '
    ln -sf /project/openlane/tt_um_inverter /openlane/designs/tt_um_inverter &&
    flow.tcl -design tt_um_inverter -tag run_$(date +%Y%m%d_%H%M%S) -overwrite
  '
```

## Per-stage docker run command

```bash
# Synthesis only
docker run --rm \
  -v "$(pwd)":/project -v "$HOME/.pdks":/pdks \
  -e PDK_ROOT=/pdks -e PDK=sky130A -e STD_CELL_LIBRARY=sky130_fd_sc_hd \
  efabless/openlane:2023.07.19-1 \
  bash -c 'ln -sf /project/openlane/tt_um_inverter /openlane/designs/tt_um_inverter &&
    flow.tcl -design tt_um_inverter -tag $TAG -to synthesis -overwrite'
```

## docker-compose services

```yaml
services:
  flow:   # full RTL-to-GDSII
    image: efabless/openlane:2023.07.19-1
    volumes: [".:project", "$PDK_ROOT:/pdks"]
    command: bash scripts/run_flow.sh full

  shell:  # interactive container
    image: efabless/openlane:2023.07.19-1
    stdin_open: true
    tty: true

  sim:    # RTL simulation (iverilog)
    image: hdlc/sim:latest
    command: bash -c 'cd /project && make sim'
```

## PDK installation (one-time)

```bash
# Install volare PDK manager
pip3 install volare

# Download and pin SKY130A at exact commit for reproducibility
volare enable \
  --pdk sky130 \
  --pdk-root $HOME/.pdks \
  0fe599b2afb6708d281543108caf8310912f54af

# Verify
ls $HOME/.pdks/sky130A/libs.ref/sky130_fd_sc_hd/lef/
# → sky130_fd_sc_hd.lef
```
