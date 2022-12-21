//-- sync_link.sv: Synchronization of tags
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

class sync_link#(CHANNELS) extends uvm_component;
    `uvm_component_utils(uvm_dma_ll_info::sync_link#(CHANNELS))

    logic status[CHANNELS] ;
    logic control[CHANNELS];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task add_element(logic status, logic control, int channel);
        this.status[channel] = status;
        this.control[channel] = control;
    endtask

endclass