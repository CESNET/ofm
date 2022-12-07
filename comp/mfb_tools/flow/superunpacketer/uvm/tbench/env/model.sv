// model.sv: Model of implementation
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


class model #(HEADER_SIZE, VERBOSITY, OUT_META_WIDTH) extends uvm_component;
    `uvm_component_param_utils(uvm_superunpacketer::model #(HEADER_SIZE, VERBOSITY, OUT_META_WIDTH))

    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item #(8))        input_data;
    uvm_analysis_port #(uvm_logic_vector_array::sequence_item #(8))            out_data;
    uvm_analysis_port #(uvm_logic_vector::sequence_item #(OUT_META_WIDTH))     out_meta;
    typedef logic [8-1 : 0] data_queue[$];

    function new(string name = "model", uvm_component parent = null);
        super.new(name, parent);

        input_data = new("input_data", this);
        out_data   = new("out_data", this);
        out_meta   = new("out_meta", this);

    endfunction

    function logic[HEADER_SIZE-1 : 0] extract_header(uvm_logic_vector_array::sequence_item #(8) packet, int index);
        logic[HEADER_SIZE-1 : 0] ret = '0;
        for (int i = 0; i < (HEADER_SIZE/8); i++) begin
            ret[(i*8) +: 8] = packet.data[index + i];
        end
        return ret;
    endfunction

    function data_queue extract_data(uvm_logic_vector_array::sequence_item #(8) packet, int index, int size);
        logic [8-1 : 0] ret[$];
        for (int i = 0; i < size; i++) begin
            ret.push_back(packet.data[index + i]);
        end
        return ret;
    endfunction

    task run_phase(uvm_phase phase);

        uvm_logic_vector_array::sequence_item #(8)        tr_input_packet;
        uvm_logic_vector_array::sequence_item #(8)        tr_output_packet;
        uvm_logic_vector::sequence_item #(OUT_META_WIDTH) tr_output_meta;
        logic [HEADER_SIZE-1 : 0] header;
        int offset      = 0;
        int data_offset = HEADER_SIZE/8;
        int size_of_sp  = 0;
        int sp_cnt      = 0;
        int pkt_cnt     = 0;
        int size_of_pkt = 0;
        int align       = 0;
        logic [8-1 : 0] data_fifo[$];

        forever begin

            input_data.get(tr_input_packet);
            sp_cnt++;
            if (VERBOSITY >= 1) begin
                $write("\nSUPERPACKET NUMBER: %d\n", sp_cnt);
            end
            size_of_sp = tr_input_packet.data.size();
            if (VERBOSITY >= 2) begin
                `uvm_info(this.get_full_name(), tr_input_packet.convert2string() ,UVM_LOW)
            end

            while(offset != size_of_sp) begin

                tr_output_packet      = uvm_logic_vector_array::sequence_item #(8)::type_id::create("tr_output_packet");
                tr_output_meta        = uvm_logic_vector::sequence_item #(OUT_META_WIDTH)::type_id::create("tr_output_packet");

                header                = extract_header(tr_input_packet, offset);
                size_of_pkt           = header[15-1 : 0];
                align                 = ((size_of_pkt % 8 == 0) || (offset + size_of_pkt + HEADER_SIZE/8) == size_of_sp) ? 0 : (8 - (size_of_pkt % 8));
                offset               += (size_of_pkt + HEADER_SIZE/8 + align);
                tr_output_packet.data = extract_data(tr_input_packet, data_offset, size_of_pkt);
                data_offset          += size_of_pkt + (HEADER_SIZE/8) + align;
                tr_output_meta.data   = {header[HEADER_SIZE-1 : 16], header[14 : 0]};
                pkt_cnt++;

                if (VERBOSITY >= 1) begin
                    $write("PACKET NUMBER: %d SIZE OF PACKET %d\n", pkt_cnt, size_of_pkt);
                    $write("NEXT BIT %b\n", header[15]);
                end
                if (VERBOSITY >= 2) begin
                    $write("HEADER %h\n", header);
                    `uvm_info(this.get_full_name(), tr_output_packet.convert2string() ,UVM_LOW)
                end
                out_data.write(tr_output_packet);
                out_meta.write(tr_output_meta);

                if (offset > size_of_sp) begin
                    $write("DATA HEADER %h\n", header);
                    $write("\nSUPERPACKET NUMBER: %d\n", sp_cnt);
                    $write("PACKET NUMBER: %d SIZE OF PACKET %d\n", pkt_cnt, size_of_pkt);
                    `uvm_fatal(this.get_full_name(), "Data length of incoming transaction is wrong or there is a problem with parsing in model.");
                end

            end
            offset = 0;
            data_offset = HEADER_SIZE/8;
            pkt_cnt = 0;

        end

    endtask
endclass
