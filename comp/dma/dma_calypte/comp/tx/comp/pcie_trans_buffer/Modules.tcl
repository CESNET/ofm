# Modules.tcl: Components include script
# Copyright (C) 2023 CESNET z. s. p. o.
# Author(s): Vladislav Valek <valekv@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

# Set paths
set PKG_BASE  "$OFM_PATH/comp/base/pkg"

# Packages
lappend PACKAGES "$PKG_BASE/math_pack.vhd"
lappend PACKAGES "$PKG_BASE/type_pack.vhd"

# Components
lappend COMPONENTS [ list "SDP_BRAM"           "$OFM_PATH/comp/base/mem/sdp_bram"    "FULL" ]
lappend COMPONENTS [ list "GEN_LUTRAM"         "$OFM_PATH/comp/base/mem/gen_lutram"    "FULL" ]
lappend COMPONENTS [ list "BARREL_SHIFTER_GEN" "$OFM_PATH/comp/base/logic/barrel_shifter" "FULL" ]

# Source files for implemented component
lappend MOD "$ENTITY_BASE/tx_dma_pcie_trans_buffer.vhd"
