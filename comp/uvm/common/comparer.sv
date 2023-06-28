/*
 * file       : comparer.sv
 * Copyright (C) 2022 CESNET z. s. p. o.
 * description: this component compare two output out of order. IF componet stays
 *              too long in fifo then erros is goint to occure.
 * date       : 2022
 * author     : Radek Iša <isa@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/

class comparer_ordered #(type CLASS_TYPE) extends uvm_common::comparer_base_ordered#(CLASS_TYPE, CLASS_TYPE);
    `uvm_component_param_utils(uvm_common::comparer_ordered#(CLASS_TYPE))

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function int unsigned compare(model_item #(MODEL_ITEM) tr_model, dut_item #(DUT_ITEM) tr_dut);
        return tr_model.item.compare(tr_dut.in_item);
    endfunction

    virtual function string message(model_item#(MODEL_ITEM) tr_model, dut_item #(DUT_ITEM) tr_dut);
        string msg = "";
        $swrite(msg, "%s\n\tDUT PACKET %s\n\n",   msg, tr_dut.in_item.convert2string());
        $swrite(msg, "%s\n\tMODEL PACKET%s\n\n",  msg, tr_model.convert2string());
        return msg;
    endfunction
endclass

class comparer_disordered #(type CLASS_TYPE) extends uvm_common::comparer_base_disordered#(CLASS_TYPE, CLASS_TYPE);
    `uvm_component_param_utils(uvm_common::comparer_disordered#(CLASS_TYPE))

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function int unsigned compare(model_item#(MODEL_ITEM) tr_model, dut_item #(DUT_ITEM) tr_dut);
        return tr_model.item.compare(tr_dut.in_item);
    endfunction

    virtual function string message(model_item#(MODEL_ITEM) tr_model, dut_item #(DUT_ITEM) tr_dut);
        string msg = "";
        $swrite(msg, "%s\n\tDUT PACKET %s\n\n",   msg, tr_dut.in_item.convert2string());
        $swrite(msg, "%s\n\tMODEL PACKET%s\n\n",  msg, tr_model.convert2string());
        return msg;
    endfunction
endclass


class comparer_taged #(type CLASS_TYPE) extends uvm_common::comparer_base_tagged#(CLASS_TYPE, CLASS_TYPE);
    `uvm_component_param_utils(uvm_common::comparer_taged#(CLASS_TYPE))

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function int unsigned compare(model_item#(MODEL_ITEM) tr_model, dut_item #(DUT_ITEM) tr_dut);
        return tr_model.item.compare(tr_dut.in_item);
    endfunction

    virtual function string message(model_item#(MODEL_ITEM) tr_model, dut_item #(DUT_ITEM) tr_dut);
        string msg = "";
        $swrite(msg, "%s\n\tDUT PACKET %s\n\n",   msg, tr_dut.in_item.convert2string());
        $swrite(msg, "%s\n\tMODEL PACKET%s\n\n",  msg, tr_model.convert2string());
        return msg;
    endfunction
endclass

