// model.sv: Model of implementation
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause

class chsum_calc_item#(MVB_DATA_WIDTH, MFB_META_WIDTH);

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

    uvm_common::fifo #(uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))) input_data;
    uvm_common::fifo #(uvm_common::model_item #(uvm_logic_vector::sequence_item #(META_WIDTH)))           input_meta;
    uvm_analysis_port #(uvm_common::model_item #(chsum_calc_item#(MVB_DATA_WIDTH, MFB_META_WIDTH)))                       out_checksum;

    function new(string name = "model", uvm_component parent = null);
        super.new(name, parent);

        out_checksum = new("out_checksum", this);
        input_data   = null;
        input_meta   = null;

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
            // $write("Frame data part 1 (i=%d): 0x%h\n", i  , frame.data[i]);
            // $write("Frame data part 2 (i=%d): 0x%h\n", i+1, frame.data[i+1]);
            ret.data[data_index][15:8]  = frame.data[i];
            if ((length % 2 == 1) && (data_index == int'(length/2))) begin // at the last last index
                ret.data[data_index][ 7:0]  = '0;
            end else begin
                ret.data[data_index][ 7:0]  = frame.data[i+1];
            end
            // $write("Return data: (di=%d): 0x%h\n", data_index, ret.data[data_index]);
            // $write("Current state of the return data array:\n");
            // `uvm_info(this.get_full_name(), ret.convert2string() ,UVM_NONE)
            data_index++;
        end

        // $write("prepare_checksum_data:\n");
        // $write("CHSUM DATA LEN %d\n", length);
        // `uvm_info(this.get_full_name(), ret.convert2string() ,UVM_NONE)
        return ret;
    endfunction

    function logic[16-1 : 0] checksum_calc(uvm_logic_vector_array::sequence_item #(16) checksum_data);
        const logic [16-1 : 0] CHCKS_MAX = '1;
        logic [16-1 : 0] ret;
        logic [32-1 : 0] temp_checksum = '0;

        for(int i = 0; i < checksum_data.data.size(); i++) begin
            temp_checksum += checksum_data.data[i];
            // $write("CHSUM DATA: %h\n", checksum_data.data[i]);
            // $write("Length of CHSUM DATA: %d\n", checksum_data.data.size());
            // $write("Tmp CHSUM: %h\n", temp_checksum);
        end

        while (temp_checksum > CHCKS_MAX) begin
            temp_checksum = temp_checksum[15 : 0] + temp_checksum[31 : 16];
            // $write("FINAL CHSUM: %h\n", temp_checksum);
        end

        ret = temp_checksum[15 : 0] + temp_checksum[31 : 16];
        // $write("BEFORE REVERT CHSUM: %h\n", ret);
        ret = ~ret;
        // $write("REVERT CHSUM: %h\n", ret);

        return ret;
    endfunction

    task run_phase(uvm_phase phase);

        uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)) tr_input_mfb;
        uvm_common::model_item #(uvm_logic_vector::sequence_item #(META_WIDTH))           tr_input_meta;
        uvm_common::model_item #(chsum_calc_item#(MVB_DATA_WIDTH, MFB_META_WIDTH))        tr_out_chsum;
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

            tr_out_chsum              = uvm_common::model_item #(chsum_calc_item#(MVB_DATA_WIDTH, MFB_META_WIDTH))::type_id::create("tr_out_chsum");
            tr_out_chsum.item         = new();
            tr_out_chsum.item.data_tr = uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH)::type_id::create("tr_out_chsum.item.data_tr");
            tr_out_chsum.time_array_add(tr_input_mfb.start);

            chsum_en    = uvm_logic_vector::sequence_item #(1)::type_id::create("chsum_en");
            bypass      = uvm_logic_vector::sequence_item #(1)::type_id::create("bypass");

            offset                 = tr_input_meta.item.data[OFFSET_WIDTH-1  : 0];
            length                 = tr_input_meta.item.data[OFFSET_WIDTH+LENGTH_WIDTH-1  : OFFSET_WIDTH];
            chsum_en.data          = tr_input_meta.item.data[OFFSET_WIDTH+LENGTH_WIDTH+1-1  : OFFSET_WIDTH+LENGTH_WIDTH];
            tr_out_chsum.item.meta = tr_input_meta.item.data[META_WIDTH-1  : OFFSET_WIDTH+LENGTH_WIDTH+1];

            // $write("-------------- Model input --------------\n");
            // $write("Packet data:\n");
            // `uvm_info(this.get_full_name(), tr_input_mfb.convert2string() ,UVM_NONE)
            // $write("Metadata:\n");
            // $write("\tOffset: %d\n\tLength: %d\n\tEnable: %d\n", offset, length, chsum_en.data);

            checksum_data     = prepare_checksum_data(tr_input_mfb.item, offset, length);
            // `uvm_info(this.get_full_name(), checksum_data.convert2string() ,UVM_NONE)
            tr_out_chsum.item.data_tr.data = checksum_calc(checksum_data);

            tr_out_chsum.item.bypass    = !chsum_en.data;

            if (VERBOSITY >= 1) begin
                `uvm_info(this.get_full_name(), tr_out_chsum.convert2string() ,UVM_NONE)
            end

            out_checksum.write(tr_out_chsum);
        end

    endtask
endclass
