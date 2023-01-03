# Modules.tcl: Components include script
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Daniel Kondys <kondys@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause


# Set paths
set PKG_BASE           "$OFM_PATH/comp/base/pkg"
set LOGIC_BASE         "$OFM_PATH/comp/base/logic/"
set MVB_TOOLS_BASE     "$OFM_PATH/comp/mvb_tools"

# Packages
lappend PACKAGES "$PKG_BASE/math_pack.vhd"
lappend PACKAGES "$PKG_BASE/type_pack.vhd"

# Source files for implemented component
lappend MOD "$ENTITY_BASE/xof_to_item_vld_conv.vhd"
lappend MOD "$ENTITY_BASE/chsum_data_ext.vhd"
# lappend MOD "$ENTITY_BASE/DevTree.tcl"

lappend COMPONENTS [ list "MVB_AGGREGATE_LAST_VLD" "$MVB_TOOLS_BASE/aggregate/last_vld" "FULL" ]
lappend COMPONENTS [ list "BIN2HOT"                "$LOGIC_BASE/bin2hot"                "FULL" ]
