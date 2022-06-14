//-- monitor.sv: Monitor for MVB environment
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

class monitor #(ITEMS, ITEM_WIDTH) extends uvm_logic_vector::monitor#(ITEM_WIDTH);
    `uvm_component_param_utils(uvm_logic_vector_mvb::monitor #(ITEMS, ITEM_WIDTH))

    // Analysis port
    typedef monitor #(ITEMS, ITEM_WIDTH) this_type;
    uvm_analysis_imp #(uvm_mvb::sequence_item #(ITEMS, ITEM_WIDTH), this_type) analysis_export;

    uvm_reset::sync_terminate reset_sync;
    local uvm_logic_vector::sequence_item#(ITEM_WIDTH) hi_tr;
    local int unsigned vld_cnt;

    function new (string name, uvm_component parent);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        hi_tr = null;
        reset_sync = new();
    endfunction

    virtual function void write(uvm_mvb::sequence_item #(ITEMS, ITEM_WIDTH) tr);
        if (reset_sync.has_been_reset()) begin
            hi_tr = null;
        end

        if (tr.src_rdy == 1'b1 && tr.dst_rdy == 1'b1) begin
            for (int i = 0; i < ITEMS; i++) begin
                hi_tr = uvm_logic_vector::sequence_item#(ITEM_WIDTH)::type_id::create("hi_tr");
                if (tr.vld[i] == 1'b1) begin
                    hi_tr.data = tr.data[i];
                    analysis_port.write(hi_tr);
                end
            end
        end
    endfunction
endclass
