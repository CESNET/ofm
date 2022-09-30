// driver.sv
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause

class driver#(META_WIDTH, HEADER_SIZE, VERBOSITY, PKT_MTU, MIN_SIZE, MFB_BLOCK_SIZE) extends uvm_component;
    `uvm_component_param_utils(uvm_superunpacketer::driver#(META_WIDTH, HEADER_SIZE, VERBOSITY, PKT_MTU, MIN_SIZE, MFB_BLOCK_SIZE))

    uvm_seq_item_pull_port #(uvm_logic_vector_array::sequence_item #(8), uvm_logic_vector_array::sequence_item #(8)) seq_item_port_byte_array;
    uvm_seq_item_pull_port #(uvm_superpacket_header::sequence_item, uvm_superpacket_header::sequence_item)           seq_item_port_header;
    uvm_seq_item_pull_port #(uvm_superpacket_size::sequence_item, uvm_superpacket_size::sequence_item)               seq_item_port_sp_size;

    mailbox#(uvm_logic_vector_array::sequence_item #(8)) byte_array_export;

    // STATES
    parameter FIRST = 0;
    parameter DATA  = 1;

    uvm_logic_vector_array::sequence_item #(8) byte_array_req;
    uvm_superpacket_header::sequence_item      info_req;
    uvm_superpacket_size::sequence_item        size_of_sp; // Size of superpacket in bytes with headers

    uvm_logic_vector_array::sequence_item #(8) byte_array_new;
    uvm_logic_vector_array::sequence_item #(8) byte_array_out;

    int state         = 0;
    int act_size      = 0;
    int sp_cnt        = 0;
    int end_of_packet = 0;
    logic done        = 1'b0;
    logic [HEADER_SIZE-1 : 0] header;
    local logic [8-1 : 0] data_fifo[$];

    function logic[HEADER_SIZE-1 : 0] fill_header(uvm_superpacket_header::sequence_item info, logic first);
        logic[HEADER_SIZE-1 : 0] ret = '0;
        info.next = 1'b1;

        if((size_of_sp.sp_size - ((act_size + HEADER_SIZE/8) + info.length)) < MIN_SIZE) begin
            info.next = 1'b0;
        end

        if ((act_size + HEADER_SIZE/8 + info.length) >= size_of_sp.sp_size) begin
            info.length = (size_of_sp.sp_size - (act_size + HEADER_SIZE/8));
            info.next = 1'b0;
        end
        end_of_packet = info.length + HEADER_SIZE/8;
        ret = {info.timestamp, info.loop_id, info.mask, info.next, info.length};
        return ret;
    endfunction

    function void fill_tr(uvm_logic_vector_array::sequence_item #(8) pkt, logic[HEADER_SIZE-1 : 0] header);
        int align         = 0;

        align = end_of_packet % MFB_BLOCK_SIZE;
        if (header[15] == 1'b1 && align > 0) begin
            end_of_packet += MFB_BLOCK_SIZE - align;
        end

        for (int i = 0; i < end_of_packet; i++) begin
            if (i < HEADER_SIZE/8) begin
                data_fifo.push_back(header[(i+1)*8-1 -: 8]);
            end else if (i < pkt.data.size() + (HEADER_SIZE/8)) begin
                data_fifo.push_back(pkt.data[i - (HEADER_SIZE/8)]);
            end else
                data_fifo.push_back('0);

            act_size++;
        end

        if (act_size == size_of_sp.sp_size && VERBOSITY >= 2) begin
            $write("SIZE OF FIFO %d\n", data_fifo.size());
            $write("SIZE OF SP %d\n", size_of_sp.sp_size);
        end
    endfunction

    // ------------------------------------------------------------------------
    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);

        seq_item_port_byte_array = new("seq_item_port_byte_array", this);
        seq_item_port_header     = new("seq_item_port_header", this);
        seq_item_port_sp_size    = new("seq_item_port_sp_size", this);

        byte_array_export        = new(10);
    endfunction

    // ------------------------------------------------------------------------
    // Starts driving signals to interface
    task run_phase(uvm_phase phase);

        forever begin

            done = 1'b0;
            while (done != 1'b1) begin

                seq_item_port_byte_array.get_next_item(byte_array_req);
                seq_item_port_header.get_next_item(info_req);

                $cast(byte_array_new, byte_array_req.clone());
                info_req.length = byte_array_new.data.size();
                header = '0;
                if (state == FIRST) begin
                    state          = DATA;
                    byte_array_out = uvm_logic_vector_array::sequence_item #(8)::type_id::create("byte_array_out");
                    seq_item_port_sp_size.get_next_item(size_of_sp);
                end
                header = fill_header(info_req, 1'b1);
                fill_tr(byte_array_new, header);
                if (header[15] == 1'b0) begin
                    done                = 1'b1;
                    byte_array_out.data = data_fifo;
                    if (byte_array_out.size() > size_of_sp.sp_size) begin
                        `uvm_fatal(this.get_full_name(), "Data length is too long.");
                    end
                    byte_array_export.put(byte_array_out);
                    sp_cnt++;
                    act_size = 0;
                    data_fifo.delete();
                    byte_array_out = null;
                    state = FIRST;
                    seq_item_port_sp_size.item_done();
                end
                end_of_packet = 0;
                seq_item_port_byte_array.item_done();
                seq_item_port_header.item_done();

            end

        end
    endtask

endclass
