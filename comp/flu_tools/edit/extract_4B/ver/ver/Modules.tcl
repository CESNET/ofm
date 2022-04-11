# Modules.tcl: Local include tcl script
# Copyright (C) 2013 CESNET
# Author: Lukas Kekely <kekely@cesnet.cz> 
#
# SPDX-License-Identifier: BSD-3-Clause

set SV_FLU_BASE   "$ENTITY_BASE/../../../../ver"
  
set COMPONENTS [list \
    [ list "SV_FLU_BASE"   $SV_FLU_BASE  "FULL"] \
]
set MOD "$MOD $ENTITY_BASE/tbench/test_pkg.sv"
set MOD "$MOD $ENTITY_BASE/tbench/dut.sv"
set MOD "$MOD $ENTITY_BASE/tbench/test.sv"  
