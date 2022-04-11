# Modules.tcl: Components include script
# Copyright (C) 2020 CESNET
# Author(s): Daniel Kondys <xkondy00@vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

# Set paths
global FIRMWARE_BASE

set COMP_BASE "$FIRMWARE_BASE/comp"
set PKG_BASE  "$OFM_PATH/comp/base/pkg"
set PKG_BASE2 "$COMP_BASE/base/pkg"

set PACKAGES "$PACKAGES $PKG_BASE/math_pack.vhd"
set PACKAGES "$PACKAGES $PKG_BASE/type_pack.vhd"

# Packages only for the simulation
set PACKAGES "$PACKAGES $PKG_BASE/dma_bus_pack.vhd"
set PACKAGES "$PACKAGES $OFM_PATH/comp/ver/vhdl_ver_tools/basics/basics_test_pkg.vhd"

set MOD "$MOD $ENTITY_BASE/dsp_counter_agilex_atom.vhd"
