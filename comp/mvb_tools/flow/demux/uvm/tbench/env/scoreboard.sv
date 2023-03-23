//-- scoreboard.sv: Scoreboard for verification
//-- Copyright (C) 2023 CESNET z. s. p. o.
//-- Author:   Oliver Gurka <xgurka00@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

class scoreboard #(ITEM_WIDTH, TX_MVB_CNT) extends uvm_scoreboard;

    `uvm_component_utils(uvm_mvb_demux::scoreboard #(ITEM_WIDTH, TX_MVB_CNT))
    // Analysis components.
    uvm_common::subscriber #(uvm_logic_vector::sequence_item#(ITEM_WIDTH + $clog2(TX_MVB_CNT))) analysis_imp_mvb_rx;
    uvm_analysis_export #(uvm_logic_vector::sequence_item#(ITEM_WIDTH)) analysis_imp_mvb_tx[TX_MVB_CNT - 1 : 0];

    uvm_common::comparer_ordered #(uvm_logic_vector::sequence_item #(ITEM_WIDTH)) port_cmp[TX_MVB_CNT - 1 : 0];
    model#(ITEM_WIDTH, TX_MVB_CNT) m_model;

    // Contructor of scoreboard.
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction // new

    function int unsigned used();
        int unsigned ret = 0;

        for (int i = 0; i < TX_MVB_CNT; i++) begin
            ret |= this.port_cmp[i].used();
            ret |= this.port_cmp[i].errors != 0;
        end
        return ret;
    endfunction // used

    function void build_phase(uvm_phase phase);
        m_model = model #(ITEM_WIDTH, TX_MVB_CNT)::type_id::create("m_model", this);
        analysis_imp_mvb_rx = uvm_common::subscriber #(uvm_logic_vector::sequence_item#(ITEM_WIDTH + $clog2(TX_MVB_CNT)))::type_id::create("analysis_imp_rx", this);

        for (int port = 0; port < TX_MVB_CNT; port ++) begin
            port_cmp[port] = uvm_common::comparer_ordered #(uvm_logic_vector::sequence_item #(ITEM_WIDTH))::type_id::create($sformatf("port_comparer_%0d", port), this);
            analysis_imp_mvb_tx[port] = new($sformatf("analysis_imp_tx_%0d", port), this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        analysis_imp_mvb_rx.port.connect(m_model.model_mvb_in.analysis_export);

        for (int port = 0; port < TX_MVB_CNT; port++) begin
            m_model.model_mvb_out[port].connect(port_cmp[port].analysis_imp_model);
            analysis_imp_mvb_tx[port].connect(port_cmp[port].analysis_imp_dut);
        end
    endfunction // connect_phase

    function void report_phase(uvm_phase phase);
        string msg = "\n";
        int unsigned compared = 0;
        int unsigned errors   = 0;

        for (int port = 0; port < TX_MVB_CNT; port++) begin
            compared = compared + port_cmp[port].compared;
            errors = errors + port_cmp[port].errors;
        end

        $swrite(msg, "%s\tDATA Compared/errors: %0d/%0d\n", msg, compared, errors);

        if (this.used() == 0) begin
            `uvm_info(get_type_name(), $sformatf("%s\n\n\t---------------------------------------\n\t----     VERIFICATION SUCCESS      ----\n\t---------------------------------------", msg), UVM_NONE)
        end else begin
            `uvm_info(get_type_name(), $sformatf("%s\n\n\t---------------------------------------\n\t----     VERIFICATION FAIL      ----\n\t---------------------------------------", msg), UVM_NONE)
        end
    endfunction

endclass
