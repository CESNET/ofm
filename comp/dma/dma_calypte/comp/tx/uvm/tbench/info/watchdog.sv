//-- watchdog.sv
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

class watchdog #(CHANNELS) extends uvm_component;
    `uvm_component_param_utils(uvm_dma_ll_info::watchdog #(CHANNELS))

    logic channel_status[CHANNELS];
    logic driver_status[CHANNELS] = '{default:'0};
    int unsigned binder_cnt[CHANNELS];

    // ------------------------------------------------------------------------
    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass
