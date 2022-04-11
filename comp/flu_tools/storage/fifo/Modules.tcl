# Modules.tcl: Local include Modules tcl script
# Copyright (C) 2012 CESNET
# Author: Lukas Kekely <kekely@cesnet.cz> 
#
# SPDX-License-Identifier: BSD-3-Clause

set FIFO_BASE        "$OFM_PATH/comp/base/fifo/fifo"
set MATH_PKG_BASE    "$OFM_PATH/comp/base/pkg"
set FIFO_BRAM_BASE   "$OFM_PATH/comp/base/fifo/fifo_bram"

# Entities
set MOD "$MOD $ENTITY_BASE/fifo_ent.vhd"
set MOD "$MOD $ENTITY_BASE/fifo_arch.vhd"
set MOD "$MOD $ENTITY_BASE/fifo_plus_ent.vhd"
set MOD "$MOD $ENTITY_BASE/fifo_plus_arch.vhd"
 
# Subcomponents
set COMPONENTS [list [list "FIFO_S"      $FIFO_BASE      "BEHAV"] \
                     [list "PKG" $MATH_PKG_BASE "MATH"] \
                     [list "FIFO_BRAM_S" $FIFO_BRAM_BASE "FULL"]]
