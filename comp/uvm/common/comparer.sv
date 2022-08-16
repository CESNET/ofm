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

    virtual function int unsigned compare(MODEL_ITEM tr_model, DUT_ITEM tr_dut);
        return tr_model.compare(tr_dut);
    endfunction

    virtual function string message(MODEL_ITEM tr_model, DUT_ITEM tr_dut);
        string msg = "";
        $swrite(msg, "%s\n\tDUT PACKET %s\n\n",   msg, tr_dut.convert2string());
        $swrite(msg, "%s\n\tMODEL PACKET%s\n\n",  msg, tr_model.convert2string());
        return msg;
    endfunction
endclass

class comparer_disordered #(type CLASS_TYPE) extends uvm_common::comparer_base_disordered#(CLASS_TYPE, CLASS_TYPE);
    `uvm_component_param_utils(uvm_common::comparer_disordered#(CLASS_TYPE))

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function int unsigned compare(MODEL_ITEM tr_model, DUT_ITEM tr_dut);
        return tr_model.compare(tr_dut);
    endfunction

    virtual function string message(MODEL_ITEM tr_model, DUT_ITEM tr_dut);
        string msg = "";
        $swrite(msg, "%s\n\tDUT PACKET %s\n\n",   msg, tr_dut.convert2string());
        $swrite(msg, "%s\n\tMODEL PACKET%s\n\n",  msg, tr_model.convert2string());
        return msg;
    endfunction
endclass

