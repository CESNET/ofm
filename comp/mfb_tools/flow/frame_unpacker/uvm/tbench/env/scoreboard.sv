// scoreboard.sv: Scoreboard for verification
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


class scoreboard #(HEADER_SIZE, MFB_ITEM_WIDTH, MVB_ITEM_WIDTH, VERBOSITY) extends uvm_scoreboard;
    `uvm_component_param_utils(uvm_superunpacketer::scoreboard #(HEADER_SIZE, MFB_ITEM_WIDTH, MVB_ITEM_WIDTH, VERBOSITY))

    uvm_analysis_export #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))               out_data;
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(HEADER_SIZE+MVB_ITEM_WIDTH))         out_meta;

    uvm_common::subscriber #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))            input_data;
    uvm_common::subscriber #(uvm_logic_vector::sequence_item #(MVB_ITEM_WIDTH))                  input_mvb;

    uvm_common::comparer_ordered #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH))       data_cmp;
    uvm_common::comparer_ordered #(uvm_logic_vector::sequence_item#(HEADER_SIZE+MVB_ITEM_WIDTH)) meta_cmp;

    model #(HEADER_SIZE, MFB_ITEM_WIDTH, MVB_ITEM_WIDTH, VERBOSITY) m_model;

    // Contructor of scoreboard.
    function new(string name, uvm_component parent);
        super.new(name, parent);

        out_data   = new("out_data", this);
        out_meta   = new("out_meta", this);
    endfunction

    function int unsigned success();
        int unsigned ret = 0;
        ret |= data_cmp.success();
        ret |= meta_cmp.success();
        return ret;
    endfunction

    function int unsigned used();
        int unsigned ret = 0;
        ret |= data_cmp.used();
        ret |= meta_cmp.used();
        return ret;
    endfunction

    function void build_phase(uvm_phase phase);

        input_data = uvm_common::subscriber #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))::type_id::create("input_data", this);
        input_mvb  = uvm_common::subscriber #(uvm_logic_vector::sequence_item #(MVB_ITEM_WIDTH))::type_id::create("input_mvb", this);

        data_cmp = uvm_common::comparer_ordered #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH))::type_id::create("data_cmp", this);
        meta_cmp = uvm_common::comparer_ordered #(uvm_logic_vector::sequence_item#(HEADER_SIZE+MVB_ITEM_WIDTH))::type_id::create("meta_cmp", this);

        data_cmp.compared_tr_timeout_set(50us);
        meta_cmp.compared_tr_timeout_set(50us);
        data_cmp.model_tr_timeout_set(1ms);
        meta_cmp.model_tr_timeout_set(1ms);

        m_model = model#(HEADER_SIZE, MFB_ITEM_WIDTH, MVB_ITEM_WIDTH, VERBOSITY)::type_id::create("m_model", this);

        m_model.input_data = uvm_common::fifo_convertor #(uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)))::type_id::create("model_input_data", this);
        m_model.input_mvb = uvm_common::fifo_convertor #(uvm_common::model_item #(uvm_logic_vector::sequence_item #(MVB_ITEM_WIDTH)))::type_id::create("model_input_mvb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        uvm_common::fifo_convertor#(uvm_common::model_item#(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH))) mfb_in;
        uvm_common::fifo_convertor#(uvm_common::model_item#(uvm_logic_vector::sequence_item#(MVB_ITEM_WIDTH))) mvb_in;

        $cast(mfb_in, m_model.input_data);
        input_data.port.connect(mfb_in.analysis_export);
        $cast(mvb_in, m_model.input_mvb);
        input_mvb.port.connect(mvb_in.analysis_export);

        // processed data from the output of the model connected to the analysis fifo
        m_model.out_data.connect(data_cmp.analysis_imp_model);
        m_model.out_meta.connect(meta_cmp.analysis_imp_model);
        // connects the data from the DUT to the analysis fifo
        out_data.connect(data_cmp.analysis_imp_dut);
        out_meta.connect(meta_cmp.analysis_imp_dut);

    endfunction

    function void report_phase(uvm_phase phase);

        if (this.success() && this.used() == 0) begin 
            `uvm_info(get_type_name(), "\n\n\t---------------------------------------\n\t----     VERIFICATION SUCCESS      ----\n\t---------------------------------------", UVM_NONE)
        end else begin
            `uvm_info(get_type_name(), "\n\n\t---------------------------------------\n\t----     VERIFICATION FAILED       ----\n\t---------------------------------------", UVM_NONE)
        end

    endfunction

endclass
