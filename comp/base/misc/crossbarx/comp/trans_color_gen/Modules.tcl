# Modules.tcl: Components include script
# Copyright (C) 2019 CESNET z. s. p. o.
# Author(s): Jakub Cabal <cabal@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

# Set paths
global FIRMWARE_BASE
set PKG_BASE     "$OFM_PATH/comp/base/pkg"

# Packages
set PACKAGES "$PACKAGES $PKG_BASE/math_pack.vhd"
set PACKAGES "$PACKAGES $PKG_BASE/type_pack.vhd"

set COMPONENTS [list \
    [ list "SHREG"       "$OFM_PATH/comp/base/shreg/sh_reg_base"       "FULL" ] \
]

# Source files for implemented component
set MOD "$MOD $ENTITY_BASE/trans_color_gen.vhd"
