# Modules.tcl: Local include script
# Copyright (C) 2021 CESNET
# Author: Radek Iša <isa@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

set COMPONENTS [ list \
    [list "COMMON"     "$OFM_PATH/comp/uvm/common"                    "FULL"] \
    [list "RESET"      "$OFM_PATH/comp/uvm/reset"                     "FULL"] \
    [list "MAC_SEG"    "$OFM_PATH/comp/uvm/byte_array_intel_mac_seg"  "FULL"] \
    [list "MFB"        "$OFM_PATH/comp/uvm/byte_array_mfb"            "FULL"] \
]


set MOD "$MOD $ENTITY_BASE/env/pkg.sv"
set MOD "$MOD $ENTITY_BASE/test/pkg.sv"
set MOD "$MOD $ENTITY_BASE/property.sv"

