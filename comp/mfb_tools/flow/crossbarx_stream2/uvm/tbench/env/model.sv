// model.sv: Model of implementation
// Copyright (C) 2023 CESNET z. s. p. o.
// Author(s): Jakub Cabal <cabal@cesnet.cz>

// SPDX-License-Identifier: BSD-3-Clause


class model #(RX_MFB_ITEM_W, RX_MVB_ITEM_W, USERMETA_W, MOD_W) extends uvm_component;
    `uvm_component_param_utils(uvm_mfb_crossbarx_stream2::model #(RX_MFB_ITEM_W, RX_MVB_ITEM_W, USERMETA_W, MOD_W))

    uvm_tlm_analysis_fifo #(uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(RX_MFB_ITEM_W)))   input_data;
    uvm_tlm_analysis_fifo #(uvm_common::model_item #(uvm_logic_vector::sequence_item #(USERMETA_W)))            input_meta;
    uvm_tlm_analysis_fifo #(uvm_common::model_item #(uvm_logic_vector::sequence_item #(RX_MVB_ITEM_W)))         input_mvb;
    uvm_analysis_port #(uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(RX_MFB_ITEM_W)))       out_data;
    uvm_analysis_port #(uvm_common::model_item #(uvm_logic_vector::sequence_item #(USERMETA_W)))                out_meta;

    protected int unsigned transactions;

    function new(string name = "model", uvm_component parent = null);
        super.new(name, parent);

        input_data   = new("input_data", this);
        input_meta   = new("input_meta", this);
        input_mvb    = new("input_mvb", this);
        out_data     = new("out_data", this);
        out_meta     = new("out_meta", this);
        transactions = 0;

    endfunction

    task run_phase(uvm_phase phase);

        uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(RX_MFB_ITEM_W)) tr_input_data;
        uvm_common::model_item #(uvm_logic_vector::sequence_item #(USERMETA_W))          tr_input_meta;
        uvm_common::model_item #(uvm_logic_vector::sequence_item #(RX_MVB_ITEM_W))       tr_input_mvb;
        uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(RX_MFB_ITEM_W)) tr_output_data;
        uvm_common::model_item #(uvm_logic_vector::sequence_item #(USERMETA_W))          tr_output_meta;

        string str = "";
        logic mod_discard;
        logic mod_sof_en;
        logic mod_sof_type;
        int mod_sof_size;
        logic mod_eof_en;
        logic mod_eof_type;
        int mod_eof_size;
        int mfb_orig_size;
        int mfb_new_size;
        int mod_sof_trim;
        int mod_sof_extend;

        forever begin

            input_data.get(tr_input_data);
            //input_meta.get(tr_input_meta);
            input_mvb.get(tr_input_mvb);

            tr_output_data      = uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(RX_MFB_ITEM_W))::type_id::create("tr_output_data");
            tr_output_data.item = uvm_logic_vector_array::sequence_item #(RX_MFB_ITEM_W)::type_id::create("tr_output_data_item");
            tr_output_meta      = uvm_common::model_item #(uvm_logic_vector::sequence_item #(USERMETA_W))::type_id::create("tr_output_data");
            tr_output_meta.item = uvm_logic_vector::sequence_item #(USERMETA_W)::type_id::create("tr_output_data_item");

            // send usermeta to output
            tr_output_meta.item.data = tr_input_mvb.item.data[USERMETA_W-1 -: USERMETA_W];
            // get mod instructions
            mod_discard  = tr_input_mvb.item.data[USERMETA_W];
            mod_sof_size = tr_input_mvb.item.data[USERMETA_W+1+MOD_W-1 -: MOD_W];
            mod_sof_en   = tr_input_mvb.item.data[USERMETA_W+1+MOD_W];
            mod_sof_type = tr_input_mvb.item.data[USERMETA_W+MOD_W+2];
            mod_eof_size = tr_input_mvb.item.data[USERMETA_W+MOD_W+3+MOD_W-1 -: MOD_W];
            mod_eof_en   = tr_input_mvb.item.data[USERMETA_W+MOD_W+3+MOD_W];
            mod_eof_type = tr_input_mvb.item.data[USERMETA_W+MOD_W+3+MOD_W+1];

            if (mod_sof_en == 0) begin
                mod_sof_size = 0;
            end

            if (mod_eof_en == 0) begin
                mod_eof_size = 0;
            end

            mfb_orig_size = tr_input_data.item.data.size();
            mod_sof_trim = 0;
            mod_sof_extend = 0;

            mfb_new_size = mfb_orig_size;
            if (mod_sof_type == 1) begin
                mfb_new_size = mfb_new_size - mod_sof_size;
            end else begin
                mfb_new_size = mfb_new_size + mod_sof_size;
            end
            if (mod_eof_type == 1) begin
                mfb_new_size = mfb_new_size - mod_eof_size;
            end else begin
                mfb_new_size = mfb_new_size + mod_eof_size;
            end

            if (mod_sof_type == 0) begin
                mod_sof_extend = mod_sof_size;
            end
            if (mod_sof_type == 1) begin
                mod_sof_trim = mod_sof_size;
            end

            tr_output_data.item = new();
            tr_output_data.item.data = new[mfb_new_size];

            for (int i = mod_sof_trim; i < mfb_orig_size; i++) begin
                tr_output_data.item.data[i-mod_sof_trim+mod_sof_extend] = tr_input_data.item.data[i];
            end
            tr_output_meta.item.data = tr_input_mvb.item.data[USERMETA_W-1 -: USERMETA_W];

            if (mod_discard == 0) begin
                out_data.write(tr_output_data);
                out_meta.write(tr_output_meta);
            end

            transactions++;
            $swrite(str, "\n======= MODEL: Transaction %0d =======", transactions);
            $swrite(str, "%s\nDISCARD: %0b", str, mod_discard);
            $swrite(str, "%s\nMOD SOF size: %0d", str, mod_sof_size);
            $swrite(str, "%s\nMOD SOF type: %0b", str, mod_sof_type);
            $swrite(str, "%s\nMOD EOF size: %0d", str, mod_eof_size);
            $swrite(str, "%s\nMOD EOF type: %0b", str, mod_eof_type);
            $swrite(str, "%s\nORIG size: %0d", str, mfb_orig_size);
            $swrite(str, "%s\nNEW size: %0d", str, mfb_new_size);
            $swrite(str, "%s\nsof_extend: %0d", str, mod_sof_extend);
            $swrite(str, "%s\nsof_trim: %0d", str, mod_sof_trim);
            `uvm_info(this.get_full_name(), str, UVM_MEDIUM)
            `uvm_info(this.get_full_name(), tr_input_data.convert2string(), UVM_MEDIUM)
            `uvm_info(this.get_full_name(), tr_output_data.convert2string(), UVM_MEDIUM)
            `uvm_info(this.get_full_name(), tr_output_meta.convert2string(), UVM_MEDIUM)

        end

    endtask
endclass
