# Modules.tcl: Components include script
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Daniel Kondys <kondys@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause


# Set paths
set PKG_BASE           "$OFM_PATH/comp/base/pkg"
set COMP_BASE          "$ENTITY_BASE/comp"
set FIFO_BASE          "$OFM_PATH/comp/base/fifo"

# Packages
lappend PACKAGES "$PKG_BASE/math_pack.vhd"
lappend PACKAGES "$PKG_BASE/type_pack.vhd"

lappend COMPONENTS [ list "CHSUM_DATA_EXT"      $COMP_BASE/chsum_data_ext      "FULL" ]
lappend COMPONENTS [ list "CHSUM_REGIONAL"      $COMP_BASE/chsum_regional      "FULL" ]
lappend COMPONENTS [ list "CHSUM_FINALIZER"     $COMP_BASE/chsum_finalizer     "FULL" ]
lappend COMPONENTS [ list "FIFOX_MULTI"         $FIFO_BASE/fifox_multi         "FULL" ]

# Source files for implemented component
lappend MOD "$ENTITY_BASE/checksum_calculator.vhd"
# lappend MOD "$ENTITY_BASE/DevTree.tcl"

