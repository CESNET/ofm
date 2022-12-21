# Modules.tcl: Components include script
# Copyright (C) 2022 CESNET
# Author(s): Vladislav Valek <xvalek14@vutbr.cz>
#

lappend PACKAGES "$OFM_PATH/comp/base/pkg/math_pack.vhd"
lappend PACKAGES "$OFM_PATH/comp/base/pkg/type_pack.vhd"
lappend PACKAGES "$OFM_PATH/comp/base/pkg/pcie_meta_pack.vhd"

set CHANNEL_CORE_BASE           "$ENTITY_BASE/comp/channel_core"
set CHANNEL_SPLITTER_BASE       "$ENTITY_BASE/comp/channel_splitter"
set SW_MANAGER_BASE             "$ENTITY_BASE/comp/software_manager"
set FIFOX_MULTI_BASE            "$OFM_PATH/comp/base/fifo/fifox_multi"
set GEN_MUX_BASE                "$OFM_PATH/comp/base/logic/mux"
set GEN_DEMUX_BASE              "$OFM_PATH/comp/base/logic/demux"
set MFB_MERGER_SIMPLE_GEN_BASE  "$OFM_PATH/comp/mfb_tools/flow/merger_simple"

lappend COMPONENTS [ list "TX_DMA_CHANNEL_CORE"     $CHANNEL_CORE_BASE          "FULL"]
lappend COMPONENTS [ list "TX_DMA_CHANNEL_SPLITTER" $CHANNEL_SPLITTER_BASE      "FULL"]
lappend COMPONENTS [ list "TX_DMA_SW_MANAGER"       $SW_MANAGER_BASE            "FULL"]
lappend COMPONENTS [ list "FIFOX_MULTI"             $FIFOX_MULTI_BASE           "FULL"]
lappend COMPONENTS [ list "GEN_MUX"                 $GEN_MUX_BASE               "FULL"]
lappend COMPONENTS [ list "GEN_DEMUX"               $GEN_DEMUX_BASE             "FULL"]
lappend COMPONENTS [ list "MFB_MERGER_SIMPLE_GEN"   $MFB_MERGER_SIMPLE_GEN_BASE "FULL"]


lappend MOD "$ENTITY_BASE/tx_dma_calypte.vhd"
