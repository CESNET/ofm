# Modules.tcl: Components include script
# Copyright (C) 2021 CESNET z. s. p. o.
# Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz> 
#
# SPDX-License-Identifier: BSD-3-Clause

# Set paths
set SV_MVB_UVM_BASE   "$OFM_PATH/comp/uvm/mvb"

set COMPONENTS [list \
      [ list "SV_MVB_UVM_BASE"   $SV_MVB_UVM_BASE "FULL"] \
]

set MOD "$MOD $ENTITY_BASE/tbench/env/pkg.sv"
set MOD "$MOD $ENTITY_BASE/tbench/tests/pkg.sv"

set MOD "$MOD $ENTITY_BASE/tbench/dut.sv"
set MOD "$MOD $ENTITY_BASE/tbench/testbench.sv"
