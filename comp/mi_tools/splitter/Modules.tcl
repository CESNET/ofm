# Modules.tcl: Components include script
# Copyright (C) 2021 CESNET
# Author(s): Jan Kubalek <kubalek@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

# Set paths
global FIRMWARE_BASE

set PKG_BASE "$OFM_PATH/comp/base/pkg"

set PACKAGES "$PACKAGES $PKG_BASE/math_pack.vhd"
set PACKAGES "$PACKAGES $PKG_BASE/type_pack.vhd"

set COMPONENTS [list \
    [list "MI_SPLITTER_PLUS_GEN" "$OFM_PATH/comp/mi_tools/splitter_plus_gen" "FULL" ] \
]

set MOD "$MOD $ENTITY_BASE/mi_splitter.vhd"
