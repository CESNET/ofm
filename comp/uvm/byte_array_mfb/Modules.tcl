# Modules.tcl: Local include script
# Copyright (C) 2021 CESNET
# Author: Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>
# SPDX-License-Identifier: BSD-3-Clause

set COMPONENTS [ list \
    [list "RESET"           "$OFM_PATH/comp/uvm/reset"          "FULL"]\
    [list "BYTE_ARRAY"      "$OFM_PATH/comp/uvm/byte_array"     "FULL"]\
    [list "LOGIC_VECTOR"    "$OFM_PATH/comp/uvm/logic_vector"   "FULL"]\
    [list "MFB"             "$OFM_PATH/comp/uvm/mfb"            "FULL"]\
]

set MOD "$MOD $ENTITY_BASE/pkg.sv"
