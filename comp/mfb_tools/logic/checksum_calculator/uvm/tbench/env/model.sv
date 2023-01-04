// model.sv: Model of implementation
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


class model #(META_WIDTH, MVB_DATA_WIDTH, MFB_ITEM_WIDTH, VERBOSITY) extends uvm_component;
    `uvm_component_param_utils(uvm_checksum_calculator::model #(META_WIDTH, MVB_DATA_WIDTH, MFB_ITEM_WIDTH, VERBOSITY))

    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)) input_mfb;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(META_WIDTH))           input_meta;
    uvm_analysis_port #(uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH))           out_l3_checksum_mvb;
    uvm_analysis_port #(uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH))           out_l4_checksum_mvb;
    // uvm_analysis_port #(uvm_logic_vector::sequence_item #(2))                        out_bypass;
    uvm_analysis_port #(uvm_logic_vector::sequence_item #(1))                        out_l3_bypass;
    uvm_analysis_port #(uvm_logic_vector::sequence_item #(1))                        out_l4_bypass;

    function new(string name = "model", uvm_component parent = null);
        super.new(name, parent);

        input_mfb           = new("input_mfb", this);
        input_meta          = new("input_meta", this);
        out_l3_checksum_mvb = new("out_l3_checksum_mvb", this);
        out_l4_checksum_mvb = new("out_l4_checksum_mvb", this);
        // out_bypass          = new("out_bypass", this);
        out_l3_bypass       = new("out_l3_bypass", this);
        out_l4_bypass       = new("out_l4_bypass", this);

    endfunction

    typedef struct {
        uvm_logic_vector_array::sequence_item #(16) l3_checksum_data;
        uvm_logic_vector_array::sequence_item #(16) l4_checksum_data;
    } checksum;

    function checksum prepare_checksum_data(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH) frame, logic [7-1 : 0] l2_size, logic [9-1 : 0] l3_size, logic [4-1 : 0] flag);
        checksum         ret;
        logic [16-1 : 0] l4_len = '0;
        int unsigned     data_index = 0;

        ret.l3_checksum_data = uvm_logic_vector_array::sequence_item #(16)::type_id::create("l3_checksum_data");
        ret.l4_checksum_data = uvm_logic_vector_array::sequence_item #(16)::type_id::create("l4_checksum_data");

        // $write("DATA bytes\n");
        // `uvm_info(this.get_full_name(), frame.convert2string() ,UVM_NONE)
        // $write("FLAG %b\n", flag);
        if (flag[1] == 1'b1) begin
            l4_len = frame.data.size() - (l2_size + l3_size);
            ret.l4_checksum_data.data = new[l4_len/2];
            // $write("L4 HDR LEN %d\n", (l4_len));
            // $write("L3 HDR LEN %d\n", (l3_size));

            for (int i = 0; i < l4_len; i += 2) begin
                ret.l4_checksum_data.data[data_index] = {<<16{frame.data[(l2_size + l3_size) + i +: 2]}};
                data_index++;
            end

            if ((l4_len %2) != 0) begin
                ret.l4_checksum_data.data = {ret.l4_checksum_data.data, {frame.data[frame.data.size()-1], 8'b00000000}};
                // ret.l4_checksum_data.data = {ret.l4_checksum_data.data, {8'b00000000, frame.data[frame.data.size()-1]}};
            end

            // $write("DATA checksum\n");
            // `uvm_info(this.get_full_name(), ret.l4_checksum_data.convert2string() ,UVM_NONE)
        end

        if (flag[0] == 1'b1) begin
            data_index = 0;
            ret.l3_checksum_data.data = new[(l3_size/2)];
            for (int i = 0; i < l3_size; i += 2) begin
                ret.l3_checksum_data.data[data_index] = {<<16{frame.data[(l2_size) + i +: 2]}};
                data_index++;
            end

            // $write("L3 LEN %d\n", l3_size);
            // `uvm_info(this.get_full_name(), ret.l3_checksum_data.convert2string() ,UVM_NONE)
        end

        // `uvm_info(this.get_full_name(), ret.l3_checksum_data.convert2string() ,UVM_NONE)
        // `uvm_info(this.get_full_name(), ret.l4_checksum_data.convert2string() ,UVM_NONE)
        return ret;
    endfunction

    function logic[16-1 : 0] checksum_calc(uvm_logic_vector_array::sequence_item #(16) checksum_data);
        const logic [16-1 : 0] CHCKS_MAX = '1;
        logic [16-1 : 0] ret;
        logic [32-1 : 0] temp_checksum = '0;

        for(int i = 0; i < checksum_data.data.size(); i++) begin
            temp_checksum += checksum_data.data[i];
            // $write("CHSUM DATA: %h\n", checksum_data.data[i]);
            // $write("CHSUM: %h\n", temp_checksum);
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

        uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH) tr_input_mfb;
        uvm_logic_vector::sequence_item #(META_WIDTH)           tr_input_meta;
        uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH)       l3_checksum_mvb;
        uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH)       l4_checksum_mvb;
        uvm_logic_vector::sequence_item #(4)                    flag;
        // uvm_logic_vector::sequence_item #(2)                    bypass;
        uvm_logic_vector::sequence_item #(1)                    l3_bypass;
        uvm_logic_vector::sequence_item #(1)                    l4_bypass;
        logic [7-1 : 0] l2_size = '0;
        logic [9-1 : 0] l3_size = '0;
        int             pkt_cnt = 0;
        checksum        checksum_str;

        forever begin

            input_mfb.get(tr_input_mfb);
            input_meta.get(tr_input_meta);

            pkt_cnt++;
            if (VERBOSITY >= 1) begin
                `uvm_info(this.get_full_name(), tr_input_meta.convert2string() ,UVM_NONE)
                `uvm_info(this.get_full_name(), tr_input_mfb.convert2string() ,UVM_NONE)
            end

            l3_checksum_mvb = uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH)::type_id::create("l3_checksum_mvb");
            l4_checksum_mvb = uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH)::type_id::create("l4_checksum_mvb");
            flag            = uvm_logic_vector::sequence_item #(4)::type_id::create("flag");
            // bypass          = uvm_logic_vector::sequence_item #(2)::type_id::create("bypass");
            l3_bypass          = uvm_logic_vector::sequence_item #(1)::type_id::create("l3_bypass");
            l4_bypass          = uvm_logic_vector::sequence_item #(1)::type_id::create("l4_bypass");

            l2_size   = tr_input_meta.data[7-1  : 0];
            l3_size   = tr_input_meta.data[16-1  : 7];
            flag.data = tr_input_meta.data[20-1  : 16];

            checksum_str         = prepare_checksum_data(tr_input_mfb, l2_size, l3_size, flag.data);
            l3_checksum_mvb.data = checksum_calc(checksum_str.l3_checksum_data);
            l4_checksum_mvb.data = checksum_calc(checksum_str.l4_checksum_data);

            l3_bypass.data = !flag.data[0];// || !flag.data[2];
            l4_bypass.data = !flag.data[1];

            // bypass.data = {!flag.data[1], !flag.data[0]};
            // `uvm_info(this.get_full_name(), l3_checksum_mvb.convert2string() ,UVM_NONE)
            // `uvm_info(this.get_full_name(), l4_checksum_mvb.convert2string() ,UVM_NONE)
            // `uvm_info(this.get_full_name(), l3_bypass.convert2string() ,UVM_NONE)
            // `uvm_info(this.get_full_name(), l4_bypass.convert2string() ,UVM_NONE)

            // out_bypass.write(bypass);
            out_l3_bypass.write(l3_bypass);
            out_l4_bypass.write(l4_bypass);
            out_l3_checksum_mvb.write(l3_checksum_mvb);
            out_l4_checksum_mvb.write(l4_checksum_mvb);
        end

    endtask
endclass
