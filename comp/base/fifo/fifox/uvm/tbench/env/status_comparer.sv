// status_comparer.sv: Ordered comparer without check phase
// Copyright (C) 2023 CESNET z. s. p. o.
// Author(s): Yaroslav Marushchenko <xmarus09@stud.fit.vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause

class status_comparer #(type CLASS_TYPE) extends uvm_common::comparer_ordered #(CLASS_TYPE);
    `uvm_component_param_utils(uvm_fifox::status_comparer #(CLASS_TYPE))

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void check_phase(uvm_phase phase);
        flush();
    endfunction

endclass
