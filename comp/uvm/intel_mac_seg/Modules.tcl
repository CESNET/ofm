# Modules.tcl: Local include script
# Copyright (C) 2021 CESNET
# Author: Radek Iša <isa@cesnet.cz> 
# SPDX-License-Identifier: BSD-3-Clause

set COMPONENTS [ list \
    [list "COMMON"     "$OFM_PATH/comp/uvm/common"     "FULL"] \
]

set MOD "$MOD $ENTITY_BASE/interface.sv"
set MOD "$MOD $ENTITY_BASE/pkg.sv"

