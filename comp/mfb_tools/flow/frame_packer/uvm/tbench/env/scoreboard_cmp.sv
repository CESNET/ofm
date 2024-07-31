// scoreboard_cmp.sv: CMP for verification
// Copyright (C) 2024 CESNET z. s. p. o.
// Author(s): David Beneš <xbenes52@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause

//Note: use comparer_ordered in case of one channel setting
class comparer_superpacket #(type CLASS_TYPE) extends uvm_common::comparer_taged#(CLASS_TYPE); // comparer_ordered#(CLASS_TYPE);
    `uvm_component_param_utils(uvm_framepacker::comparer_superpacket #(CLASS_TYPE))

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function int unsigned compare(MODEL_ITEM tr_model, DUT_ITEM tr_dut);
        int unsigned ret = 1;
        if (tr_model.data.size() < tr_dut.data.size()) return 0;
        for (int unsigned it = 0; it < tr_model.size(); it++) begin
            if (!$isunknown(tr_model.data[it]) && tr_model.data[it] !== tr_dut.data[it]) begin
                return 0;
            end
        end
        `uvm_info(this.get_full_name(), {"\nMODEL ITEM : ", model_item2string(tr_model), "\nDUT ITEM : ", dut_item2string(tr_dut)}, UVM_MEDIUM);
        return ret;
    endfunction

endclass
