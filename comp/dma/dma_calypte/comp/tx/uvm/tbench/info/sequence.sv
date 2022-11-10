//-- sequence.sv
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause


// Reusable high level sequence. Contains transaction, which has only data part.
class sequence_simple#(CHANNELS) extends uvm_sequence #(sequence_item);
    `uvm_object_param_utils(uvm_dma_ll_info::sequence_simple#(CHANNELS))

    rand int unsigned transaction_count;
    int unsigned transaction_count_min = 10;
    int unsigned transaction_count_max = 100;
    uvm_common::rand_length   rdy_length;

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}

    // Constructor - creates new instance of this class
    function new(string name = "sequence_simple");
        super.new(name);
        rdy_length = uvm_common::rand_length_rand::new();
    endfunction

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "uvm_dma_ll_info::sequence_simple is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            int unsigned channel_next;

            void'(rdy_length.randomize());
            channel_next = rdy_length.m_value % CHANNELS;
            // Generate random request, which must be in interval from min length to max length
            `uvm_do_with(req, {channel == channel_next; });
        end
    endtask
endclass

class sequence_simple_rand#(CHANNELS) extends uvm_sequence #(sequence_item);
    `uvm_object_param_utils(uvm_dma_ll_info::sequence_simple_rand#(CHANNELS))

    rand int unsigned transaction_count;
    int unsigned transaction_count_min = 10;
    int unsigned transaction_count_max = 100;
    rand int unsigned channel_max; // 2048
    rand int unsigned channel_min;

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}
    constraint channel_num_c {channel_min inside {[0 : CHANNELS]}; channel_max inside {[0 : CHANNELS]}; channel_min <= channel_max;}

    // Constructor - creates new instance of this class
    function new(string name = "sequence_simple_rand");
        super.new(name);
    endfunction

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "uvm_dma_ll_info::sequence_simple is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            // Generate random request, which must be in interval from min length to max length
            `uvm_do_with(req, {channel inside{[channel_min : channel_max]}; });
        end
    endtask
endclass

class sequence_simple_rand_dist#(CHANNELS) extends uvm_sequence #(sequence_item);
    `uvm_object_param_utils(uvm_dma_ll_info::sequence_simple_rand_dist#(CHANNELS))

    rand int unsigned transaction_count;
    int unsigned transaction_count_min = 10;
    int unsigned transaction_count_max = 200;
    int unsigned channel_max = CHANNELS; // 2048
    int unsigned channel_min = 0;

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}

    // Constructor - creates new instance of this class
    function new(string name = "sequence_simple_rand_dist");
        super.new(name);
    endfunction

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "uvm_dma_ll_info::sequence_simple is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            // Generate random request, which must be in interval from min length to max length
            `uvm_do_with(req, {channel inside{[channel_min : channel_max]}; });
        end
    endtask
endclass

class sequence_simple_channel#(CHANNELS) extends uvm_sequence #(sequence_item);
    `uvm_object_param_utils(uvm_dma_ll_info::sequence_simple_channel#(CHANNELS))

    rand int unsigned transaction_count;
    int unsigned transaction_count_min = 10;
    int unsigned transaction_count_max = 20;
    rand int unsigned channel; // 2048

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}
    constraint channel_num_c {channel inside {[0 : CHANNELS]};}

    // Constructor - creates new instance of this class
    function new(string name = "sequence_simple_channel");
        super.new(name);
    endfunction

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "uvm_dma_ll_info::sequence_simple is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            // Generate random request, which must be in interval from min length to max length
            `uvm_do_with(req, {channel == this.channel;});
        end
    endtask
endclass


//////////////////////////////////////
// TX LIBRARY
class sequence_lib#(CHANNELS) extends uvm_sequence_library#(sequence_item);
  `uvm_object_param_utils(uvm_dma_ll_info::sequence_lib#(CHANNELS))
  `uvm_sequence_library_utils(uvm_dma_ll_info::sequence_lib#(CHANNELS))

    function new(string name = "sequence_lib");
        super.new(name);
        init_sequence_library();
    endfunction

    // subclass can redefine and change run sequences
    // can be useful in specific tests
    virtual function void init_sequence();
        this.add_sequence(sequence_simple#(CHANNELS)::get_type());
        this.add_sequence(sequence_simple_rand#(CHANNELS)::get_type());
        this.add_sequence(sequence_simple_rand_dist#(CHANNELS)::get_type());
        this.add_sequence(sequence_simple_channel#(CHANNELS)::get_type());
    endfunction
endclass

