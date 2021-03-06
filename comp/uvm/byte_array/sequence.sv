/*
 * file       : sequence.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: byte array sequence
 * date       : 2021
 * author     : Daniel Kriz <xkrizd01@vutbr.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/


// Reusable high level sequence. Contains transaction, which has only data part.
class sequence_simple extends uvm_sequence #(sequence_item);
    `uvm_object_utils(byte_array::sequence_simple)

    rand int unsigned transaction_count;
    int unsigned data_size_max = 2048; // 2048
    int unsigned data_size_min = 64;
    int unsigned transaction_count_min = 10;
    int unsigned transaction_count_max = 200;

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}

    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new(name);
    endfunction

    // -----------------------
    // Functions.
    // -----------------------

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "sequence_simple is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            // Generate random request, which must be in interval from min length to max length
            `uvm_do_with(req, {data.size inside{[data_size_min : data_size_max]}; });
        end
    endtask

endclass

// High level sequence with same size.

class sequence_simple_const extends uvm_sequence #(sequence_item);
    `uvm_object_utils(byte_array::sequence_simple_const)

    rand int unsigned data_size;
    rand int unsigned transaction_count;
    int unsigned transaction_count_min = 10;
    int unsigned transaction_count_max = 200;
    int unsigned data_size_min = 60;
    int unsigned data_size_max = 1500;

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}
    constraint c2 {data_size inside {[data_size_min : data_size_max]};}

    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new(name);
    endfunction

    // -----------------------
    // Functions.
    // -----------------------

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "sequence_simple_const is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            // Generate random request, which must be in interval from min length to max length
            `uvm_do_with(req, {data.size == data_size; });
        end
    endtask

endclass

// High level sequence with Gaussian distribution.

class sequence_simple_gauss extends uvm_sequence #(sequence_item);
    `uvm_object_utils(byte_array::sequence_simple_gauss)

    rand int unsigned transaction_count;
    rand int unsigned mean; // Mean of data size
    rand int unsigned std_deviation; // Standard deviation
    int unsigned transaction_count_min = 10;
    int unsigned transaction_count_max = 200;
    int unsigned mean_min = 256;
    int unsigned mean_max = 4096;
    int unsigned std_deviation_min = 1;
    int unsigned std_deviation_max = 20;

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}
    constraint c2 {mean inside {[mean_min : mean_max]};}
    constraint c3 {std_deviation inside {[std_deviation_min : std_deviation_max]};}

    function int gaussian_dist();
        return $dist_normal($urandom(), mean, std_deviation);
    endfunction


    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new(name);
    endfunction

    // -----------------------
    // Functions.
    // -----------------------

    // Generates transactions
    task body;
        int unsigned data_size;
        `uvm_info(get_full_name(), "sequence_simple_gauss is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            data_size = gaussian_dist();
            // Generate random request, which must be in interval from min length to max length
            `uvm_do_with(req, {data.size ==  data_size;});
        end
    endtask

endclass

// High level sequence with increment size.

class sequence_simple_inc extends uvm_sequence #(sequence_item);
    `uvm_object_utils(byte_array::sequence_simple_inc)

    rand int unsigned transaction_count;
    rand int unsigned step;
    rand int unsigned data_size;
    int unsigned border = 4096;
    int unsigned transaction_count_min = 10;
    int unsigned transaction_count_max = 200;
    int unsigned data_size_min = 64;
    int unsigned data_size_max = 2048;
    int unsigned mean = 50; // Mean of data size
    int unsigned std_deviation = 5; // Standard deviation

    function int gaussian_dist();
        return $dist_normal($urandom(), mean, std_deviation);
    endfunction

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}
    constraint c2 {step == gaussian_dist();}
    constraint c3 {data_size inside {[data_size_min : data_size_max]};}

    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new(name);
    endfunction

    // -----------------------
    // Functions.
    // -----------------------

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "sequence_simple_inc is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            // Generate random request, which must be in interval from min length to max length
            if (data_size <= border) begin
                `uvm_do_with(req, {data.size == data_size; });
                data_size += step;
            end else begin
                break;
            end
        end
    endtask

endclass


// High level sequence which is used for measuring

class sequence_simple_meas extends uvm_sequence #(sequence_item);
    `uvm_object_utils(byte_array::sequence_simple_meas)

    int unsigned transaction_count = 370;
    int unsigned data_size    = 64;
    int unsigned step         = 4;
    int unsigned border       = 0;
    int unsigned biggest_size = 1500;
    int unsigned border_max   = 60*data_size;
    logic meas_done           = 0;

    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new(name);
    endfunction

    // -----------------------
    // Functions.
    // -----------------------

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "sequence_simple_meas is running", UVM_DEBUG)
        repeat (transaction_count)
        begin
            while (border <= border_max) begin
                `uvm_do_with(req, {data.size == data_size; });
                border += data_size;
            end
            data_size += step;
            border_max = 60*data_size;
            border = 0;
        end
    endtask

endclass

// High level sequence with decrement size.

class sequence_simple_dec extends uvm_sequence #(sequence_item);
    `uvm_object_utils(byte_array::sequence_simple_dec)

    rand int unsigned transaction_count;
    rand int unsigned step;
    rand int unsigned data_size;
    int unsigned border = 64;
    int unsigned transaction_count_min = 10;
    int unsigned transaction_count_max = 200;
    int unsigned data_size_min = 1024;
    int unsigned data_size_max = 4096;
    int unsigned mean = 50; // Mean of data size
    int unsigned std_deviation = 5; // Standard deviation

    function int gaussian_dist();
        return $dist_normal($urandom(), mean, std_deviation);
    endfunction

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}
    constraint c2 {step == gaussian_dist();}
    constraint c3 {data_size inside {[data_size_min : data_size_max]};}

    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new(name);
    endfunction

    // -----------------------
    // Functions.
    // -----------------------

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "sequence_simple_dec is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            // Generate random request, which must be in interval from min length to max length
            if (data_size >= border) begin
                `uvm_do_with(req, {data.size == data_size; });
                data_size -= step;
            end else begin
                break;
            end
        end
    endtask

endclass


/////////////////////////////////////////////////////////////////////////
// SEQUENCE LIBRARY
class sequence_lib extends uvm_sequence_library#(sequence_item );
  `uvm_object_utils(byte_array::sequence_lib)
  `uvm_sequence_library_utils(byte_array::sequence_lib)

    function new(string name = "");
        super.new(name);
        init_sequence_library();
    endfunction

    // subclass can redefine and change run sequences
    // can be useful in specific tests
    virtual function void init_sequence();
        this.add_sequence(sequence_simple::get_type());
        this.add_sequence(sequence_simple_const::get_type());
        this.add_sequence(sequence_simple_gauss::get_type());
        this.add_sequence(sequence_simple_inc::get_type());
        this.add_sequence(sequence_simple_dec::get_type());
    endfunction
endclass
