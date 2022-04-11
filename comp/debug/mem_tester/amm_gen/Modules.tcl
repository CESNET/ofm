# Modules.tcl: Components include script
# Copyright (C) 2021 CESNET z. s. p. o.
# Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause


# Paths to components
set DP_BRAM_BASE        "$OFM_PATH/comp/base/mem/dp_bram"
set EDGE_DETECT_BASE    "$OFM_PATH/comp/base/logic/edge_detect"

# Packages
set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/math_pack.vhd"
set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/type_pack.vhd"

set COMPONENTS [concat $COMPONENTS [list \
    [ list "DP_BRAM"            $DP_BRAM_BASE           "FULL" ] \
    [ list "EDGE_DETECT"        $EDGE_DETECT_BASE       "FULL" ] \
]]

# Source files for implemented component
set MOD "$MOD $ENTITY_BASE/amm_gen.vhd"
