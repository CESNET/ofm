//-- scoreboard.sv: Scoreboard for verification
//-- Copyright (C) 2023 CESNET z. s. p. o.
//-- Author(s): Yaroslav Marushchenko <xmarus09@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

class scoreboard #(ITEM_WIDTH) extends uvm_scoreboard;
    `uvm_component_utils(uvm_pipe::scoreboard #(ITEM_WIDTH))

    // Analysis components.
    uvm_common::subscriber #(uvm_logic_vector::sequence_item #(ITEM_WIDTH)) analysis_imp_mvb_rx;

    uvm_analysis_export #(uvm_logic_vector::sequence_item #(ITEM_WIDTH)) analysis_imp_mvb_tx;

    uvm_common::comparer_ordered #(uvm_logic_vector::sequence_item #(ITEM_WIDTH)) cmp;

    model #(ITEM_WIDTH) m_model;

    // Contructor of scoreboard.
    function new(string name, uvm_component parent);
        super.new(name, parent);

        analysis_imp_mvb_tx = new("analysis_imp_mvb_tx",  this);

    endfunction

    function int unsigned success();
        int unsigned ret = 0;
        ret |= cmp.success();
        return ret;
    endfunction

    function int unsigned used();
        int unsigned ret = 0;
        ret |= cmp.used();
        return ret;
    endfunction

    function void build_phase(uvm_phase phase);

        analysis_imp_mvb_rx = uvm_common::subscriber #(uvm_logic_vector::sequence_item #(ITEM_WIDTH))::type_id::create("analysis_imp_mvb_rx", this);

        cmp = uvm_common::comparer_ordered #(uvm_logic_vector::sequence_item #(ITEM_WIDTH))::type_id::create("cmp",  this);
        cmp.model_tr_timeout_set(200us);

        m_model = model #(ITEM_WIDTH)::type_id::create("m_model", this);

    endfunction

    function void connect_phase(uvm_phase phase);

        // Connects input data to the input of the models
        analysis_imp_mvb_rx.port.connect(m_model.model_mvb_in.analysis_export);

        // Processed data from the output of the model connected to the analysis fifo
        m_model.model_mvb_out.connect(cmp.analysis_imp_model);

        // Processed data from the output of the DUT connected to the analysis fifo
        analysis_imp_mvb_tx.connect(cmp.analysis_imp_dut);
        
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
