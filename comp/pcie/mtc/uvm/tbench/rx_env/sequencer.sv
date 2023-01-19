//-- sequencer.sv
//-- Copyright (C) 2023 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

class sequencer#(ITEM_WIDTH) extends uvm_sequencer;
    `uvm_component_param_utils(uvm_pcie_cq::sequencer#(ITEM_WIDTH));

    uvm_pcie_hdr::sequencer                        m_pcie_hdr;

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass


