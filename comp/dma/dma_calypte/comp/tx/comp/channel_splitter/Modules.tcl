# Modules.tcl: Components include script
# Copyright (C) 2022 CESNET
# Author(s): Vladislav Valek <xvalek14@vutbr.cz>
#

lappend PACKAGES "$OFM_PATH/comp/base/pkg/math_pack.vhd"
lappend PACKAGES "$OFM_PATH/comp/base/pkg/type_pack.vhd"
lappend PACKAGES "$OFM_PATH/comp/base/pkg/pcie_meta_pack.vhd"

set PCIE_CQ_HDR_DEPARSER_BASE    "$OFM_PATH/comp/pcie/others/hdr_gen"
set PCIE_BYTE_COUNT_BASE         "$OFM_PATH/comp/pcie/logic/byte_count"
set MFB_SPLITTER_SIMPLE_GEN_BASE "$OFM_PATH/comp/mfb_tools/flow/splitter_simple"

lappend COMPONENTS [ list "PCIE_CQ_HDR_DEPARSER"    $PCIE_CQ_HDR_DEPARSER_BASE    "FULL"]
lappend COMPONENTS [ list "PCIE_BYTE_COUNT"         $PCIE_BYTE_COUNT_BASE         "FULL"]
lappend COMPONENTS [ list "MFB_SPLITTER_SIMPLE_GEN" $MFB_SPLITTER_SIMPLE_GEN_BASE "FULL"]

lappend MOD "$ENTITY_BASE/tx_dma_channel_splitter.vhd"
