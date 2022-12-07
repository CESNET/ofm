# Modules.tcl: Components include script
# Copyright (C) 2022 CESNET
# Author(s): Vladislav Valek <xvalek14@vutbr.cz>
#


lappend PACKAGES \
    "$OFM_PATH/comp/base/pkg/math_pack.vhd" \
    "$OFM_PATH/comp/base/pkg/type_pack.vhd" \

set RX_SIDE_BASE "$ENTITY_BASE/comp/rx"

lappend COMPONENTS \
      [ list "RX_DMA_CALYPTE" $RX_SIDE_BASE "FULL"] \


lappend MOD \
    "$ENTITY_BASE/dma_calypte.vhd" \
    "$ENTITY_BASE/DevTree.tcl" \
