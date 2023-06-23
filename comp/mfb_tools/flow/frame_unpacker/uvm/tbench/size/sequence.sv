// sequence.sv
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause

class sequence_simple#(MIN_SIZE, PKT_MTU) extends uvm_sequence#(uvm_superpacket_size::sequence_item);
    `uvm_object_param_utils(uvm_superpacket_size::sequence_simple#(MIN_SIZE, PKT_MTU))

    rand int unsigned transaction_count;
    int unsigned transaction_count_min = 10;
    int unsigned transaction_count_max = 20;

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}

    // Constructor - creates new instance of this class
    function new(string name = "sequence_simple");
        super.new(name);
    endfunction

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "uvm_superpacket_size::sequence_simple is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            `uvm_do_with(req, {req.sp_size inside{[MIN_SIZE : PKT_MTU]}; });
        end
    endtask

endclass

class sequence_simple_long#(MIN_SIZE, PKT_MTU) extends uvm_sequence#(uvm_superpacket_size::sequence_item);
    `uvm_object_param_utils(uvm_superpacket_size::sequence_simple_long#(MIN_SIZE, PKT_MTU))

    rand int unsigned transaction_count;
    int unsigned transaction_count_min = 10;
    int unsigned transaction_count_max = 20;
    int unsigned min_len = 16383;

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}

    // Constructor - creates new instance of this class
    function new(string name = "sequence_simple_long");
        super.new(name);
    endfunction

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "uvm_superpacket_size::sequence_simple_long is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            `uvm_do_with(req, {req.sp_size inside{[min_len : PKT_MTU]}; });
        end
    endtask

endclass

class sequence_simple_medium extends uvm_sequence#(uvm_superpacket_size::sequence_item);
    `uvm_object_utils(uvm_superpacket_size::sequence_simple_medium)

    rand int unsigned transaction_count;
    int unsigned transaction_count_min = 10;
    int unsigned transaction_count_max = 20;
    int unsigned min_len = 1500;
    int unsigned max_len = 16383;

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}

    // Constructor - creates new instance of this class
    function new(string name = "sequence_simple_medium");
        super.new(name);
    endfunction

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "uvm_superpacket_size::sequence_simple_medium is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            `uvm_do_with(req, {req.sp_size inside{[min_len : max_len]}; });
        end
    endtask

endclass

class sequence_simple_short#(MIN_SIZE, PKT_MTU) extends uvm_sequence#(uvm_superpacket_size::sequence_item);
    `uvm_object_param_utils(uvm_superpacket_size::sequence_simple_short#(MIN_SIZE, PKT_MTU))

    rand int unsigned transaction_count;
    int unsigned transaction_count_min = 10;
    int unsigned transaction_count_max = 20;
    int unsigned max_len = 1500;

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}

    // Constructor - creates new instance of this class
    function new(string name = "sequence_simple_short");
        super.new(name);
    endfunction

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "uvm_superpacket_size::sequence_simple_short is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            `uvm_do_with(req, {req.sp_size inside{[MIN_SIZE : max_len]}; });
        end
    endtask

endclass

class sequence_simple_min#(MIN_SIZE, PKT_MTU) extends uvm_sequence#(uvm_superpacket_size::sequence_item);
    `uvm_object_param_utils(uvm_superpacket_size::sequence_simple_min#(MIN_SIZE, PKT_MTU))

    rand int unsigned transaction_count;
    int unsigned transaction_count_min = 100;
    int unsigned transaction_count_max = 200;
    int unsigned max_len = 128;

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}

    // Constructor - creates new instance of this class
    function new(string name = "sequence_simple_min");
        super.new(name);
    endfunction

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "uvm_superpacket_size::sequence_simple_min is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            `uvm_do_with(req, {req.sp_size inside{[MIN_SIZE : max_len]}; });
        end
    endtask

endclass


/////////////////////////////////////////////////////////////////////////
// SEQUENCE LIBRARY
class sequence_lib#(MIN_SIZE, PKT_MTU) extends uvm_sequence_library#(sequence_item);
  `uvm_object_param_utils(uvm_superpacket_size::sequence_lib#(MIN_SIZE, PKT_MTU))
  `uvm_sequence_library_utils(uvm_superpacket_size::sequence_lib#(MIN_SIZE, PKT_MTU))

    function new(string name = "sequence_library");
        super.new(name);
        init_sequence_library();
    endfunction

    // subclass can redefine and change run sequences
    // can be useful in specific tests
    virtual function void init_sequence();
        this.add_sequence(uvm_superpacket_size::sequence_simple#(MIN_SIZE, PKT_MTU)::get_type());
        // this.add_sequence(uvm_superpacket_size::sequence_simple_short#(MIN_SIZE, PKT_MTU)::get_type());
        // this.add_sequence(uvm_superpacket_size::sequence_simple_medium::get_type());
        // this.add_sequence(uvm_superpacket_size::sequence_simple_long#(MIN_SIZE, PKT_MTU)::get_type());
        // this.add_sequence(uvm_superpacket_size::sequence_simple_min#(MIN_SIZE, PKT_MTU)::get_type());
    endfunction
endclass