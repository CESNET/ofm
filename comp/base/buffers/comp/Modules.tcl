# Modules.tcl: Local include tcl script
# Copyright (C) 2008 CESNET
# Author: Vozenilek Jan <xvozen00@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Base directories
set MATH_PACK_BASE "$OFM_PATH/comp/base/pkg"

if { $ARCHGRP == "FULL" } {
   set BASECOMP_BASE "$FIRMWARE_BASE/comp/base"
   set MEM_BASE      "$OFM_PATH/comp/base/mem"
   set SHREG_BASE    "$OFM_PATH/comp/base/shreg/"


# Source files for all components
   set PACKAGES  "$MATH_PACK_BASE/math_pack.vhd"

   set COMPONENTS [list \
      [list "MATH_PACK"   $MATH_PACK_BASE                    "MATH"] \
      [list "DP_BMEM"     $MEM_BASE/dp_bmem                  "FULL"] \
      [list "DP_DISTMEM"  $MEM_BASE/gen_lutram/compatibility "FULL"] \
      [list "SH_REG_BASE" $SHREG_BASE/sh_reg_base            "FULL"] \
      [list "SH_REG"      $SHREG_BASE/sh_reg                 "FULL"] \
   ]

   set MOD "$MOD $ENTITY_BASE/buf_mem.vhd"
   set MOD "$MOD $ENTITY_BASE/buf_status.vhd"
   set MOD "$MOD $ENTITY_BASE/buf_status_almost_full.vhd"
   set MOD "$MOD $ENTITY_BASE/rx_switch.vhd"
   set MOD "$MOD $ENTITY_BASE/tx_switch.vhd"
}
