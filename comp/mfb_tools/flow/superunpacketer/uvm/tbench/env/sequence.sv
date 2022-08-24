// sequence.sv Sequence generating superpackets
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause

// This low level sequence define bus functionality
class byte_array_sequence extends uvm_sequence#(uvm_logic_vector_array::sequence_item #(8));
    `uvm_object_utils(uvm_superunpacketer::byte_array_sequence)

    mailbox#(uvm_logic_vector_array::sequence_item #(8)) tr_export;

    function new(string name = "superpacket_sequence");
        super.new(name);
    endfunction

    task body;
        forever begin
            tr_export.get(req);
            start_item(req);
            finish_item(req);
        end
    endtask
endclass
