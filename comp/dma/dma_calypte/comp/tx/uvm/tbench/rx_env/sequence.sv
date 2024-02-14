//-- sequence.sv
//-- Copyright (C) 2024 CESNET z. s. p. o.
//-- Author(s): Radek Iša <isa@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

// This low level sequence define bus functionality


class base_send_sequence#(type T_ITEM) extends uvm_sequence #(T_ITEM);
    `uvm_object_param_utils(uvm_dma_ll_rx::base_send_sequence#(T_ITEM))

    mailbox#(T_ITEM) tr_export;

    function new(string name = "sequence_simple_rx_base");
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

