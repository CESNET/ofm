# Modules.tcl: Components include script
# Copyright (C) 2017 CESNET z. s. p. o.
# Author(s): Jakub Cabal <xcabal05@stud.feec.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

set SV_MFB_BASE   "$ENTITY_BASE/../../../ver"
  
set COMPONENTS [list \
      [ list "SV_MFB"   $SV_MFB_BASE  "FULL"] \
]
set MOD "$MOD $ENTITY_BASE/tbench/test_pkg.sv"
set MOD "$MOD $ENTITY_BASE/tbench/dut.sv"
set MOD "$MOD $ENTITY_BASE/tbench/test.sv"
