// scoreboard.sv: Scoreboard for verification
// Copyright (C) 2024 CESNET z. s. p. o.
// Author:   David Beneš <xbenes52@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause

class scoreboard #(MVB_ITEM_WIDTH, MFB_ITEM_WIDTH, RX_CHANNELS, USR_RX_PKT_SIZE_MAX) extends uvm_scoreboard;

    `uvm_component_utils(uvm_framepacker::scoreboard #(MVB_ITEM_WIDTH, MFB_ITEM_WIDTH, RX_CHANNELS, USR_RX_PKT_SIZE_MAX))

    //Anylysis components
    uvm_analysis_export #(uvm_logic_vector::sequence_item#(MVB_ITEM_WIDTH)) analysis_imp_mvb_rx;
    // uvm_analysis_export #(uvm_logic_vector::sequence_item#(MVB_ITEM_WIDTH)) analysis_imp_mvb_tx;

    //Model Data - SmallPackets
    uvm_common::subscriber #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH))        analysis_imp_mfb_rx_data;

    //DUT Data - SuperPackets
    uvm_common::subscriber #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH))        analysis_imp_mfb_tx_data;

    // uvm_common::subscriber #()

    //MVB
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(MVB_ITEM_WIDTH))                analysis_imp_mvb_tx;

    //Comparer
    //uvm_common::comparer_ordered #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH))  data_cmp;
    uvm_framepacker::comparer_superpacket #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)) data_cmp;

    //Speed-meter
    meter #(MVB_ITEM_WIDTH, MFB_ITEM_WIDTH, RX_CHANNELS, USR_RX_PKT_SIZE_MAX) m_meter;

    //Model
    model #(MVB_ITEM_WIDTH, MFB_ITEM_WIDTH, RX_CHANNELS) m_model;

    // Contructor
    function new(string name, uvm_component parent);
        super.new(name, parent);

        analysis_imp_mvb_rx = new("analysis_imp_mvb_rx", this);
        analysis_imp_mvb_tx = new("analysis_imp_mvb_tx", this);

    endfunction

    function int unsigned success();
        int unsigned ret = 0;
        ret |= data_cmp.success();
        return ret;
    endfunction

    function int unsigned used();
        int unsigned ret = 0;
        ret |= data_cmp.used();
        ret |= m_model.used();
        return ret;
    endfunction

    function void build_phase(uvm_phase phase);
        m_model = model #(MVB_ITEM_WIDTH, MFB_ITEM_WIDTH, RX_CHANNELS)::type_id::create("m_model", this);
        m_meter = meter #(MVB_ITEM_WIDTH, MFB_ITEM_WIDTH, RX_CHANNELS, USR_RX_PKT_SIZE_MAX)::type_id::create("m_meter", this);

        analysis_imp_mfb_rx_data = uvm_common::subscriber #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH))::type_id::create("analysis_imp_mfb_rx_data", this);
        analysis_imp_mfb_tx_data = uvm_common::subscriber # (uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH))::type_id::create("analysis_imp_mfb_tx_data", this);

        //data_cmp = uvm_common::comparer_ordered #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH))::type_id::create("data_cmp", this);

        data_cmp = uvm_framepacker::comparer_superpacket #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH))::type_id::create("data_cmp", this);
        data_cmp.model_tr_timeout_set(500us);

    endfunction

    function void connect_phase(uvm_phase phase);
        //Input of model
        analysis_imp_mfb_rx_data.port.connect(m_model.data_in.analysis_export);
        analysis_imp_mvb_rx.connect(m_model.meta_in.analysis_export);

        //Speed-meter
        analysis_imp_mfb_rx_data.port.connect(m_meter.rx_data_in.analysis_export);
        analysis_imp_mfb_tx_data.port.connect(m_meter.tx_data_in.analysis_export);

        //MVB
        analysis_imp_mfb_tx_data.port.connect(m_meter.mfb_control_data.analysis_export);
        analysis_imp_mvb_tx.connect(m_meter.meta_in.analysis_export);

        //Connect model output to comparer
        m_model.data_out.connect(data_cmp.analysis_imp_model);


    endfunction

    virtual function void report_phase(uvm_phase phase);

        if (this.success() && this.used() == 0) begin 
            `uvm_info(get_type_name(), $sformatf("\n\n\t---------------------------------------\n\t----     VERIFICATION SUCCESS      ----\n\t---------------------------------------"), UVM_NONE)
        end else begin
            `uvm_info(get_type_name(), $sformatf("\n\n\t---------------------------------------\n\t----     VERIFICATION FAIL      ----\n\t---------------------------------------"), UVM_NONE)
        end

    endfunction
endclass
