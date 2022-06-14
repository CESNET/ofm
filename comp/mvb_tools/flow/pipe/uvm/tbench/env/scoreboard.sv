//-- scoreboard.sv: Scoreboard for verification
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

class scoreboard #(ITEM_WIDTH) extends uvm_scoreboard;

    `uvm_component_utils(uvm_pipe::scoreboard #(ITEM_WIDTH))
    // Analysis components.
    uvm_analysis_export #(uvm_logic_vector::sequence_item#(ITEM_WIDTH)) analysis_imp_mvb_rx;
    uvm_analysis_export #(uvm_logic_vector::sequence_item#(ITEM_WIDTH)) analysis_imp_mvb_tx;

    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item#(ITEM_WIDTH)) rx_fifo;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item#(ITEM_WIDTH)) tx_fifo;

    local int unsigned compared = 0;
    local int unsigned errors   = 0;


    // Contructor of scoreboard.
    function new(string name, uvm_component parent);
        super.new(name, parent);
        analysis_imp_mvb_rx = new("analysis_imp_mvb_rx", this);
        analysis_imp_mvb_tx = new("analysis_imp_mvb_tx", this);
        rx_fifo = new("rx_fifo", this);
        tx_fifo = new("tx_fifo", this);
    endfunction

    function int unsigned used();
        int unsigned ret = 0;
        ret |= (rx_fifo.used() != 0);
        ret |= (tx_fifo.used() != 0);
        return ret;
    endfunction


    function void connect_phase(uvm_phase phase);
        analysis_imp_mvb_rx.connect(rx_fifo.analysis_export);
        analysis_imp_mvb_tx.connect(tx_fifo.analysis_export);
    endfunction


    task run_phase(uvm_phase phase);
        string msg;
        uvm_logic_vector::sequence_item#(ITEM_WIDTH) tr_model;
        uvm_logic_vector::sequence_item#(ITEM_WIDTH) tr_dut;

        forever begin
            rx_fifo.get(tr_model);
            tx_fifo.get(tr_dut);

            compared++;
            if (tr_model.compare(tr_dut) == 0) begin
                errors++;
                $swrite(msg, "\nTransactions doesnt match\n\tMODEL Transaction\n%s\n\n\tDUT Transaction\n%s", tr_model.convert2string(), tr_dut.convert2string());
            end
        end
    endtask

    virtual function void report_phase(uvm_phase phase);
        string msg = "\n";
        $swrite(msg, "%sCompared/errors: %0d/%0d \n", msg, compared, errors);
        $swrite(msg, "%sCount of items inside RX fifo: %d \n", msg, rx_fifo.used());
        $swrite(msg, "%sCount of items inside TX fifo: %d \n", msg, tx_fifo.used());
        $swrite(msg, "%sErrors : %d \n", msg, errors);

        if (errors == 0 && this.used() == 0) begin
            `uvm_info(get_type_name(), $sformatf("%s\n\n\t---------------------------------------\n\t----     VERIFICATION SUCCESS      ----\n\t---------------------------------------", msg), UVM_NONE)
        end else begin
            `uvm_info(get_type_name(), $sformatf("%s\n\n\t---------------------------------------\n\t----     VERIFICATION FAIL      ----\n\t---------------------------------------", msg), UVM_NONE)
        end

    endfunction

endclass
