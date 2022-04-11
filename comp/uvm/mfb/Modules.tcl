# Modules.tcl: Local include script
# Copyright (C) 2021 CESNET
# Author: Tomáš Beneš <xbenes55@stud.fit.vutbr.cz> 
# SPDX-License-Identifier: BSD-3-Clause

set COMPONENTS [ list \
    [list "RESET"        "$OFM_PATH/comp/uvm/reset"          "FULL"] \
    [list "COMMON"       "$OFM_PATH/comp/uvm/common"         "FULL"] \
]


set MOD "$MOD $ENTITY_BASE/interface.sv"
set MOD "$MOD $ENTITY_BASE/property.sv"
set MOD "$MOD $ENTITY_BASE/pkg.sv"
