# Modules.tcl: Components include script
# Copyright (C) 2020 CESNET z. s. p. o.
# Author(s): Jakub Cabal <cabal@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

# Set paths

# Paths to components
set PKG_BASE    "$OFM_PATH/comp/base/pkg"
#set FIFOXM_BASE "$COMP_BASE/base/fifo/fifox_multi"

# Packages
set PACKAGES "$PACKAGES $PKG_BASE/math_pack.vhd"
set PACKAGES "$PACKAGES $PKG_BASE/type_pack.vhd"

# Components
#set COMPONENTS [concat $COMPONENTS [list \
#   [ list "FIFOXM" $FIFOXM_BASE "FULL" ] \
#]]

# Source files for implemented component
set MOD "$MOD $ENTITY_BASE/mvb_channel_router.vhd"
set MOD "$MOD $ENTITY_BASE/mvb_channel_router_mi.vhd"
