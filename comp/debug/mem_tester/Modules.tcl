# Modules.tcl: Components include script
# Copyright (C) 2021 CESNET z. s. p. o.
# Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause


# Paths to components
set LFSR_RND_GEN_BASE   "$OFM_PATH/comp/base/logic/lfsr_simple_random_gen"
set MI_ASYNC_BASE       "$OFM_PATH/comp/mi_tools/async"
set MI_PIPE_BASE        "$OFM_PATH/comp/mi_tools/pipe"
set CMP_BASE            "$OFM_PATH/comp/base/logic/cmp"
set MUX_BASE            "$OFM_PATH/comp/base/logic/mux"
set EDGE_DETECT_BASE    "$OFM_PATH/comp/base/logic/edge_detect"
set CNT_BASE            "$OFM_PATH/comp/base/logic/cnt"
set MI_SPLITER_BASE     "$OFM_PATH/comp/mi_tools/splitter_plus_gen"

set AMM_GEN_BASE        "$ENTITY_BASE/amm_gen"
set AMM_PROBE_BASE      "$ENTITY_BASE/amm_probe"
set AMM_MUX_BASE        "$ENTITY_BASE/amm_mux"
set EMIF_REFRESH_BASE   "$ENTITY_BASE/emif_refresh"

# Packages
set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/math_pack.vhd"
set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/type_pack.vhd"

set COMPONENTS [concat $COMPONENTS [list \
    [ list "LFSR_RANDOM_GEN"    $LFSR_RND_GEN_BASE      "FULL" ] \
    [ list "MI_ASYNC"           $MI_ASYNC_BASE          "FULL" ] \
    [ list "MI_PIPE"            $MI_PIPE_BASE           "FULL" ] \
    [ list "CMP"                $CMP_BASE               "FULL" ] \
    [ list "MUX"                $MUX_BASE               "FULL" ] \
    [ list "EDGE_DETECT"        $EDGE_DETECT_BASE       "FULL" ] \
    [ list "CNT"                $CNT_BASE               "FULL" ] \
    [ list "MI_SPLITTER"        $MI_SPLITER_BASE        "FULL" ] \
    [ list "AMM_GEN"            $AMM_GEN_BASE           "FULL" ] \
    [ list "AMM_PROBE"          $AMM_PROBE_BASE         "FULL" ] \
    [ list "AMM_MUX"            $AMM_MUX_BASE           "FULL" ] \
    [ list "EMIF_REFRESH"       $EMIF_REFRESH_BASE      "FULL" ] \
]]

# Source files for implemented component
set MOD "$MOD $ENTITY_BASE/mem_tester_mi.vhd"
set MOD "$MOD $ENTITY_BASE/mem_tester.vhd"

# Component DevTree
set MOD "$MOD $ENTITY_BASE/DevTree.tcl"
