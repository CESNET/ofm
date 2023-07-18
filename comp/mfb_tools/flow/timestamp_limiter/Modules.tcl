# Modules.tcl: Components include script
# Copyright (C) 2023 CESNET z. s. p. o.
# Author(s): Daniel Kondys <kondys@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

# Paths to components
set MFB_FLOW_BASE    "$OFM_PATH/comp/mfb_tools/flow"

# Packages
lappend PACKAGES "$OFM_PATH/comp/base/pkg/math_pack.vhd"
lappend PACKAGES "$OFM_PATH/comp/base/pkg/type_pack.vhd"

lappend COMPONENTS [ list "MFB_PACKET_DELAYER"    "$MFB_FLOW_BASE/packet_delayer"    "FULL" ]
lappend COMPONENTS [ list "MFB_MERGER_GEN"        "$MFB_FLOW_BASE/merger_simple"     "FULL" ]
lappend COMPONENTS [ list "MFB_SPLITTER_GEN"      "$MFB_FLOW_BASE/splitter_simple"   "FULL" ]

# Source files for implemented component
lappend MOD "$ENTITY_BASE/mfb_timestamp_limiter.vhd"
lappend MOD "$ENTITY_BASE/DevTree.tcl"
