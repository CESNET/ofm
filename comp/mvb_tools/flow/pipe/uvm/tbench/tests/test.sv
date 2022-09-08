//-- test.sv: Verification test 
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author:   Daniel Kříž <xkrizd01@vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 


class ex_test extends uvm_test;
    `uvm_component_utils(test::ex_test);

    bit timeout;
    uvm_pipe::env #(ITEMS, ITEM_WIDTH)             m_env;
    uvm_logic_vector::sequence_simple#(ITEM_WIDTH) h_seq_rx;
    uvm_mvb::sequence_lib_tx#(ITEMS, ITEM_WIDTH)   h_seq_tx;

    // ------------------------------------------------------------------------
    // Functions
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        m_env = uvm_pipe::env #(ITEMS, ITEM_WIDTH)::type_id::create("m_env", this);
    endfunction

    task test_wait_timeout(int unsigned time_length);
        #(time_length*1us);
    endtask

    task test_wait_result();
        do begin
            #(600ns);
        end while (m_env.m_scoreboard.used() != 0);
        timeout = 0;
    endtask

    // ------------------------------------------------------------------------
    // Create environment and Run sequences o their sequencers
    task run_seq_rx(uvm_phase phase);
        phase.raise_objection(this, "Start of rx sequence");

        assert(h_seq_rx.randomize());
        h_seq_rx.start(m_env.rx_env.m_logic_vector_agent.m_sequencer);

        timeout = 1;
        fork
            test_wait_timeout(20);
            test_wait_result();
        join_any;

        phase.drop_objection(this, "End of rx sequence");
    endtask


    task run_seq_tx(uvm_phase phase);
        forever begin
            h_seq_tx.randomize();
            h_seq_tx.start(m_env.tx_env.m_mvb_agent.m_sequencer);
        end
    endtask

    virtual task run_phase(uvm_phase phase);

        h_seq_rx = uvm_logic_vector::sequence_simple#(ITEM_WIDTH)::type_id::create("h_seq_rx");
        h_seq_rx.transaction_count_min = 100000;
        h_seq_rx.transaction_count_max = 250000;

        h_seq_tx = uvm_mvb::sequence_lib_tx #(ITEMS, ITEM_WIDTH)::type_id::create("h_seq_tx");
        h_seq_tx.init_sequence();
        h_seq_tx.cfg.probability_set(60, 100);
        h_seq_tx.min_random_count = 200;
        h_seq_tx.max_random_count = 500;


        fork
            run_seq_tx(phase);
            run_seq_rx(phase);
        join
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info(this.get_full_name(), {"\n\tTEST : ", this.get_type_name(), " END\n"}, UVM_NONE);
        if (timeout) begin
            `uvm_error(this.get_full_name(), "\n\t===================================================\n\tTIMEOUT SOME PACKET STUCK IN DESIGN\n\t===================================================\n\n");
        end
    endfunction
endclass
