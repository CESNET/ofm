//-- sequence.sv
//-- Copyright (C) 2023 CESNET z. s. p. o.
//-- Author(s): Daniel Kříž <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

class sequence_meta#(META_WIDTH, TIMESTAMP_WIDTH, TIMESTAMP_MIN, TIMESTAMP_MAX) extends uvm_sequence #(uvm_logic_vector::sequence_item#(META_WIDTH));
    `uvm_object_param_utils(uvm_timestamp_limiter::sequence_meta#(META_WIDTH, TIMESTAMP_WIDTH, TIMESTAMP_MIN, TIMESTAMP_MAX))

    function new(string name = "sequence_meta");
        super.new(name);
    endfunction

    task body;
        forever begin
            `uvm_do_with(req, {
                data[TIMESTAMP_WIDTH-1 : 0] inside {[TIMESTAMP_MIN : TIMESTAMP_MAX]};
            });
        end
    endtask
endclass
