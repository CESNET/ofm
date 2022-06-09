/*
 * file       : base.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: base test
 * date       : 2021
 * author     : Radek Iša <isa@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/

class sequence_base #(REGIONS, REGION_SIZE) extends uvm_byte_array_mfb::sequence_simple_rx #(REGIONS, REGION_SIZE,  8, 1);
    `uvm_object_param_utils(sequence_base #(REGIONS, REGION_SIZE))

    function new (string name = "req");
        uvm_common::rdy_bounds bounds_arr[1];

        super.new(name);
        hl_transactions_min = 100;
        hl_transactions_max = 500;
        bounds_arr[0] = uvm_common::rdy_bounds_full::new();
        rdy_rdy       = uvm_common::rand_rdy_rand::new(bounds_arr);
     endfunction
endclass


class test_seq#(REGIONS, REGION_SIZE) extends uvm_byte_array_mfb::sequence_lib_rx#(REGIONS, REGION_SIZE,  8, 1);
  `uvm_object_param_utils(test_seq#(REGIONS, REGION_SIZE))
  `uvm_sequence_library_utils(test_seq#(REGIONS, REGION_SIZE))

  function new(string name = "");
    super.new(name);
    init_sequence_library();
  endfunction


  virtual function void init_sequence();
        this.add_sequence(uvm_byte_array_mfb::sequence_full_speed_rx #(REGIONS, REGION_SIZE, 8, 1)::get_type());
        this.add_sequence(sequence_base #(REGIONS, REGION_SIZE)::get_type());
        this.add_sequence(uvm_byte_array_mfb::sequence_stop_rx #(REGIONS, REGION_SIZE, 8, 1)::get_type());
    endfunction
endclass


class base extends uvm_test;
    `uvm_component_utils(test::base);

    /////////////////////
    // variables
    uvm_mac_seg_tx::env#(SEGMENTS, REGIONS, REGION_SIZE) m_env;

    /////////////////////
    // functions
    function new(string name, uvm_component parent);
            super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        uvm_byte_array_mfb::sequence_lib_rx#(REGIONS, REGION_SIZE,  8, 1)::type_id::set_inst_override(test_seq#(REGIONS, REGION_SIZE)::get_type(), {this.get_full_name() ,".m_env.*"});

        m_env = uvm_mac_seg_tx::env#(SEGMENTS, REGIONS, REGION_SIZE)::type_id::create("m_env", this);
    endfunction

    //run virtual sequence on virtual sequencer
    virtual task run_phase(uvm_phase phase);
        uvm_mac_seg_tx::sequence_simple_1#(SEGMENTS) seq;

        uvm_component c;
        c = uvm_root::get();
        c.set_report_id_action_hier("ILLEGALNAME", UVM_NO_ACTION);

        phase.raise_objection(this);

        seq = uvm_mac_seg_tx::sequence_simple_1#(SEGMENTS)::type_id::create("seq");
        seq.seq_create();
        seq.randomize();
        seq.start(m_env.m_sequencer);

        phase.drop_objection(this);
    endtask

endclass

