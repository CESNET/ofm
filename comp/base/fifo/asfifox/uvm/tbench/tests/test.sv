//-- test.sv: Verification test 
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 


class ex_test extends uvm_test;
    `uvm_component_utils(test::ex_test);

    env::env_base #(ITEMS, ITEM_WIDTH) m_env;
    mvb::sequence_simple_rx #(ITEMS, ITEM_WIDTH)h_seq_rx;
    mvb::sequence_simple_tx #(ITEMS, ITEM_WIDTH)h_seq_tx;
    
    // ------------------------------------------------------------------------
    // Functions
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        m_env = env::env_base #(ITEMS, ITEM_WIDTH)::type_id::create("m_env", this);
    endfunction

    // ------------------------------------------------------------------------
    // Create environment and Run sequences o their sequencers
    task run_seq_rx(uvm_phase phase);
        phase.raise_objection(this, "Start of rx sequence");
        h_seq_rx.start(m_env.agent_rx.m_sequencer);
        phase.drop_objection(this, "End of rx sequence");
    endtask

    virtual task run_phase(uvm_phase phase);
        h_seq_rx = mvb::sequence_simple_rx #(ITEMS, ITEM_WIDTH)::type_id::create("h_seq_rx");
        h_seq_rx.randomize();

        h_seq_tx = mvb::sequence_simple_tx #(ITEMS, ITEM_WIDTH)::type_id::create("h_seq_tx");
        h_seq_tx.randomize();
        
        phase.phase_done.set_drain_time(this, FIFO_ITEMS*RX_CLK_PERIOD);
        
        fork
            h_seq_tx.start(m_env.agent_tx.m_sequencer);
            run_seq_rx(phase); 
        join

    endtask

endclass
