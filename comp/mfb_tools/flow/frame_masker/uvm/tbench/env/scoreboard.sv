// scoreboard.sv: Scoreboard for verification
// Copyright (C) 2023 CESNET z. s. p. o.
// Author(s): Yaroslav Marushchenko <xmarus09@stud.fit.vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


class scoreboard #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH, USE_PIPE) extends uvm_scoreboard;
    `uvm_component_param_utils(frame_masker::scoreboard #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH, USE_PIPE))

    uvm_analysis_export #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)) out_data;
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(MFB_META_WIDTH))       out_meta;

    uvm_common::comparer_ordered #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)) data_cmp;
    uvm_common::comparer_ordered #(uvm_logic_vector::sequence_item #(MFB_META_WIDTH))       meta_cmp;

    uvm_analysis_export    #(uvm_mfb::sequence_item #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH)) analysis_imp_mfb_data;
    uvm_common::subscriber #(uvm_logic_vector::sequence_item #(MFB_META_WIDTH))                                                      analysis_imp_mfb_meta;
    uvm_analysis_export    #(uvm_mvb::sequence_item #(MFB_REGIONS, 1))                                                               analysis_imp_mvb_data;

    model #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH, USE_PIPE) m_model;

    uvm_logic_vector_array_mfb::monitor_logic_vector_array #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH) m_data_monitor;
    uvm_logic_vector_array_mfb::monitor_logic_vector       #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH) m_meta_monitor;
    uvm_common::subscriber                                 #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))                      m_data_subscriber;
    uvm_common::subscriber                                 #(uvm_logic_vector::sequence_item #(MFB_META_WIDTH))                            m_meta_subscriber;

    // Contructor of scoreboard.
    function new(string name, uvm_component parent);
        super.new(name, parent);

        analysis_imp_mfb_data = new("analysis_imp_mfb_data", this);
        analysis_imp_mvb_data = new("analysis_imp_mvb_data", this);

        out_data = new("out_data", this);
        out_meta = new("out_meta", this);

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
        ret |= m_model.input_data.used();
        ret |= m_model.input_mvb.used();
        return ret;
    endfunction


    function void build_phase(uvm_phase phase);
        m_data_monitor    = uvm_logic_vector_array_mfb::monitor_logic_vector_array #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH)::type_id::create("m_data_monitor",    this);
        m_meta_monitor    = uvm_logic_vector_array_mfb::monitor_logic_vector       #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH)::type_id::create("m_meta_monitor",    this);
        m_data_subscriber = uvm_common::subscriber                                 #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))                     ::type_id::create("m_data_subscriber", this);
        m_meta_subscriber = uvm_common::subscriber                                 #(uvm_logic_vector::sequence_item #(MFB_META_WIDTH))                           ::type_id::create("m_meta_subscriber", this);

        m_model = model #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH, USE_PIPE)::type_id::create("m_model", this);

        analysis_imp_mfb_meta = uvm_common::subscriber #(uvm_logic_vector::sequence_item #(MFB_META_WIDTH))::type_id::create("analysis_imp_mfb_meta", this);

        data_cmp = uvm_common::comparer_ordered #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))::type_id::create("data_cmp", this);
        meta_cmp = uvm_common::comparer_ordered #(uvm_logic_vector::sequence_item #(MFB_META_WIDTH))      ::type_id::create("meta_cmp", this);

        data_cmp.model_tr_timeout_set(200us);
        meta_cmp.model_tr_timeout_set(200us);
    endfunction

    function void connect_phase(uvm_phase phase);
        m_model.out_data.connect(m_data_monitor.analysis_export);
        m_model.out_data.connect(m_meta_monitor.analysis_export);
        m_data_monitor.analysis_port.connect(m_data_subscriber.analysis_export);
        m_meta_monitor.analysis_port.connect(m_meta_subscriber.analysis_export);

        // connects input data to the input of the model
        analysis_imp_mfb_data.connect(m_model.input_data.analysis_export);
        analysis_imp_mvb_data.connect(m_model.input_mvb.analysis_export);

        // processed data from the output of the model connected to the analysis fifo
        m_data_subscriber.port.connect(data_cmp.analysis_imp_model);
        m_meta_subscriber.port.connect(meta_cmp.analysis_imp_model);

        // connects the data from the DUT to the analysis fifo
        out_data.connect(data_cmp.analysis_imp_dut);
        out_meta.connect(meta_cmp.analysis_imp_dut);

    endfunction

    function void report_phase(uvm_phase phase);
        string msg = "\n";

        if (this.success() && this.used() == 0) begin 
            `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION SUCCESS      ----\n\t---------------------------------------"}, UVM_NONE)
        end else begin
            `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION FAILED       ----\n\t---------------------------------------"}, UVM_NONE)
        end

    endfunction

endclass
