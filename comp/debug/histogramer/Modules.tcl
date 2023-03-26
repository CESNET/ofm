# Modules.tcl: Components include script
# Copyright (C) 2021 CESNET z. s. p. o.
# Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause


# Paths to components
set CNT_BASE            "$OFM_PATH/comp/base/logic/cnt"
set DP_BRAM_BASE        "$OFM_PATH/comp/base/mem/dp_bram"

# Packages
set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/math_pack.vhd"
set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/type_pack.vhd"

set COMPONENTS [concat $COMPONENTS [list \
    [ list "CNT"                $CNT_BASE               "FULL" ] \
    [ list "DP_BRAM"            $DP_BRAM_BASE           "FULL" ] \
]]

# Source files for implemented component
set MOD "$MOD $ENTITY_BASE/histogramer.vhd"
