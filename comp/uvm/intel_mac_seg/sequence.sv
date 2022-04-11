/*
 * file       : sequence.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: base sequence Intel seq mac agent
 * date       : 2021
 * author     : Radek Iša <isa@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/


class sequence_simple_rx #(SEGMENTS) extends uvm_sequence #(sequence_item #(SEGMENTS));
    `uvm_object_param_utils(intel_mac_seg::sequence_simple_rx #(SEGMENTS))

    // ------------------------------------------------------------------------
    // Variables
    sequence_item #(SEGMENTS) req;

    int unsigned max_transaction_count = 2048;
    int unsigned min_transaction_count = 32;
    rand int unsigned transaction_count;

    constraint c1 {transaction_count inside {[min_transaction_count: max_transaction_count]};}
    // ------------------------------------------------------------------------
    // Constructor
    function new(string name = "Simple sequence rx");
        super.new(name);
    endfunction

    task send_empty_frame();
        start_item(req);
        req.randomize();
        {>>{req.inframe}} = '0;
        req.valid   = '0;
        finish_item(req);
        get_response(rsp);
    endtask

    task send_frame();
        start_item(req);
        req.randomize();
        finish_item(req);
        get_response(rsp);
	endtask


    // ------------------------------------------------------------------------
    // Generates transactions
    task body;
        // Generate transaction_count transactions
        req = sequence_item #(SEGMENTS)::type_id::create("req");
        repeat(transaction_count) begin
            // Create a request for sequence item
            send_frame();
        end
    endtask
endclass


class sequence_simple_tx #(SEGMENTS) extends uvm_sequence #(sequence_item #(SEGMENTS));
    `uvm_object_param_utils(intel_mac_seg::sequence_simple_tx #(SEGMENTS))

    // ------------------------------------------------------------------------
    // Variables
    sequence_item #(SEGMENTS) req;
    common::rand_rdy          rdy;

    int unsigned max_transaction_count = 2048;
    int unsigned min_transaction_count = 32;
    rand int unsigned transaction_count;

    constraint c1 {transaction_count inside {[min_transaction_count: max_transaction_count]};}
    // ------------------------------------------------------------------------
    // Constructor
    function new(string name = "Simple sequence rx");
        super.new(name);
        rdy = common::rand_rdy_rand::new();
    endfunction

    task send_frame();
        start_item(req);
        void'(rdy.randomize());
        void'(req.randomize() with {ready == rdy.m_value;});
        finish_item(req);
        get_response(rsp);
	endtask


    // ------------------------------------------------------------------------
    // Generates transactions
    task body;
        // Generate transaction_count transactions
        req = sequence_item #(SEGMENTS)::type_id::create("req");
        repeat(transaction_count) begin
            // Create a request for sequence item
            send_frame();
        end
    endtask
endclass

