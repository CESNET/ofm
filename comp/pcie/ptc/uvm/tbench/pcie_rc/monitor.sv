//-- monitor.sv: Monitor for MVB environment
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

class monitor #(ITEM_WIDTH) extends uvm_logic_vector::monitor#(ITEM_WIDTH);
    `uvm_component_param_utils(uvm_pcie_rc::monitor #(ITEM_WIDTH))

    // Analysis port
    typedef monitor #(ITEM_WIDTH) this_type;
    uvm_analysis_imp #(uvm_logic_vector::sequence_item#(ITEM_WIDTH), this_type) analysis_export;

    uvm_reset::sync_terminate reset_sync;
    local uvm_logic_vector::sequence_item#(ITEM_WIDTH) hi_tr;
    int read_cnt;

    function new (string name, uvm_component parent);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        hi_tr = null;
        reset_sync = new();
        read_cnt = 0;
    endfunction

    virtual function void write(uvm_logic_vector::sequence_item #(ITEM_WIDTH) tr);
        if (reset_sync.has_been_reset()) begin
            hi_tr = null;
        end

        if (tr.data[30] == 1'b0) begin
            hi_tr = uvm_logic_vector::sequence_item#(ITEM_WIDTH)::type_id::create("hi_tr");
            hi_tr.data = tr.data;
            read_cnt++;
            analysis_port.write(hi_tr);
        end
    endfunction
endclass
