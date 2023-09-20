// model.sv: Model of implementation
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


class model #(HEADER_SIZE, MFB_ITEM_WIDTH, MVB_ITEM_WIDTH, VERBOSITY) extends uvm_component;
    `uvm_component_param_utils(uvm_superunpacketer::model #(HEADER_SIZE, MFB_ITEM_WIDTH, MVB_ITEM_WIDTH, VERBOSITY))

    uvm_common::fifo #(uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)))        input_data;
    uvm_common::fifo #(uvm_common::model_item #(uvm_logic_vector::sequence_item #(MVB_ITEM_WIDTH)))              input_mvb;
    uvm_analysis_port #(uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)))       out_data;
    uvm_analysis_port #(uvm_common::model_item #(uvm_logic_vector::sequence_item #(HEADER_SIZE+MVB_ITEM_WIDTH))) out_meta;

    typedef logic [MFB_ITEM_WIDTH-1 : 0] data_queue[$];

    function new(string name = "model", uvm_component parent = null);
        super.new(name, parent);

        input_data = null;
        input_mvb  = null;
        out_data   = new("out_data", this);
        out_meta   = new("out_meta", this);

    endfunction

    function logic[HEADER_SIZE-1 : 0] extract_header(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH) packet, int index);
        logic[HEADER_SIZE-1 : 0] ret = '0;
        for (int i = 0; i < (HEADER_SIZE/MFB_ITEM_WIDTH); i++) begin
            ret[(i*MFB_ITEM_WIDTH) +: MFB_ITEM_WIDTH] = packet.data[index + i];
        end
        return ret;
    endfunction

    function data_queue extract_data(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH) packet, int index, int size);
        logic [MFB_ITEM_WIDTH-1 : 0] ret[$];
        for (int i = 0; i < size; i++) begin
            ret.push_back(packet.data[index + i]);
        end
        return ret;
    endfunction

    task run_phase(uvm_phase phase);

        uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))       tr_input_packet;
        uvm_common::model_item #(uvm_logic_vector::sequence_item #(MVB_ITEM_WIDTH))             tr_input_mvb;
        uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))       tr_output_packet;
        uvm_common::model_item #(uvm_logic_vector::sequence_item #(HEADER_SIZE+MVB_ITEM_WIDTH)) tr_output_meta;

        logic [HEADER_SIZE-1 : 0]    header;
        logic [MFB_ITEM_WIDTH-1 : 0] data_fifo[$];

        int offset      = 0;
        int data_offset = HEADER_SIZE/MFB_ITEM_WIDTH;
        int size_of_sp  = 0;
        int sp_cnt      = 0;
        int pkt_cnt     = 0;
        int size_of_pkt = 0;
        int align       = 0;

        string msg;

        forever begin

            msg = "";
            input_data.get(tr_input_packet);
            input_mvb.get(tr_input_mvb);
            sp_cnt++;
            $swrite(msg, "%s\n ================ MODEL DEBUG =============== \n", msg);
            $swrite(msg, "%s\tSUPERPACKET NUMBER: %d\n", msg, sp_cnt);
            if (this.get_report_verbosity_level() == 200) begin
                $swrite(msg, "%s\tINPUT PACKET: %s\n", msg, tr_input_packet.convert2string());
            end
            size_of_sp = tr_input_packet.item.data.size();
            if (this.get_report_verbosity_level() == 300) begin
            end

            while(offset != size_of_sp) begin

                tr_output_packet      = uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))::type_id::create("tr_output_packet");
                tr_output_packet.item = uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)::type_id::create("tr_output_packet_item");
                tr_output_meta        = uvm_common::model_item #(uvm_logic_vector::sequence_item #(HEADER_SIZE+MVB_ITEM_WIDTH))::type_id::create("tr_output_packet");
                tr_output_meta.item   = uvm_logic_vector::sequence_item #(HEADER_SIZE+MVB_ITEM_WIDTH)::type_id::create("tr_output_packet_item");

                header                     = extract_header(tr_input_packet.item, offset);
                size_of_pkt                = header[16-1 : 0];
                align                      = ((size_of_pkt % MFB_ITEM_WIDTH == 0) || (offset + size_of_pkt + HEADER_SIZE/MFB_ITEM_WIDTH) == size_of_sp) ? 0 : (MFB_ITEM_WIDTH - (size_of_pkt % MFB_ITEM_WIDTH));
                offset                    += (size_of_pkt + HEADER_SIZE/MFB_ITEM_WIDTH + align);
                tr_output_packet.item.data = extract_data(tr_input_packet.item, data_offset, size_of_pkt);
                data_offset               += size_of_pkt + (HEADER_SIZE/MFB_ITEM_WIDTH) + align;
                tr_output_meta.item.data   = {tr_input_mvb.item.data, header};
                pkt_cnt++;

                tr_output_packet.time_array_add(tr_input_packet.start);
                tr_output_packet.time_array_add(tr_input_mvb.start);
                tr_output_meta.time_array_add(tr_input_packet.start);
                tr_output_meta.time_array_add(tr_input_mvb.start);

                if (this.get_report_verbosity_level() == 200) begin
                    $swrite(msg, "%s\tHEADER %h\n", msg, header);
                end
                if (this.get_report_verbosity_level() == 300) begin
                    $swrite(msg, "%s\tPACKET NUMBER: %d SIZE OF PACKET %d\n", msg, pkt_cnt, size_of_pkt);
                end
                $swrite(msg, "%s\tOUTPUT PACKET %s\n", msg, tr_output_packet.convert2string());
                $swrite(msg, "%s\tOUTPUT META %s\n", msg, tr_output_meta.convert2string());
                out_data.write(tr_output_packet);
                out_meta.write(tr_output_meta);

                if (this.get_report_verbosity_level() == 200) begin
                    `uvm_info(this.get_full_name(), msg ,UVM_FULL)
                end

                if (offset > size_of_sp) begin
                    msg = "";
                    $swrite(msg, "%s\n ================ OFFSET FATAL =============== \n", msg);
                    $swrite(msg, "%s\tDATA HEADER %h\n", msg, header);
                    $swrite(msg, "%s\n\tSUPERPACKET NUMBER: %d\n", msg, sp_cnt);
                    $swrite(msg, "%s\tPACKET NUMBER: %d SIZE OF PACKET %d\n", msg, pkt_cnt, size_of_pkt);
                    $swrite(msg, "%s\tData length of incoming transaction is wrong or there is a problem with parsing in model.", msg);
                    `uvm_fatal(this.get_full_name(), msg);
                end


            end
            $swrite(msg, "%s\n ======================================= \n", msg);
            `uvm_info(this.get_full_name(), msg ,UVM_FULL)
            offset = 0;
            data_offset = HEADER_SIZE/MFB_ITEM_WIDTH;
            pkt_cnt = 0;
        end

    endtask
endclass
