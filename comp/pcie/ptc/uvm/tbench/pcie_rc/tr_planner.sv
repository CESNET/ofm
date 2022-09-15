//-- tr_planner.sv: Transaction planner
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

class tr_planner #(ITEM_WIDTH) extends uvm_component;
    `uvm_component_param_utils(uvm_pcie_rc::tr_planner #(ITEM_WIDTH))

    uvm_analysis_imp#(uvm_logic_vector::sequence_item#(ITEM_WIDTH), tr_planner #(ITEM_WIDTH)) analysis_imp;
    uvm_logic_vector::sequence_item #(ITEM_WIDTH) logic_array[$];
    uvm_logic_vector::sequence_item #(ITEM_WIDTH) byte_array[$];

    function new(string name, uvm_component parent);
        super.new(name, parent);
        analysis_imp = new("analysis_imp", this);
    endfunction

    virtual function void write(uvm_logic_vector::sequence_item#(ITEM_WIDTH) req);
        logic_array.push_back(req);
        byte_array.push_back(req);
    endfunction
endclass