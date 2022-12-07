//-- driver.sv
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Radek Iša <isa@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause


class driver#(CHANNELS, PKT_SIZE_MAX) extends uvm_component;
    `uvm_component_param_utils(uvm_dma_ll_rx::driver#(CHANNELS, PKT_SIZE_MAX))

    localparam MFB_META_WIDTH = 24 + $clog2(PKT_SIZE_MAX+1) + $clog2(CHANNELS);

    uvm_seq_item_pull_port #(uvm_byte_array::sequence_item, uvm_byte_array::sequence_item)   seq_item_port_byte_array;
    uvm_seq_item_pull_port #(uvm_dma_ll_info::sequence_item, uvm_dma_ll_info::sequence_item) seq_item_port_info;

    mailbox#(uvm_byte_array::sequence_item)   byte_array_export;
    mailbox#(uvm_logic_vector::sequence_item#(MFB_META_WIDTH)) logic_vector_export;

    uvm_byte_array::sequence_item byte_array_req;
    uvm_dma_ll_info::sequence_item       info_req;

    uvm_byte_array::sequence_item                 byte_array_new;
    uvm_logic_vector::sequence_item#(MFB_META_WIDTH)  logic_vector_new;

    // ------------------------------------------------------------------------
    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);

        seq_item_port_byte_array = new("seq_item_port_byte_array", this);
        seq_item_port_info       = new("seq_item_port_info", this);

        byte_array_export   = new(1);
        logic_vector_export = new(1);
    endfunction

    // ------------------------------------------------------------------------
    // Starts driving signals to interface
    task run_phase(uvm_phase phase);
        logic [$clog2(PKT_SIZE_MAX+1)-1:0] packet_size;
        logic [$clog2(CHANNELS)-1:0]       channel;
        logic [24-1:0]                     meta;

        forever begin
            // Get new sequence item to drive to interface
            seq_item_port_byte_array.get_next_item(byte_array_req);
            seq_item_port_info.get_next_item(info_req);

            $cast(byte_array_new, byte_array_req.clone());
            logic_vector_new  = uvm_logic_vector::sequence_item#(MFB_META_WIDTH)::type_id::create("logic_vector_new");
            packet_size  = byte_array_new.data.size();
            channel      = info_req.channel;
            meta         = info_req.meta;
            logic_vector_new.data = {packet_size, channel, meta};

            byte_array_export.put(byte_array_new);
            logic_vector_export.put(logic_vector_new);

            seq_item_port_byte_array.item_done();
            seq_item_port_info.item_done();
        end
    endtask

endclass

