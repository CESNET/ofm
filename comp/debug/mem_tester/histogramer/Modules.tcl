# Modules.tcl: Components include script
# Copyright (C) 2021 CESNET z. s. p. o.
# Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

# Paths to components
set LAST_ONE_BASE           "$OFM_PATH/comp/base/logic/last_one"
set OR_BASE                 "$OFM_PATH/comp/base/logic/or"
set DEC1F_BASE              "$OFM_PATH/comp/base/logic/dec1fn"

# Packages
set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/math_pack.vhd"
set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/type_pack.vhd"

set COMPONENTS [concat $COMPONENTS [list \
    [ list "LAST_ONE"   $LAST_ONE_BASE  "FULL" ] \
    [ list "OR"         $OR_BASE        "FULL" ] \
    [ list "DEC1FN"     $DEC1F_BASE     "FULL" ] \
]]

# Source files for implemented component
set MOD "$MOD $ENTITY_BASE/histogramer_types.vhd"
set MOD "$MOD $ENTITY_BASE/histogramer.vhd"
