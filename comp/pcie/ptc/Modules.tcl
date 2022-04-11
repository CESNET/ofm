# Modules.tcl: Local include Modules tcl script
# Copyright (C) 2013 CESNET z. s. p. o.
# Author: Jiri Matousek <xmatou06@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

# Set paths

set PKG_BASE            "$OFM_PATH/comp/base/pkg"

set MVB_TOOLS_BASE     "$OFM_PATH/comp/mvb_tools"
set MFB_TOOLS_BASE     "$OFM_PATH/comp/mfb_tools"
set SUBCOMP_BASE       "$ENTITY_BASE/comp"

set PACKAGES "$PACKAGES $PKG_BASE/math_pack.vhd"
set PACKAGES "$PACKAGES $PKG_BASE/type_pack.vhd"
set PACKAGES "$PACKAGES $PKG_BASE/dma_bus_pack.vhd"

# list of sub-components
set COMPONENTS [ list \
   [ list "MVB_ASFIFOX"         "$MVB_TOOLS_BASE/storage/asfifox"            "FULL" ] \
   [ list "MVB_SHAKEDOWN"       "$MVB_TOOLS_BASE/flow/shakedown"             "FULL" ] \
   [ list "MFB_ASFIFOX"         "$MFB_TOOLS_BASE/storage/asfifox"            "FULL" ] \
   [ list "MFB_MERGER"          "$MFB_TOOLS_BASE/flow/merger"                "FULL" ] \
   [ list "MFB_SPLITTER"        "$MFB_TOOLS_BASE/flow/splitter"              "FULL" ] \
   [ list "MFB_TRANSFORMER"     "$MFB_TOOLS_BASE/flow/transformer"           "FULL" ] \
   [ list "MFB_ASFIFO_512to256" "$SUBCOMP_BASE/mfb_asfifo_512to256"          "FULL" ] \
   [ list "MFB_ASFIFO_256to512" "$SUBCOMP_BASE/mfb_asfifo_256to512"          "FULL" ] \
   [ list "SUM_ONE"             "$OFM_PATH/comp/base/logic/sum_one"              "FULL" ] \
   [ list "PIPE_TREE_ADDER"     "$OFM_PATH/comp/base/logic/pipe_tree_adder"      "FULL" ] \
   [ list "ASFIFOX"             "$OFM_PATH/comp/base/fifo/asfifox"               "FULL" ] \
   [ list "DMA2PCIE"            "$SUBCOMP_BASE/dma2pcie_hdr_transform"       "FULL" ] \
   [ list "CODAPA_CHECKER"      "$SUBCOMP_BASE/codapa_checker"               "FULL" ] \
   [ list "HDR_DATA_MERGE"      "$SUBCOMP_BASE/hdr_data_merge"               "FULL" ] \
   [ list "MFB2PCIE_AXI"        "$SUBCOMP_BASE/mfb2pcie_axi"                 "FULL" ] \
   [ list "TAG_MANAGER"         "$SUBCOMP_BASE/tag_manager"                  "FULL" ] \
   [ list "PCIE_AXI2MFB"        "$SUBCOMP_BASE/pcie_axi2mfb"                 "FULL" ] \
   [ list "MFB_FIFO"            "$MFB_TOOLS_BASE/storage/fifo_bram_xilinx"   "FULL" ] \
   [ list "MFB_GET_ITEMS"       "$MFB_TOOLS_BASE/logic/get_items"            "FULL" ] \
   [ list "PCIE2DMA"            "$SUBCOMP_BASE/pcie2dma_hdr_transform"       "FULL" ] \
   [ list "FRAME_ERASER"        "$SUBCOMP_BASE/frame_eraser_upto96bits"      "FULL" ] \
   [ list "STORAGE_FIFO"        "$SUBCOMP_BASE/storage_fifo"                 "FULL" ] \
   [ list "MVB_PIPE"            "$MVB_TOOLS_BASE/flow/pipe"                  "FULL" ] \
   [ list "MFB_PIPE"            "$MFB_TOOLS_BASE/flow/pipe"                  "FULL" ] \
   [ list "CUTTER"              "$MFB_TOOLS_BASE/flow/cutter_simple"         "FULL" ] \
]

# entity and architecture
set MOD "$MOD $ENTITY_BASE/ptc_ent.vhd"
set MOD "$MOD $ENTITY_BASE/ptc_full.vhd"
