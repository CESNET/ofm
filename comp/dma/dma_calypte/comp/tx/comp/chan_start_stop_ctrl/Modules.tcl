# Modules.tcl: Components include script
# Copyright (C) 2023 CESNET
# Author(s): Vladislav Valek <xvalek14@vutbr.cz>
#

lappend PACKAGES "$OFM_PATH/comp/base/pkg/math_pack.vhd"

set MFB_DROPPER_BASE       "$OFM_PATH/comp/mfb_tools/flow/dropper"

lappend COMPONENTS [ list "MFB_DROPPER"       $MFB_DROPPER_BASE       "FULL"]

lappend MOD "$ENTITY_BASE/tx_dma_chan_start_stop_ctrl.vhd"
