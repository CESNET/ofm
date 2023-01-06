// sequence_set.sv Sequence generating user defined MI and data transactions
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause

// This MI sequence define bus functionality
class sequence_mi#(DATA_WIDTH, ADDR_WIDTH, CLK_PERIOD, META_WIDTH = 0) extends uvm_mi::sequence_slave_sim#(DATA_WIDTH, ADDR_WIDTH, META_WIDTH);
    `uvm_object_param_utils(uvm_lookup_table::sequence_mi #(DATA_WIDTH, ADDR_WIDTH, CLK_PERIOD, META_WIDTH))

    function new (string name = "sequence_mi");
        super.new(name);
    endfunction

    // In this task you have to define how the MI transactions will look like
    virtual task create_sequence_item();

        // Write request
        //       WR    DATA          ADDR     BE
        mi_write(1'b1, 32'hda7a5407, 10'd0,   '1);
        mi_write(1'b1, 32'hda7a5411, 10'd512, '1);
        mi_write(1'b1, 32'heb7ab8cc, 10'd4,   '1);
        mi_write(1'b1, 32'hda7a54cc, 10'd516, '1);
        mi_write(1'b1, 32'h6fbaaa52, 10'd8,   '1);
        mi_write(1'b1, 32'h2474b6ac, 10'd12,  '1);
        mi_write(1'b1, 32'hc4d1ce40, 10'd16,  '1);
        #(50*CLK_PERIOD)
        // Read request
        //      RD    ADDR    BE
        mi_read(1'b1, 10'd0,  '1);
        mi_read(1'b1, 10'd4,  '1);
        mi_read(1'b1, 10'd8,  '1);
        mi_read(1'b1, 10'd12, '1);
        mi_read(1'b1, 10'd16, '1);

    endtask
endclass

class sequence_mvb_data #(DATA_WIDTH) extends uvm_sequence #(uvm_logic_vector::sequence_item #(DATA_WIDTH));

    `uvm_object_param_utils(uvm_lookup_table::sequence_mvb_data#(DATA_WIDTH))

    // Constructor - creates new instance of this class
    function new(string name = "sequence_mvb_data");
        super.new(name);
    endfunction

    // In body you have to define how the MVB data will looks like
    task body;
        `uvm_do_with(req, {req.data == 10'd0;  });
        `uvm_do_with(req, {req.data == 10'd4;  });
        `uvm_do_with(req, {req.data == 10'd8;  });
        `uvm_do_with(req, {req.data == 10'd12; });
        `uvm_do_with(req, {req.data == 10'd16; });
    endtask

endclass