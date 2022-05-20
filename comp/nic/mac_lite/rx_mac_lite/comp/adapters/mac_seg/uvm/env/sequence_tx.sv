/*
 * file       : sequence_tx.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: tx sequence generates allways 1. other side have to be allways ready 
 * date       : 2021
 * author     : Radek Iša <isa@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/


class sequence_tx #(REGIONS, REGION_SIZE) extends uvm_mfb::sequence_simple_tx #(REGIONS, REGION_SIZE, 8, 8, 1);
    `uvm_object_param_utils(uvm_mac_seg_rx::sequence_tx #(REGIONS, REGION_SIZE))

    // ------------------------------------------------------------------------
    // Constructor
    function new(string name = "Simple sequence tx");
        super.new(name);
    endfunction

    task body;
        req = uvm_mfb::sequence_item #(REGIONS, REGION_SIZE, 8, 8, 1)::type_id::create("req");
        forever begin
            // Create a request for sequence item
            start_item(req);
            void'(req.randomize() with {DST_RDY == 1'b1;});
            finish_item(req);
            get_response(rsp);
        end
    endtask
endclass
