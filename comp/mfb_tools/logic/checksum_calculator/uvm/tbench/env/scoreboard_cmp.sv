// scoreboard.sv: Scoreboard for verification
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause

class chsum_calc_cmp #(MVB_DATA_WIDTH, MFB_META_WIDTH) extends uvm_common::comparer_base_ordered#(uvm_checksum_calculator::chsum_calc_item#(MVB_DATA_WIDTH, MFB_META_WIDTH), uvm_logic_vector::sequence_item#(MVB_DATA_WIDTH+1+MFB_META_WIDTH));
    `uvm_component_param_utils(uvm_checksum_calculator::chsum_calc_cmp #(MVB_DATA_WIDTH, MFB_META_WIDTH))

    protected uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH) tr_dut_data;
    protected logic                                             bypass_dut;
    protected logic[MFB_META_WIDTH-1 : 0]                       meta_dut;

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function int unsigned compare(uvm_common::model_item #(MODEL_ITEM) tr_model, uvm_common::dut_item #(DUT_ITEM) tr_dut);
        int unsigned                                      ret;

        `uvm_info(get_type_name(), message(tr_model, tr_dut), UVM_HIGH)

        tr_dut_data      = uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH)::type_id::create("tr_dut_data");
        tr_dut_data.data = tr_dut.in_item.data[MVB_DATA_WIDTH-1 : 0];
        bypass_dut       = tr_dut.in_item.data[MVB_DATA_WIDTH];
        meta_dut         = tr_dut.in_item.data[MVB_DATA_WIDTH+1+MFB_META_WIDTH-1 : MVB_DATA_WIDTH];

        if (tr_model.item.bypass) begin
            ret = 1;
        end else begin
            ret |= tr_model.item.data_tr.compare(tr_dut_data);
            ret |= bypass_dut === tr_model.item.bypass;
            ret |= meta_dut   === tr_model.item.meta;
        end

        return ret;
    endfunction

    virtual function string message(uvm_common::model_item#(MODEL_ITEM) tr_model, uvm_common::dut_item #(DUT_ITEM) tr_dut);
        string msg = "\n";
        $swrite(msg, "%s\n\tDUT PACKET %s\n\n" , msg, tr_dut_data.convert2string());
        $swrite(msg, "%s\n\tDUT BYPASS %h\n\n" , msg, bypass_dut);
        $swrite(msg, "%s\n\tDUT META   %h\n\n" , msg, meta_dut);
        $swrite(msg, "%s\n\tMODEL PACKET%s\n\n", msg, tr_model.convert2string());
        return msg;
    endfunction
endclass

