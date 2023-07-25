//-- sequence.sv
//-- Copyright (C) 2023 CESNET z. s. p. o.
//-- Author(s): Daniel Kříž <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

class sequence_meta#(META_WIDTH, TIMESTAMP_WIDTH, TIMESTAMP_MIN, TIMESTAMP_MAX, TIMESTAMP_FORMAT) extends uvm_sequence #(uvm_logic_vector::sequence_item#(META_WIDTH));
    `uvm_object_param_utils(uvm_timestamp_limiter::sequence_meta#(META_WIDTH, TIMESTAMP_WIDTH, TIMESTAMP_MIN, TIMESTAMP_MAX, TIMESTAMP_FORMAT))

    function new(string name = "sequence_meta");
        super.new(name);
    endfunction

    task body;
        logic [TIMESTAMP_WIDTH-1 : 0] timestamp = 0;
        logic [TIMESTAMP_WIDTH-1 : 0] ts_step   = 0;
        forever begin
            assert(std::randomize(ts_step) with {
                    ts_step inside {[TIMESTAMP_MIN : TIMESTAMP_MAX]}; 
                });
            `uvm_do_with(req, {
                if (TIMESTAMP_FORMAT == 0) {
                    data[TIMESTAMP_WIDTH-1 : 0] inside {[TIMESTAMP_MIN : TIMESTAMP_MAX]};
                } else {
                    data[TIMESTAMP_WIDTH-1 : 0] == timestamp;
                }
            });
            timestamp += ts_step;
        end
    endtask
endclass
