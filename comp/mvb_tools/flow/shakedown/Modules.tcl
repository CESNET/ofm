# Modules.tcl: Components include script
# Copyright (C) 2019 CESNET z. s. p. o.
# Author(s): Jakub Cabal <cabal@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

# Paths to components
set PKG_BASE       "$OFM_PATH/comp/base/pkg"
set SHAKEDOWN_BASE "$OFM_PATH/comp/mvb_tools/flow/merge_n_to_m"
set BARREL_SH_BASE "$OFM_PATH/comp/base/logic/barrel_shifter"

# Packages
set PACKAGES "$PACKAGES $PKG_BASE/math_pack.vhd"
set PACKAGES "$PACKAGES $PKG_BASE/type_pack.vhd"

# Components
set COMPONENTS [concat $COMPONENTS [list \
   [ list "SHAKEDOWN" $SHAKEDOWN_BASE "FULL" ] \
   [ list "BARREL_SH" $BARREL_SH_BASE "FULL" ] \
]]

# Source files for implemented component
set MOD "$MOD $ENTITY_BASE/mvb_shakedown.vhd"
