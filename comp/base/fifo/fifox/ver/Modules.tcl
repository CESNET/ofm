# Modules.tcl: Components include script
# Copyright (C) 2016 CESNET
# Author(s):      Lukas Kekely <kekely@cesnet.cz>
#                 Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>                 
#
# SPDX-License-Identifier: BSD-3-Clause


# Set paths

set SV_MVB_BASE   "$OFM_PATH/comp/mvb_tools/ver"
  
set COMPONENTS [list \
      [ list "SV_MVB"   $SV_MVB_BASE  "FULL"] \
]

set MOD "$MOD $ENTITY_BASE/tbench/interfaces/fifox_in_ifc.sv"
set MOD "$MOD $ENTITY_BASE/tbench/interfaces/fifox_out_ifc.sv"
set MOD "$MOD $ENTITY_BASE/tbench/cov/sv_fifox_cov_pkg.sv"
set MOD "$MOD $ENTITY_BASE/tbench/test_pkg.sv"
set MOD "$MOD $ENTITY_BASE/tbench/dut.sv"
set MOD "$MOD $ENTITY_BASE/tbench/test.sv"
