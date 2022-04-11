# Modules.tcl: Local include Modules tcl script
# Copyright (C) 2013 CESNET z. s. p. o.
# Author: Jiri Matousek <xmatou06@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause


set PKG_BASE            "$OFM_PATH/comp/base/pkg"

set PACKAGES "$PACKAGES $PKG_BASE/math_pack.vhd"
set PACKAGES "$PACKAGES $PKG_BASE/type_pack.vhd"
set PACKAGES "$PACKAGES $PKG_BASE/dma_bus_pack.vhd"

# list of sub-components
set COMPONENTS [ list \
]

# entity and architecture
set MOD "$MOD $ENTITY_BASE/ptc_dma2pcie_hdr_transform_ent.vhd"
set MOD "$MOD $ENTITY_BASE/ptc_dma2pcie_hdr_transform_full.vhd"
