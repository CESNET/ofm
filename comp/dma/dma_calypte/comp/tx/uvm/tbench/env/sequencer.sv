//-- sequencer.sv: Virtual sequencer 
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

class sequencer#(USR_REGIONS, USR_REGION_SIZE, USR_BLOCK_SIZE, USR_ITEM_WIDTH, CQ_ITEM_WIDTH, CHANNELS, PKT_SIZE_MAX) extends uvm_sequencer;
    `uvm_component_param_utils(uvm_dma_ll::sequencer#(USR_REGIONS, USR_REGION_SIZE, USR_BLOCK_SIZE, USR_ITEM_WIDTH, CQ_ITEM_WIDTH, CHANNELS, PKT_SIZE_MAX))

    localparam USER_META_WIDTH = 24 + $clog2(PKT_SIZE_MAX+1) + $clog2(CHANNELS);

    uvm_reset::sequencer                                                                                m_reset;
    uvm_dma_ll_rx::sequencer#(CQ_ITEM_WIDTH, CHANNELS)                                                  m_packet;
    uvm_mfb::sequencer #(USR_REGIONS, USR_REGION_SIZE, USR_BLOCK_SIZE, USR_ITEM_WIDTH, USER_META_WIDTH) m_pcie[CHANNELS];
    uvm_dma_ll::regmodel #(CHANNELS)                                                                    m_regmodel;

    function new(string name = "virt_sequencer", uvm_component parent);
        super.new(name, parent);
    endfunction

endclass
