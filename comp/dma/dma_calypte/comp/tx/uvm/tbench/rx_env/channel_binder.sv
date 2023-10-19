//-- channel_binder.sv
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

class channel_binder #(CHANNELS, ITEM_WIDTH) extends uvm_component;
    `uvm_component_param_utils(uvm_dma_ll_rx::channel_binder #(CHANNELS, ITEM_WIDTH))

    mailbox#(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH))                      data_in_export[CHANNELS];
    mailbox#(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)) meta_in_export[CHANNELS];
    mailbox#(uvm_logic_vector::sequence_item#(18))                                    sdp_in_export[CHANNELS];

    mailbox#(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH))                      data_out_export;
    mailbox#(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)) meta_out_export;
    mailbox#(uvm_logic_vector::sequence_item#(18))                                    sdp_out_export;
    mailbox#(uvm_logic_vector::sequence_item#($clog2(CHANNELS)))                      chan_out_export;
    semaphore sem;
    uvm_dma_ll_info::watchdog #(CHANNELS) m_watch_dog;

    // ------------------------------------------------------------------------
    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);

        for (int unsigned chan = 0; chan < CHANNELS; chan++) begin
            data_in_export[chan] = new(10);
            meta_in_export[chan] = new(10);
            sdp_in_export [chan] = new(10);
        end

        data_out_export = new(10);
        meta_out_export = new(10);
        sdp_out_export  = new(10);
        chan_out_export = new(10);
        sem             = new(1);
    endfunction

    task read_chan(int unsigned channel);
        uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)                      data_tr;
        uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH) meta_tr;
        uvm_logic_vector::sequence_item#(18)                                    sdp_tr;
        uvm_logic_vector::sequence_item#($clog2(CHANNELS))                      chan_tr;

        data_in_export[channel].get(data_tr);
        sem.get();
        chan_tr = uvm_logic_vector::sequence_item#($clog2(CHANNELS))::type_id::create("chan_tr");

        meta_in_export[channel].get(meta_tr);
        sdp_in_export[channel].get(sdp_tr);
        chan_tr.data = channel;

        chan_out_export.put(chan_tr);
        data_out_export.put(data_tr);
        meta_out_export.put(meta_tr);
        sdp_out_export.put(sdp_tr);

        sem.put();
        m_watch_dog.binder_cnt[channel]++;

    endtask

    // ------------------------------------------------------------------------
    // Starts driving signals to interface
    task run_phase(uvm_phase phase);
        for (int unsigned chan = 0; chan < CHANNELS; chan++) begin
            fork
                automatic int unsigned it = chan;
                forever begin
                    read_chan(it);
                end
            join_none
        end
    endtask

endclass
