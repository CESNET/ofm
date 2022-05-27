# Modules.tcl: Components include script
# Copyright (C) 2021 CESNET z. s. p. o.
# Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

# Paths to components
set EDGE_DETECT_BASE    "$OFM_PATH/comp/base/logic/edge_detect"
set DEC_BASE            "$OFM_PATH/comp/base/logic/dec1fn"
set OR_BASE             "$OFM_PATH/comp/base/logic/or"
set HISTOGRAMER_BASE    "$OFM_PATH/comp/debug/mem_tester/histogramer"

# Packages
set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/math_pack.vhd"
set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/type_pack.vhd"

set COMPONENTS [concat $COMPONENTS [list \
    [ list "DEC"                $DEC_BASE               "FULL" ] \
    [ list "EDGE_DETECT"        $EDGE_DETECT_BASE       "FULL" ] \
    [ list "OR"                 $OR_BASE                "FULL" ] \
    [ list "HISTOGRAMER"        $HISTOGRAMER_BASE       "FULL" ] \
]]

# Source files for implemented component
set MOD "$MOD $ENTITY_BASE/latency_meter.vhd"
set MOD "$MOD $ENTITY_BASE/amm_probe.vhd"

