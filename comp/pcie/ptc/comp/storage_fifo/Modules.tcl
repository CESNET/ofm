# Modules.tcl: Components include script
# Copyright (C) 2018 CESNET
# Author(s): Jakub Cabal <cabal@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

# Set paths

# Paths to components
set FIFOXM_BASE        "$OFM_PATH/comp/base/fifo/fifox_multi"
set MFB_TOOLS_BASE     "$OFM_PATH/comp/mfb_tools"
set AUX_SIG_BASE       "$OFM_PATH/comp/mfb_tools/logic/auxiliary_signals"

# Packages
set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/math_pack.vhd"
set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/type_pack.vhd"
set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/dma_bus_pack.vhd"

# Components
set COMPONENTS [concat $COMPONENTS [list \
   [ list "FIFOX_MULTI"       $FIFOXM_BASE                    "FULL" ] \
   [ list "MVB_FIFOX"        "$OFM_PATH/comp/mvb_tools/storage/fifox"  "FULL" ] \
   [ list "MFB_FIFOX"        "$MFB_TOOLS_BASE/storage/fifox"  "FULL" ] \
   [ list "AUXILIARY_SIGNALS" $AUX_SIG_BASE                   "FULL" ] \
]]

# Source files for implemented component
set MOD "$MOD $ENTITY_BASE/ptc_storage_fifo.vhd"
