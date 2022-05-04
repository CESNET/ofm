# Modules.tcl: Local include Modules tcl script
# Copyright (C) 2013 CESNET z. s. p. o.
# Author: Jiri Matousek <xmatou06@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

set FIFOXM_BASE         "$OFM_PATH/comp/base/fifo/fifox_multi" 
set FIFOX_BASE          "$OFM_PATH/comp/base/fifo/fifox" 
set SPLITTER_BASE       "$OFM_PATH/comp/mfb_tools/flow/splitter_simple" 

set PKG_BASE            "$OFM_PATH/comp/base/pkg"

lappend PACKAGES "$PKG_BASE/math_pack.vhd"
lappend PACKAGES "$PKG_BASE/type_pack.vhd"
lappend PACKAGES "$PKG_BASE/dma_bus_pack.vhd"

# list of sub-components
set COMPONENTS [ list \
   [ list "FIFOX_MULTI"   $FIFOXM_BASE         "FULL" ] \
   [ list "FIFOX"         $FIFOX_BASE          "FULL" ] \
   [ list "SPLITTER"      $SPLITTER_BASE       "FULL" ] \
]

# entity and architecture
lappend MOD "$ENTITY_BASE/mfb_splitter.vhd"
lappend MOD "$ENTITY_BASE/mfb_splitter_gen.vhd"
