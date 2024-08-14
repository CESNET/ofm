// generator.sv
// Copyright (C) 2024 CESNET z. s. p. o.
// Author(s): David Beneš <xbenes52@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


class generator#(USR_RX_PKT_SIZE_MAX, RX_CHANNELS, HDR_META_WIDTH, MVB_ITEM_WIDTH, MFB_ITEM_WIDTH) extends uvm_component;
    `uvm_component_param_utils(uvm_framepacker::generator#(USR_RX_PKT_SIZE_MAX, RX_CHANNELS, HDR_META_WIDTH, MVB_ITEM_WIDTH, MFB_ITEM_WIDTH))

    localparam MVB_LEN_WIDTH = $clog2(USR_RX_PKT_SIZE_MAX+1);
    localparam MVB_CHANNEL_WIDTH = $clog2(RX_CHANNELS);

    // PORT DECLARATION
    //INPUT
    uvm_seq_item_pull_port #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH), uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))                                         seq_item_port_byte_array;
    uvm_seq_item_pull_port #(uvm_meta::sequence_item #(USR_RX_PKT_SIZE_MAX, RX_CHANNELS, HDR_META_WIDTH), uvm_meta::sequence_item #(USR_RX_PKT_SIZE_MAX, RX_CHANNELS, HDR_META_WIDTH)) seq_item_port_info;

    //OUTPUT - FIFO
    mailbox#(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)) byte_array_export;
    mailbox#(uvm_logic_vector::sequence_item#(MVB_ITEM_WIDTH))        logic_vector_export;

    uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)                     byte_array_req;
    uvm_meta::sequence_item #(USR_RX_PKT_SIZE_MAX, RX_CHANNELS, HDR_META_WIDTH) info_req;

    uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH) byte_array_new;
    uvm_logic_vector::sequence_item#(MVB_ITEM_WIDTH)        logic_vector_new;

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

        logic [MVB_LEN_WIDTH-1:0]     packet_size;
        logic [HDR_META_WIDTH-1:0]    meta;
        logic [MVB_CHANNEL_WIDTH-1:0] channel;
        logic                         discard;

        forever begin
            // Get new sequence item to generate to interface
            seq_item_port_byte_array.get_next_item(byte_array_req);
            seq_item_port_info.get_next_item(info_req);

            $cast(byte_array_new, byte_array_req.clone());
            logic_vector_new      = uvm_logic_vector::sequence_item#(MVB_ITEM_WIDTH)::type_id::create("logic_vector_new");
            packet_size           = byte_array_new.data.size();
            meta                  = info_req.meta;
            channel               = info_req.channel;
            discard               = info_req.discard;
            logic_vector_new.data = {packet_size, meta, channel, discard};

            byte_array_export.put(byte_array_new);
            logic_vector_export.put(logic_vector_new);

            seq_item_port_byte_array.item_done();
            seq_item_port_info.item_done();
        end
    endtask

endclass
