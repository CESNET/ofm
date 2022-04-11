# Modules.tcl: Local include script
# Copyright (C) 2021 CESNET
# Author: Radek Iša <isa@cesnet.cz>
# SPDX-License-Identifier: BSD-3-Clause

set COMPONENTS [ list \
    [list "RESET"        "$OFM_PATH/comp/uvm/reset"          "FULL"] \
    [list "COMMON"       "$OFM_PATH/comp/uvm/common"         "FULL"] \
    [list "MAC_SEG"      "$OFM_PATH/comp/uvm/intel_mac_seg"  "FULL"] \
    [list "BYTE_ARRAY"   "$OFM_PATH/comp/uvm/byte_array"     "FULL"] \
    [list "LOGIC_VECTOR" "$OFM_PATH/comp/uvm/logic_vector"   "FULL"] \
]


set MOD "$MOD $ENTITY_BASE/pkg.sv"

