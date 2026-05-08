# ============================================================
# Dockerfile — tt_um_inverter OpenLane / SKY130HD build env
#
# Base: efabless/openlane 2023.07.19-1
#   • OpenLane 1.x flow scripts at /openlane
#   • yosys, OpenROAD, Magic, KLayout, Netgen, OpenSTA pre-installed
#   • PDK NOT included — mount PDK_ROOT from the host (see docker-compose.yml)
#
# Build:
#   docker build -t tt-inverter-flow .
#
# Run (standalone, PDK_ROOT must be exported on host):
#   docker run --rm -it \
#     -v "$(pwd)":/project \
#     -v "${PDK_ROOT}":/pdks \
#     -e PDK_ROOT=/pdks \
#     tt-inverter-flow
# ============================================================
FROM efabless/openlane:2023.07.19-1

LABEL org.opencontainers.image.title="tt_um_inverter OpenLane flow"
LABEL org.opencontainers.image.description="TinyTapeout CMOS inverter RTL-to-GDSII"

# ── Environment variables ─────────────────────────────────────
ENV OPENLANE_ROOT=/openlane
ENV PDK_ROOT=/pdks
ENV PDK=sky130A
ENV STD_CELL_LIBRARY=sky130_fd_sc_hd
ENV PROJECT_ROOT=/project
ENV DESIGN_NAME=tt_um_inverter

# ── Project mount point placeholder ──────────────────────────
# The /project directory is populated at runtime via -v mount.
# Nothing is COPY'd here so the image remains PDK-independent.
WORKDIR /openlane

# ── Helper: link project design into OpenLane designs tree ───
# Called by run_flow.sh; idempotent if link already exists
RUN echo '#!/bin/bash\n\
set -euo pipefail\n\
DESIGN=${DESIGN_NAME:-tt_um_inverter}\n\
ln -sf "${PROJECT_ROOT}/openlane/${DESIGN}" "${OPENLANE_ROOT}/designs/${DESIGN}"\n\
exec "$@"\n' > /usr/local/bin/link-design && chmod +x /usr/local/bin/link-design

ENTRYPOINT ["/usr/local/bin/link-design"]
CMD ["bash"]
