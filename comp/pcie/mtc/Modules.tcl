# Modules.tcl: Components include script
# Copyright (C) 2019 CESNET z. s. p. o.
# Author(s): Jakub Cabal <cabal@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

# Set paths

# Paths to components
set LOCAL_COMP           "$ENTITY_BASE/comp"
set SDP_BRAM_BASE        "$OFM_PATH/comp/base/mem/sdp_bram"
set MI_PIPE_BASE         "$OFM_PATH/comp/mi_tools/pipe"
set PIPE_BASE            "$OFM_PATH/comp/base/misc/pipe"
set MFB_PIPE_BASE        "$OFM_PATH/comp/mfb_tools/flow/pipe"
set MFB_TRANSFORMER_BASE "$OFM_PATH/comp/mfb_tools/flow/transformer"

# Packages
set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/math_pack.vhd"
set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/type_pack.vhd"

# list of subcomponents
set COMPONENTS [list \
    [ list "SDP_BRAM"        $SDP_BRAM_BASE        "FULL" ]  \
    [ list "PIPE"            $PIPE_BASE            "FULL" ]  \
    [ list "MI_PIPE"         $MI_PIPE_BASE         "FULL" ]  \
    [ list "MFB_PIPE"        $MFB_PIPE_BASE        "FULL" ]  \
    [ list "MFB_TRANSFORMER" $MFB_TRANSFORMER_BASE "FULL" ]  \
]

# entity and architecture
set MOD "$MOD $ENTITY_BASE/mtc.vhd"
