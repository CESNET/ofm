/*
 * file       : sequence.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: sequence simple
 * date       : 2021
 * author     : Radek Iša <isa@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/

class seq_small_pkt extends byte_array::sequence_simple;
    `uvm_object_utils(mac_seq_rx_ver::seq_small_pkt)
    function new(string name="seq_small_pkt");
        super.new(name);
        data_size_max = 128;
        data_size_min = 12;
        transaction_count_min = 1;
        transaction_count_max = 20;
        
    endfunction
endclass

class sequence_lib extends byte_array::sequence_lib;
  `uvm_object_utils(mac_seq_rx_ver::sequence_lib)
  `uvm_sequence_library_utils(mac_seq_rx_ver::sequence_lib)

    function new(string name = "");
        super.new(name);
        init_sequence_library();
    endfunction

    // subclass can redefine and change run sequences
    // can be useful in specific tests
    virtual function void init_sequence();
        super.init_sequence();
        this.add_sequence(seq_small_pkt::get_type());
    endfunction
endclass

class sequence_error#(LOGIC_WIDTH) extends logic_vector::sequence_simple#(LOGIC_WIDTH);
    `uvm_object_param_utils(mac_seq_rx_ver::sequence_error#(LOGIC_WIDTH))

	function new (string name = "");
		super.new(name);
	endfunction

    task body;
        repeat(transaction_count)
        begin
            // Generate random request
            `uvm_do_with(req, { data dist {0 :/ 10, [0:2**LOGIC_WIDTH-1] :/ 1};})
        end
    endtask
endclass

class sequence_simple_1 extends uvm_sequence;
    `uvm_object_utils(mac_seq_rx_ver::sequence_simple_1)
    `uvm_declare_p_sequencer(mac_seq_rx_ver::sequencer);

    localparam LOGIC_WIDTH = 6;

    //////////////////////////////////
    // variables
    uvm_sequence #(byte_array::sequence_item)   rx_packet;
    logic_vector::sequence_simple#(LOGIC_WIDTH) rx_error;
    uvm_sequence#(reset::sequence_item)         reset_seq;

    //////////////////////////////////
    // functions
    function new (string name = "");
        super.new(name);
    endfunction

    virtual function void seq_create();
		mac_seq_rx_ver::sequence_lib rx_packet_lib;

        rx_packet_lib = mac_seq_rx_ver::sequence_lib::type_id::create("seq_data");
        rx_packet_lib.init_sequence();
        rx_packet_lib.min_random_count = 100;
        rx_packet_lib.max_random_count = 200;

        rx_error  = sequence_error#(LOGIC_WIDTH)::type_id::create("avalon_rx_seq_base");
        reset_seq = reset::sequence_start::type_id::create("reset_simple");

		rx_packet = rx_packet_lib;
	endfunction

    task error_rx();
        forever begin
            rx_error.randomize();
            rx_error.start(p_sequencer.rx_error);
        end

    endtask

    task reset();
        forever  begin
            reset_seq.randomize();
            reset_seq.start(p_sequencer.reset);
        end
    endtask

    //////////////////////////////
    //run all sequences paralelly
    task body;
        fork
            reset();
            error_rx();
        join_none

        assert(rx_packet.randomize());
        rx_packet.start(p_sequencer.rx_packet);
    endtask
endclass
