//-- scoreboard.sv: Scoreboard for verification
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 


// Scoreboard. Check if DUT implementation is correct.
class mvb_converter#(ITEM_WIDTH) extends uvm_subscriber#(mvb::sequence_item #(1, ITEM_WIDTH));
    `uvm_component_param_utils(env::mvb_converter#(ITEM_WIDTH))

    uvm_analysis_port #(logic_vector::sequence_item#(ITEM_WIDTH)) analysis_port;

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
        analysis_port = new("analysis port", this);
    endfunction

    function void write(mvb::sequence_item #(1, ITEM_WIDTH) t);
        logic_vector::sequence_item#(ITEM_WIDTH) tr_out;

        if(t.src_rdy && t.dst_rdy) begin
            for (int unsigned it = 0; it < 1; it++) begin
                if (t.vld[it] == 1) begin
                    tr_out = logic_vector::sequence_item#(ITEM_WIDTH)::type_id::create("tr_out", this);
                    tr_out.data = t.data[it];
                    analysis_port.write(tr_out);
                end
            end
        end
    endfunction
endclass


class scoreboard #(ITEM_WIDTH) extends uvm_scoreboard;

    `uvm_component_utils(env::scoreboard #(ITEM_WIDTH))
    // Analysis components.
    uvm_analysis_export #(mvb::sequence_item #(1, ITEM_WIDTH)) analysis_imp_mvb_rx;
    uvm_analysis_export #(mvb::sequence_item #(1, ITEM_WIDTH)) analysis_imp_mvb_tx;

    local uvm_tlm_analysis_fifo #(logic_vector::sequence_item#(ITEM_WIDTH)) rx_fifo;
    local uvm_tlm_analysis_fifo #(logic_vector::sequence_item#(ITEM_WIDTH)) tx_fifo;

    //uvm_tlm_analysis_fifo #(mvb::sequence_item #(1, ITEM_WIDTH)) analysis_imp_mvb_rx;
    //uvm_tlm_analysis_fifo #(mvb::sequence_item #(1, ITEM_WIDTH)) analysis_imp_mvb_tx;

    local mvb_converter#(ITEM_WIDTH) mvb_converter_rx;
    local mvb_converter#(ITEM_WIDTH) mvb_converter_tx;
    //model m_model;
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

    function void build_phase(uvm_phase phase);
        mvb_converter_rx = mvb_converter#(ITEM_WIDTH)::type_id::create("mvb_converter_rx", this);
        mvb_converter_tx = mvb_converter#(ITEM_WIDTH)::type_id::create("mvb_converter_tx", this);
    endfunction


    function void connect_phase(uvm_phase phase);
        analysis_imp_mvb_rx.connect(mvb_converter_rx.analysis_export);
        analysis_imp_mvb_tx.connect(mvb_converter_tx.analysis_export);

        mvb_converter_rx.analysis_port.connect(rx_fifo.analysis_export);
        mvb_converter_tx.analysis_port.connect(tx_fifo.analysis_export);
    endfunction


    task run_phase(uvm_phase phase);
        string msg;
        logic_vector::sequence_item#(ITEM_WIDTH) tr_model;
        logic_vector::sequence_item#(ITEM_WIDTH) tr_dut;

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
        $swrite(msg, "%sCount of items inside fifo: %d \n", msg, rx_fifo.used());
        $swrite(msg, "%sErrors : %d \n", msg, errors);

        if (errors == 0 && this.used() == 0) begin
            `uvm_info(get_type_name(), $sformatf("%s\n\n\t---------------------------------------\n\t----     VERIFICATION SUCCESS      ----\n\t---------------------------------------", msg), UVM_NONE)
        end else begin
            `uvm_info(get_type_name(), $sformatf("%s\n\n\t---------------------------------------\n\t----     VERIFICATION FAIL      ----\n\t---------------------------------------", msg), UVM_NONE)
        end

    endfunction

endclass
