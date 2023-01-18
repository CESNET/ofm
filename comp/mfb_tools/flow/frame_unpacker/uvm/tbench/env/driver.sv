// driver.sv
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause

class driver#(HEADER_SIZE, VERBOSITY, PKT_MTU, MIN_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, OFF_PIPE_STAGES) extends uvm_component;
    `uvm_component_param_utils(uvm_superunpacketer::driver#(HEADER_SIZE, VERBOSITY, PKT_MTU, MIN_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, OFF_PIPE_STAGES))

    uvm_seq_item_pull_port #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH), uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)) seq_item_port_byte_array;
    uvm_seq_item_pull_port #(uvm_superpacket_header::sequence_item, uvm_superpacket_header::sequence_item)           seq_item_port_header;
    uvm_seq_item_pull_port #(uvm_superpacket_size::sequence_item, uvm_superpacket_size::sequence_item)               seq_item_port_sp_size;

    mailbox#(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)) byte_array_export;

    // STATES
    parameter FIRST = 0;
    parameter DATA  = 1;

    uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH) byte_array_req;
    uvm_superpacket_header::sequence_item                   info_req;
    uvm_superpacket_size::sequence_item                     size_of_sp; // Size of superpacket in bytes with headers
    uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH) byte_array_new;
    uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH) byte_array_out;

    int pkt_cnt_stat[OFF_PIPE_STAGES] = '{default:'0};
    int state                         = 0;
    int act_size                      = 0;
    int sp_cnt                        = 0;
    int pkt_cnt                       = 0;
    int end_of_packet                 = 0;
    int sup_align                     = 0;

    logic                              done = 1'b0;
    logic [HEADER_SIZE-1 : 0]          header;
    local logic [MFB_ITEM_WIDTH-1 : 0] data_fifo[$];

    function logic[HEADER_SIZE-1 : 0] fill_header(uvm_superpacket_header::sequence_item info, logic first);
        logic[HEADER_SIZE-1 : 0] ret = '0;
        info.next = 1'b1;

        if((size_of_sp.sp_size - ((act_size + HEADER_SIZE/MFB_ITEM_WIDTH) + info.length)) < MIN_SIZE) begin
            info.next = 1'b0;
        end

        if ((act_size + HEADER_SIZE/MFB_ITEM_WIDTH + info.length) >= size_of_sp.sp_size) begin
            info.length = (size_of_sp.sp_size - (act_size + HEADER_SIZE/MFB_ITEM_WIDTH));
            info.next = 1'b0;
        end
        if (pkt_cnt == OFF_PIPE_STAGES) begin
            info.next = 1'b0;
        end
        end_of_packet = info.length + HEADER_SIZE/MFB_ITEM_WIDTH;

        ret = {info.timestamp, info.loop_id, info.mask, info.next, info.length};
        return ret;
    endfunction

    function void fill_tr(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH) pkt, logic[HEADER_SIZE-1 : 0] header);
        int align  = 0;
        string msg = "";

        align = MFB_BLOCK_SIZE - end_of_packet[3-1 : 0];
        if (header[15] == 1'b1 && end_of_packet[3-1 : 0] > 0) begin
            end_of_packet += align;
        end

        for (int i = 0; i < end_of_packet; i++) begin
            if (i < HEADER_SIZE/MFB_ITEM_WIDTH) begin
                data_fifo.push_back(header[(i+1)*MFB_ITEM_WIDTH-1 -: MFB_ITEM_WIDTH]);
            end else if (i < pkt.data.size() + (HEADER_SIZE/MFB_ITEM_WIDTH)) begin
                data_fifo.push_back(pkt.data[i - (HEADER_SIZE/MFB_ITEM_WIDTH)]);
            end else
                data_fifo.push_back('0);

            act_size++;
        end

        if (header[15] == 1'b0 && end_of_packet[3-1 : 0]) begin
            for (int i = 0; i < align; i++) begin
                data_fifo.push_back('0);
            end
        end

        if (act_size == size_of_sp.sp_size && VERBOSITY >= 3) begin
            $swrite(msg, "%s\tSIZE OF FIFO %d\n", msg, data_fifo.size());
            $swrite(msg, "%s\tSIZE OF SP %d\n", msg, size_of_sp.sp_size);
            `uvm_info(this.get_full_name(), msg ,UVM_FULL)
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
        localparam MIN_DATA_SIZE = MIN_SIZE - HEADER_SIZE/MFB_ITEM_WIDTH;
        logic[16-1 : 0] len_with_hdr = 0;
        string msg = "";

        forever begin

            done = 1'b0;
            while (done != 1'b1) begin

                seq_item_port_byte_array.get_next_item(byte_array_req);
                pkt_cnt++;
                seq_item_port_header.get_next_item(info_req);

                $cast(byte_array_new, byte_array_req.clone());
                info_req.length = byte_array_new.data.size();
                header = '0;

                if (state == FIRST) begin
                    state          = DATA;
                    byte_array_out = uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)::type_id::create("byte_array_out");
                    seq_item_port_sp_size.get_next_item(size_of_sp);
                end

                header = fill_header(info_req, 1'b1);

                len_with_hdr = byte_array_new.size() + HEADER_SIZE/MFB_ITEM_WIDTH;
                if (VERBOSITY >= 3) begin
                    $swrite(msg, "%s\n ================ DEBUG IN DRIVER =============== \n", msg);
                    $swrite(msg, "%s\tlen with hdr %d\n", msg, len_with_hdr);
                    $swrite(msg, "%s\tact_size %d\n", msg, act_size);
                    $swrite(msg, "%s\tMIN DATA SIZE %d\n", msg, MIN_DATA_SIZE);
                    $swrite(msg, "%s\tHEADER_SIZE/MFB_ITEM_WIDTH %d\n", msg, HEADER_SIZE/MFB_ITEM_WIDTH);
                    $swrite(msg, "%s\tsize_of_sp.sp_size %d\n", msg, size_of_sp.sp_size);
                    $swrite(msg, "%s\tALIGN %d\n", msg, MFB_BLOCK_SIZE-len_with_hdr[3-1 : 0]);
                    $swrite(msg, "%s\tSOLUTION %d\n", msg, signed'((size_of_sp.sp_size - (act_size + len_with_hdr + HEADER_SIZE/MFB_ITEM_WIDTH + MIN_DATA_SIZE + (MFB_BLOCK_SIZE - int'(len_with_hdr[3-1 : 0]) )))));
                    `uvm_info(this.get_full_name(), msg ,UVM_FULL)
                end

                // Check if there is a place for another packet
                if (signed'((size_of_sp.sp_size - (act_size + len_with_hdr + HEADER_SIZE/MFB_ITEM_WIDTH + MIN_DATA_SIZE + (MFB_BLOCK_SIZE - int'(len_with_hdr[3-1 : 0]) )))) < 0) begin
                    header[15] = 1'b0;
                end

                fill_tr(byte_array_new, header);

                if (header[15-1 : 0] < MIN_DATA_SIZE) begin
                    `uvm_fatal(this.get_full_name(), "Data length is too small.");
                end

                if (header[15] == 1'b0) begin
                    done                = 1'b1;
                    pkt_cnt_stat[pkt_cnt] += 1;
                    pkt_cnt             = 1'b0;
                    byte_array_out.data = data_fifo;
                    sup_align = MFB_BLOCK_SIZE - (size_of_sp.sp_size % MFB_BLOCK_SIZE);
                    if (byte_array_out.size() > size_of_sp.sp_size + sup_align) begin
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

    function void report_phase(uvm_phase phase);
        string msg = "";

        $swrite(msg, "%s\n\tNumber of packets in SP statistic:\n", msg);
        for (int unsigned it = 0; it < OFF_PIPE_STAGES; it++) begin
            $swrite(msg, "%s\tCounter number %d: %d\n", msg, it, pkt_cnt_stat[it]);
        end
        `uvm_info(this.get_full_name(), msg ,UVM_FULL)
    endfunction


endclass
