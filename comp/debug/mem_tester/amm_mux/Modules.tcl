# Modules.tcl: Components include script
# Copyright (C) 2021 CESNET z. s. p. o.
# Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause


# Paths to components
set MI_PIPE_BASE        "$OFM_PATH/comp/mi_tools/pipe"
set MUX_BASE            "$OFM_PATH/comp/base/logic/mux"

# Packages
set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/math_pack.vhd"
set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/type_pack.vhd"

set COMPONENTS [concat $COMPONENTS [list \
    [ list "MI_PIPE"            $MI_PIPE_BASE           "FULL" ] \
    [ list "MUX"                $MUX_BASE               "FULL" ] \
]]

# Source files for implemented component
set MOD "$MOD $ENTITY_BASE/amm_mux.vhd"