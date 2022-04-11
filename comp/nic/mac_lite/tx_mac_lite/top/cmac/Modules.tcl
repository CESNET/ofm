# Modules.tcl: Components include script
# Copyright (C) 2020 CESNET z. s. p. o.
# Author(s): Jakub Cabal <cabal@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

# Set paths

set PKG_BASE          "$OFM_PATH/comp/base/pkg"
set TX_MAC_LITE_BASE  "$OFM_PATH/comp/nic/mac_lite/tx_mac_lite"
set CMAC_REBASE_BASE  "$COMP_BASE/nic/cmac/obuf/comp/rebase"

set PACKAGES "$PACKAGES $PKG_BASE/math_pack.vhd"
set PACKAGES "$PACKAGES $PKG_BASE/type_pack.vhd"

set COMPONENTS [list \
    [list "CMAC_REBASE"  $CMAC_REBASE_BASE  "FULL" ] \
    [list "TX_MAC_LITE"  $TX_MAC_LITE_BASE  "NO_CRC" ] \
]

# Source files for implemented component
set MOD "$MOD $ENTITY_BASE/tx_mac_lite_cmac.vhd"
