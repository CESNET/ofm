//-- sequencer.sv
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Radek Iša <isa@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

class sequencer extends uvm_sequencer#(sequence_item);
    `uvm_component_param_utils(uvm_dma_ll_rx::sequencer);

    uvm_reset::sync_terminate reset_sync;
    uvm_dma_regs::reg_channel m_regmodel;

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void regmodel_set(uvm_dma_regs::reg_channel m_regmodel);
        this.m_regmodel = m_regmodel;
    endfunction


    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        reset_sync = new();
    endfunction
endclass


