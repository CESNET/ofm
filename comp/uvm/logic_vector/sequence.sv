//-- sequence.sv: Sequence of logic vector 
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

// Reusable high level sequence. Contains transaction, which has only data part
class sequence_simple #(DATA_WIDTH) extends uvm_sequence #(sequence_item #(DATA_WIDTH));

    `uvm_object_param_utils(uvm_logic_vector::sequence_simple#(DATA_WIDTH))

    int unsigned transaction_count_min = 10;
    int unsigned transaction_count_max = 1000;
    rand int unsigned transaction_count;

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
        repeat(transaction_count)
        begin
            // Generate random request
            `uvm_do(req)
        end
    endtask

endclass

class sequence_endless #(DATA_WIDTH) extends uvm_sequence #(sequence_item #(DATA_WIDTH));
    `uvm_object_param_utils(uvm_logic_vector::sequence_endless#(DATA_WIDTH))

    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new(name);
    endfunction

    // -----------------------
    // Functions.
    // -----------------------

    // Generates transactions
    task body;
        forever begin
            // Generate random request
            `uvm_do(req)
        end
    endtask

endclass
