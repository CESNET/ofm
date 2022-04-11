# Modules.tcl: Modules.tcl script to compile all design
# Copyright (C) 2013 CESNET
# Author: Lukas Kekely <kekely@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause


# PACKAGES:
set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/math_pack.vhd"

# MODULES:
if { $ARCHGRP == "FULL" } { 
  set MOD "$MOD $ENTITY_BASE/streaming_debug_probe.vhd"
  set MOD "$MOD $ENTITY_BASE/streaming_debug_probe_n.vhd"
  set MOD "$MOD $OFM_PATH/comp/base/logic/dec1fn/dec1fn_enable.vhd"
  set MOD "$MOD $ENTITY_BASE/streaming_debug_master.vhd"
  set MOD "$MOD $ENTITY_BASE/DevTree.tcl"
}

if { $ARCHGRP == "PROBE" } {
  set MOD "$MOD $ENTITY_BASE/streaming_debug_probe.vhd"
  set MOD "$MOD $ENTITY_BASE/streaming_debug_probe_n.vhd"
}
