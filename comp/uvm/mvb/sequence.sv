//-- sequence.sv: Mvb sequence
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

`ifndef MVB_SEQUENCE_SV
`define MVB_SEQUENCE_SV

// This low level sequence define bus functionality 
class sequence_simple_rx #(ITEMS, ITEM_WIDTH) extends uvm_sequence #(mvb::sequence_item #(ITEMS, ITEM_WIDTH));

    // ------------------------------------------------------------------------
    // Registration of agent to databaze
    `uvm_object_param_utils(mvb::sequence_simple_rx #(ITEMS, ITEM_WIDTH))
  
    // ------------------------------------------------------------------------
    // Variables
    sequence_item #(ITEMS, ITEM_WIDTH) req;
    sequence_item #(ITEMS, ITEM_WIDTH) rsp;
    
    int unsigned transaction_count_max = 100;
    int unsigned transaction_count_min = 10;
    rand int unsigned transaction_count;

    constraint tr_cnt_cons {transaction_count inside {[transaction_count_min:transaction_count_max]};}
    // ------------------------------------------------------------------------
    // Constructor
    function new(string name = "Simple sequence rx");
        super.new(name);
    endfunction

    // ------------------------------------------------------------------------
    // Generates transactions
    task body;
        // Generate transaction_count transactions
        req = sequence_item #(ITEMS, ITEM_WIDTH)::type_id::create("req");

        repeat(transaction_count) begin
            // Create a request for sequence item
            start_item(req);
        
            // Do not generate new data when SRC_RDY was 1 but the transaction does not transfare 
            if (!req.randomize()) begin
                `uvm_fatal("sequence:", "Faile to randomize sequence.")
            end
            finish_item(req);

            // Get response from driver
            get_response(rsp);

            while (rsp.SRC_RDY && !rsp.DST_RDY) begin
                start_item(req);
                finish_item(req);
                get_response(rsp);
            end

        end
    endtask
endclass

//////////////////////////////////////
// RX LIBRARY
class sequence_lib_rx#(ITEMS, ITEM_WIDTH) extends uvm_sequence_library#(mvb::sequence_item#(ITEMS, ITEM_WIDTH));
  `uvm_object_param_utils(mvb::sequence_lib_rx#(ITEMS, ITEM_WIDTH))
  `uvm_sequence_library_utils(mvb::sequence_lib_rx#(ITEMS, ITEM_WIDTH))

    function new(string name = "");
        super.new(name);
        init_sequence_library();
    endfunction

    // subclass can redefine and change run sequences
    // can be useful in specific tests
    virtual function void init_sequence();
        this.add_sequence(sequence_simple_rx#(ITEMS, ITEM_WIDTH)::get_type());
    endfunction
endclass

// This low level sequence define how can data looks like
class sequence_simple_tx #(ITEMS, ITEM_WIDTH) extends uvm_sequence #(mvb::sequence_item #(ITEMS, ITEM_WIDTH));

    // ------------------------------------------------------------------------
    // Registration of agent to databaze
    `uvm_object_param_utils(mvb::sequence_simple_tx #(ITEMS, ITEM_WIDTH))

    // ------------------------------------------------------------------------
    // Variables
    sequence_item #(ITEMS, ITEM_WIDTH) req;
    common::rand_rdy          rdy;

    int unsigned max_transaction_count = 100;
    int unsigned min_transaction_count = 10;
    rand int unsigned transaction_count;

    constraint c1 {transaction_count inside {[min_transaction_count: max_transaction_count]};}

    // ------------------------------------------------------------------------
    // Constructor
    function new(string name = "Simple sequence tx");
        super.new(name);
        rdy = common::rand_rdy_rand::new();
    endfunction

    // ------------------------------------------------------------------------
    // Generates transactions
    task body;
        // Generate transaction_count transactions  
        req = sequence_item#(ITEMS, ITEM_WIDTH)::type_id::create("req");
        repeat(transaction_count) begin
            // Create a request for sequence item
            start_item(req);
            void'(rdy.randomize());
            void'(req.randomize() with {DST_RDY == rdy.m_value;});
            finish_item(req);
            get_response(rsp);
        end
    endtask
endclass


// This low level sequence that have every tact dst rdy at tx side
class sequence_full_speed_tx #(ITEMS, ITEM_WIDTH) extends uvm_sequence #(mvb::sequence_item #(ITEMS, ITEM_WIDTH));
    `uvm_object_param_utils(mvb::sequence_full_speed_tx #(ITEMS, ITEM_WIDTH))

    // ------------------------------------------------------------------------
    // Variables
    sequence_item #(ITEMS, ITEM_WIDTH) req;
    int unsigned max_transaction_count = 100;
    int unsigned min_transaction_count = 10;
    rand int unsigned transaction_count;

    constraint c1 {transaction_count inside {[min_transaction_count: max_transaction_count]};}

    // ------------------------------------------------------------------------
    // Constructor
    function new(string name = "Simple sequence tx");
        super.new(name);
    endfunction

    // ------------------------------------------------------------------------
    // Generates transactions
    task body;
        // Generate transaction_count transactions
        req = sequence_item#(ITEMS, ITEM_WIDTH)::type_id::create("req");
        repeat(transaction_count) begin
            // Create a request for sequence item
            start_item(req);
            void'(req.randomize() with {DST_RDY == 1'b1;});
            finish_item(req);
            get_response(rsp);
        end
    endtask

endclass

class sequence_stop_tx #(ITEMS, ITEM_WIDTH) extends uvm_sequence #(mvb::sequence_item #(ITEMS, ITEM_WIDTH));
    `uvm_object_param_utils(mvb::sequence_stop_tx #(ITEMS, ITEM_WIDTH))

    // ------------------------------------------------------------------------
    // Variables
    sequence_item #(ITEMS, ITEM_WIDTH) req;
    int unsigned max_transaction_count = 50;
    int unsigned min_transaction_count = 10;
    rand int unsigned transaction_count;

    constraint c1 {transaction_count inside {[min_transaction_count: max_transaction_count]};}

    // ------------------------------------------------------------------------
    // Constructor
    function new(string name = "Simple sequence tx");
        super.new(name);
    endfunction

    // ------------------------------------------------------------------------
    // Generates transactions
    task body;
        // Generate transaction_count transactions
        req = sequence_item#(ITEMS, ITEM_WIDTH)::type_id::create("req");
        repeat(transaction_count) begin
            // Create a request for sequence item
            start_item(req);
            void'(req.randomize() with {DST_RDY == 1'b0;});
            finish_item(req);
            get_response(rsp);
        end
    endtask

endclass



//////////////////////////////////////
// TX LIBRARY
class sequence_lib_tx#(ITEMS, ITEM_WIDTH) extends uvm_sequence_library#(sequence_item#(ITEMS, ITEM_WIDTH));
  `uvm_object_param_utils(mvb::sequence_lib_tx#(ITEMS, ITEM_WIDTH))
  `uvm_sequence_library_utils(mvb::sequence_lib_tx#(ITEMS, ITEM_WIDTH))

    function new(string name = "");
        super.new(name);
        init_sequence_library();
    endfunction

    // subclass can redefine and change run sequences
    // can be useful in specific tests
    virtual function void init_sequence();
        this.add_sequence(sequence_simple_tx#(ITEMS, ITEM_WIDTH)::get_type());
        this.add_sequence(sequence_full_speed_tx#(ITEMS, ITEM_WIDTH)::get_type());
        this.add_sequence(sequence_stop_tx#(ITEMS, ITEM_WIDTH)::get_type());
    endfunction
endclass

`endif
