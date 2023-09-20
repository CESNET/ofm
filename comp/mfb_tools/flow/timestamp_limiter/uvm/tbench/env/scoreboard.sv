// scoreboard.sv: Scoreboard for verification
// Copyright (C) 2023 CESNET z. s. p. o.
// Author(s): Daniel Kříž <danielkriz@cesnet.cz>

// SPDX-License-Identifier: BSD-3-Clause


class scoreboard #(MFB_ITEM_WIDTH, RX_MFB_META_WIDTH, TX_MFB_META_WIDTH, TIMESTAMP_WIDTH, QUEUES, TIMESTAMP_FORMAT) extends uvm_scoreboard;
    `uvm_component_param_utils(uvm_timestamp_limiter::scoreboard #(MFB_ITEM_WIDTH, RX_MFB_META_WIDTH, TX_MFB_META_WIDTH, TIMESTAMP_WIDTH, QUEUES, TIMESTAMP_FORMAT))

    uvm_analysis_export #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)) out_data;
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(TX_MFB_META_WIDTH))    out_meta;

    uvm_timestamp_limiter::delayer_cmp #(MFB_ITEM_WIDTH, TIMESTAMP_WIDTH)               data_cmp;
    uvm_common::comparer_taged #(uvm_logic_vector::sequence_item#(TX_MFB_META_WIDTH)) meta_cmp;

    uvm_common::subscriber #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH)) analysis_imp_mfb_data;
    uvm_common::subscriber #(uvm_logic_vector::sequence_item#(RX_MFB_META_WIDTH))    analysis_imp_mfb_meta;

    model #(MFB_ITEM_WIDTH, RX_MFB_META_WIDTH, TX_MFB_META_WIDTH, TIMESTAMP_WIDTH, QUEUES, TIMESTAMP_FORMAT) m_model;

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
        m_model = model#(MFB_ITEM_WIDTH, RX_MFB_META_WIDTH, TX_MFB_META_WIDTH, TIMESTAMP_WIDTH, QUEUES, TIMESTAMP_FORMAT)::type_id::create("m_model", this);

        analysis_imp_mfb_data = uvm_common::subscriber #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH))::type_id::create("analysis_imp_mfb_data", this);
        analysis_imp_mfb_meta = uvm_common::subscriber #(uvm_logic_vector::sequence_item#(RX_MFB_META_WIDTH))::type_id::create("analysis_imp_mfb_meta", this);

        data_cmp = uvm_timestamp_limiter::delayer_cmp #(MFB_ITEM_WIDTH, TIMESTAMP_WIDTH)::type_id::create("data_cmp", this);
        meta_cmp = uvm_common::comparer_taged #(uvm_logic_vector::sequence_item#(TX_MFB_META_WIDTH))::type_id::create("meta_cmp", this);
    endfunction

    function void connect_phase(uvm_phase phase);

        // connects input data to the input of the model
        analysis_imp_mfb_data.port.connect(m_model.input_data.analysis_export);
        analysis_imp_mfb_meta.port.connect(m_model.input_meta.analysis_export);

        // processed data from the output of the model connected to the analysis fifo
        m_model.out_data.connect(data_cmp.analysis_imp_model);
        m_model.out_meta.connect(meta_cmp.analysis_imp_model);
        // connects the data from the DUT to the analysis fifo
        out_data.connect(data_cmp.analysis_imp_dut);
        out_meta.connect(meta_cmp.analysis_imp_dut);

    endfunction

    function void report_phase(uvm_phase phase);
        string msg = "\n";

        $swrite(msg, "%s\n\DATA info %s", msg, data_cmp.info());
        // $swrite(msg, "%s\n\tMETA info %s", msg, meta_cmp.info());

        if (this.success() && this.used() == 0) begin 
            `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION SUCCESS      ----\n\t---------------------------------------"}, UVM_NONE)
        end else begin
            `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION FAILED       ----\n\t---------------------------------------"}, UVM_NONE)
        end

    endfunction

endclass
