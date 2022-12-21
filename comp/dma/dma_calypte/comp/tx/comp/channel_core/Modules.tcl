# Modules.tcl: Components include script
# Copyright (C) 2022 CESNET
# Author(s): Vladislav Valek <xvalek14@vutbr.cz>
#

lappend PACKAGES "$OFM_PATH/comp/base/pkg/math_pack.vhd"

set MFB_DROPPER_BASE       "$OFM_PATH/comp/mfb_tools/flow/dropper"
set MFB_CUTTER_SIMPLE_BASE "$OFM_PATH/comp/mfb_tools/flow/cutter_simple"
set MFB_DATA_ALIGNER_BASE  "$ENTITY_BASE/comp/mfb_data_aligner"
set MFB_FIFOX_BASE         "$OFM_PATH/comp/mfb_tools/storage/fifox"
set MVB_FIFOX_BASE         "$OFM_PATH/comp/mvb_tools/storage/fifox"

lappend COMPONENTS [ list "MFB_DROPPER"       $MFB_DROPPER_BASE       "FULL"]
lappend COMPONENTS [ list "MFB_CUTTER_SIMPLE" $MFB_CUTTER_SIMPLE_BASE "FULL"]
lappend COMPONENTS [ list "MFB_DATA_ALIGNER"  $MFB_DATA_ALIGNER_BASE  "FULL"]
lappend COMPONENTS [ list "MFB_FIFOX"         $MFB_FIFOX_BASE         "FULL"]
lappend COMPONENTS [ list "MVB_FIFOX"         $MVB_FIFOX_BASE         "FULL"]

lappend MOD "$ENTITY_BASE/tx_dma_channel_core.vhd"
