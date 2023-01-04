// driver.sv
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause

class driver#(ITEM_WIDTH, META_WIDTH) extends uvm_component;
    `uvm_component_param_utils(uvm_checksum_calculator::driver#(ITEM_WIDTH, META_WIDTH))

    uvm_seq_item_pull_port #(uvm_logic_vector_array::sequence_item #(ITEM_WIDTH), uvm_logic_vector_array::sequence_item #(ITEM_WIDTH)) seq_item_port_payload;
    uvm_seq_item_pull_port #(uvm_header_type::sequence_item, uvm_header_type::sequence_item)                                           seq_item_port_info;

    mailbox#(uvm_header_type::sequence_item)                 frame_export;
    mailbox #(uvm_logic_vector::sequence_item #(META_WIDTH)) logic_vector_export;

    uvm_logic_vector_array::sequence_item #(ITEM_WIDTH) payload_req;
    uvm_header_type::sequence_item                      info_req;

    uvm_logic_vector_array::sequence_item #(ITEM_WIDTH) payload_new;
    uvm_logic_vector_array::sequence_item #(ITEM_WIDTH) frame_out;
    uvm_logic_vector::sequence_item #(META_WIDTH)       meta;

    local logic [ITEM_WIDTH-1 : 0] data_fifo[$];
    local logic [15 : 0]           payload_len;
    local logic [32-1 : 0]  ipv4_src_addr;
    local logic [32-1 : 0]  ipv4_dst_addr;
    local logic [128-1 : 0] ipv6_src_addr;
    local logic [128-1 : 0] ipv6_dst_addr;

    local logic [16-1 : 0]  checksum_fifo[$];
    local int len_ind = 0;

    // ------------------------------------------------------------------------
    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);

        seq_item_port_payload = new("seq_item_port_payload", this);
        seq_item_port_info   = new("seq_item_port_info", this);

        frame_export        = new(10);
        logic_vector_export = new(10);
    endfunction

    // ------------------------------------------------------------------------
    // Starts driving signals to interface
    task run_phase(uvm_phase phase);

        forever begin

            seq_item_port_payload.get_next_item(payload_req);
            seq_item_port_info.get_next_item(info_req);
            payload_len = '0;

            $cast(payload_new, payload_req.clone());

            meta  = uvm_logic_vector::sequence_item #(META_WIDTH)::type_id::create("meta");
            meta.data[7-1 : 0] = info_req.l2_size;
            meta.data[16-1 : 7] = info_req.l3_size;
            meta.data[20-1 : 16] = info_req.flag;

            frame_out = uvm_logic_vector_array::sequence_item #(ITEM_WIDTH)::type_id::create("frame_out");
            frame_export.put(info_req);
            logic_vector_export.put(meta);

            seq_item_port_payload.item_done();
            seq_item_port_info.item_done();
        end
    endtask

endclass
