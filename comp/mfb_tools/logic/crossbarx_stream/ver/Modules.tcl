# Modules.tcl: Components include script
# Copyright (C) 2020 CESNET z. s. p. o.
# Author: Daniel Kriz <xkrizd01@vutbr.cz> 
#
# SPDX-License-Identifier: BSD-3-Clause

set SV_MFB_BASE   "$OFM_PATH/comp/mfb_tools/ver"
  
set COMPONENTS [list \
      [ list "SV_MFB"   $SV_MFB_BASE  "FULL"] \
]
set MOD "$MOD $ENTITY_BASE/tbench/dut_wrapper.vhd"
set MOD "$MOD $ENTITY_BASE/tbench/test_pkg.sv"
set MOD "$MOD $ENTITY_BASE/tbench/dut.sv"
set MOD "$MOD $ENTITY_BASE/tbench/test.sv"
