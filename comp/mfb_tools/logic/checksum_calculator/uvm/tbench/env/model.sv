// model.sv: Model of implementation
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause

class chsum_calc_item#(MVB_DATA_WIDTH, MFB_META_WIDTH) extends uvm_common::sequence_item;

    logic                                             bypass;
    logic[MFB_META_WIDTH-1 : 0]                       meta;
    uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH) data_tr;

    function string convert2string();
        string msg;

        $swrite(msg, "%s\n\tbypass %b\n", msg, bypass);
        $swrite(msg, "%s\n\tDATA: %s", msg, data_tr.convert2string());
        return msg;
    endfunction

endclass


class model #(META_WIDTH, MVB_DATA_WIDTH, MFB_ITEM_WIDTH, OFFSET_WIDTH, LENGTH_WIDTH, VERBOSITY, MFB_META_WIDTH) extends uvm_component;
    `uvm_component_param_utils(uvm_checksum_calculator::model #(META_WIDTH, MVB_DATA_WIDTH, MFB_ITEM_WIDTH, OFFSET_WIDTH, LENGTH_WIDTH, VERBOSITY, MFB_META_WIDTH))

    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)) input_data;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(META_WIDTH))           input_meta;
    uvm_analysis_port #(chsum_calc_item#(MVB_DATA_WIDTH, MFB_META_WIDTH))        out_checksum;

    function new(string name = "model", uvm_component parent = null);
        super.new(name, parent);

        out_checksum = new("out_checksum", this);
        input_data   = new("input_data", this);
        input_meta   = new("input_meta", this);

    endfunction

    typedef struct {
        uvm_logic_vector_array::sequence_item #(16) l3_checksum_data;
        uvm_logic_vector_array::sequence_item #(16) l4_checksum_data;
    } checksum;

    function uvm_logic_vector_array::sequence_item #(16) prepare_checksum_data(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH) frame, logic [OFFSET_WIDTH-1 : 0] offset, logic [LENGTH_WIDTH-1 : 0] length);
        uvm_logic_vector_array::sequence_item #(16) ret;
        int unsigned     data_index = 0;

        ret = uvm_logic_vector_array::sequence_item #(16)::type_id::create("ret");

        // Create checksum data array
        if (length % 2 == 1) begin
            ret.data = new[int'(length/2)+1];
        end else begin
            ret.data = new[int'(length/2)];
        end

        // Fill checksum data array with the correct bytes from the input frame
        for (int i = offset; i < offset+length; i+=2) begin
            ret.data[data_index][15:8]  = frame.data[i];
            if ((length % 2 == 1) && (data_index == int'(length/2))) begin // at the last last index
                ret.data[data_index][ 7:0]  = '0;
            end else begin
                ret.data[data_index][ 7:0]  = frame.data[i+1];
            end
            data_index++;
        end

        return ret;
    endfunction

    function logic[16-1 : 0] checksum_calc(uvm_logic_vector_array::sequence_item #(16) checksum_data);
        const logic [16-1 : 0] CHCKS_MAX = '1;
        logic [16-1 : 0] ret;
        logic [32-1 : 0] temp_checksum = '0;

        for(int i = 0; i < checksum_data.data.size(); i++) begin
            temp_checksum += checksum_data.data[i];
        end

        while (temp_checksum > CHCKS_MAX) begin
            temp_checksum = temp_checksum[15 : 0] + temp_checksum[31 : 16];
        end

        ret = temp_checksum[15 : 0] + temp_checksum[31 : 16];
        ret = ~ret;

        return ret;
    endfunction

    task run_phase(uvm_phase phase);

        uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH) tr_input_mfb;
        uvm_logic_vector::sequence_item #(META_WIDTH)           tr_input_meta;
        chsum_calc_item#(MVB_DATA_WIDTH, MFB_META_WIDTH)        tr_out_chsum;
        uvm_logic_vector::sequence_item #(1)                    chsum_en;
        uvm_logic_vector::sequence_item #(1)                    bypass;
        uvm_logic_vector_array::sequence_item #(16)             checksum_data;

        logic [OFFSET_WIDTH-1 : 0] offset = '0;
        logic [LENGTH_WIDTH-1 : 0] length = '0;
        int                        pkt_cnt = 0;

        forever begin

            input_data.get(tr_input_mfb);
            input_meta.get(tr_input_meta);

            pkt_cnt++;
            if (VERBOSITY >= 1) begin
                `uvm_info(this.get_full_name(), tr_input_meta.convert2string() ,UVM_NONE)
                `uvm_info(this.get_full_name(), tr_input_mfb.convert2string() ,UVM_NONE)
            end

            tr_out_chsum              = new;
            tr_out_chsum.data_tr = uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH)::type_id::create("tr_out_chsum.item.data_tr");
            tr_out_chsum.time_array_add(tr_input_mfb.start);

            chsum_en    = uvm_logic_vector::sequence_item #(1)::type_id::create("chsum_en");
            bypass      = uvm_logic_vector::sequence_item #(1)::type_id::create("bypass");

            offset                 = tr_input_meta.data[OFFSET_WIDTH-1  : 0];
            length                 = tr_input_meta.data[OFFSET_WIDTH+LENGTH_WIDTH-1  : OFFSET_WIDTH];
            chsum_en.data          = tr_input_meta.data[OFFSET_WIDTH+LENGTH_WIDTH+1-1  : OFFSET_WIDTH+LENGTH_WIDTH];
            tr_out_chsum.meta = tr_input_meta.data[META_WIDTH-1  : OFFSET_WIDTH+LENGTH_WIDTH+1];

            checksum_data     = prepare_checksum_data(tr_input_mfb, offset, length);
            tr_out_chsum.data_tr.data = checksum_calc(checksum_data);

            tr_out_chsum.bypass    = !chsum_en.data;

            if (VERBOSITY >= 1) begin
                `uvm_info(this.get_full_name(), tr_out_chsum.convert2string() ,UVM_NONE)
            end

            out_checksum.write(tr_out_chsum);
        end

    endtask
endclass
