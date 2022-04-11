/*
 * file       : base.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: base test
 * date       : 2021
 * author     : Radek Iša <isa@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/

class base extends uvm_test;
    `uvm_component_utils(test::base);

    /////////////////////
    // variables
    mac_seq_rx_ver::env#(SEGMENTS, REGIONS, REGION_SIZE) m_env;
    bit   timeout;

    /////////////////////
    // functions
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        m_env = mac_seq_rx_ver::env#(SEGMENTS, REGIONS, REGION_SIZE)::type_id::create("m_env", this);
    endfunction

    task test_wait_timeout(int unsigned time_length);
        #(time_length*1us);
    endtask

    task test_wait_result();
        do begin
            #(600ns);
        end while (m_env.sc.used() != 0);
        timeout = 0;
    endtask

    //run virtual sequence on virtual sequencer
    virtual task run_phase(uvm_phase phase);
        mac_seq_rx_ver::sequence_simple_1 seq;

        uvm_component c;
        c = uvm_root::get();
        c.set_report_id_action_hier("ILLEGALNAME", UVM_NO_ACTION);


        phase.raise_objection(this);

        seq = mac_seq_rx_ver::sequence_simple_1::type_id::create("seq");
        seq.seq_create();
        seq.randomize();
        seq.start(m_env.m_sequencer);

        timeout = 1;
        fork
            test_wait_timeout(20);
            test_wait_result();
        join_any;

        phase.drop_objection(this);
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info(this.get_full_name(), {"\n\tTEST : ", this.get_type_name(), " END\n"}, UVM_NONE);
        if (timeout) begin
            `uvm_error(this.get_full_name(), "\n\t===================================================\n\tTIMEOUT SOME PACKET STUCK IN DESIGN\n\t===================================================\n\n");
        end
    endfunction
endclass

