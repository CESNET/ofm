// sequencer.sv: Virtual sequencer
// Copyright (C) 2024 CESNET z. s. p. o.
// Author(s): David Beneš <xbenes52@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


class virt_sequencer#(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MVB_ITEM_WIDTH, USR_RX_PKT_SIZE_MAX, RX_CHANNELS, HDR_META_WIDTH) extends uvm_sequencer;
    `uvm_component_param_utils(uvm_framepacker::virt_sequencer#(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MVB_ITEM_WIDTH, USR_RX_PKT_SIZE_MAX, RX_CHANNELS, HDR_META_WIDTH))

    uvm_reset::sequencer                                                                    m_reset;
    uvm_logic_vector_array::sequencer#(MFB_ITEM_WIDTH)                                      m_mfb_data_sqr;
    uvm_mfb::sequencer #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, 0)   m_mfb_tx_sqr;
    uvm_mvb::sequencer #(MFB_REGIONS, MVB_ITEM_WIDTH)                                       m_mvb_tx_sqr;
    uvm_meta::sequencer #(USR_RX_PKT_SIZE_MAX, RX_CHANNELS, HDR_META_WIDTH)                 m_info;

    function new(string name = "virt_sequencer", uvm_component parent);
        super.new(name, parent);
    endfunction

endclass
