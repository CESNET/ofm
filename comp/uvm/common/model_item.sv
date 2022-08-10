/*
 * file       : model_item.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: item to model add time;
 * date       : 2021
 * author     : Radek Iša <isa@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/


////////////////////////////////////////////////
// CLASS WITH BOUNDS
class model_item#(type SEQ_ITEM) extends uvm_object;
   `uvm_object_param_utils(uvm_common::model_item#(SEQ_ITEM))

    time     start;
    SEQ_ITEM item;

    function new(string name = "");
        super.new(name);
    endfunction

    function void do_copy(uvm_object rhs);
        model_item#(SEQ_ITEM) rhs_;

        if(!$cast(rhs_, rhs)) begin
            `uvm_fatal( "do_copy:", "Failed to cast transaction object.")
            return;
        end

        // Now copy all attributes
        super.do_copy(rhs);
        start = rhs_.start;
        item  = rhs_.item;
    endfunction: do_copy
endclass


////////////////////////////////////////////////
// subscriber add time to item 
class subscriber#(type SEQ_ITEM) extends uvm_subscriber#(SEQ_ITEM);
   `uvm_component_param_utils(uvm_common::subscriber#(SEQ_ITEM))

    uvm_analysis_port#(model_item#(SEQ_ITEM)) port;

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
        port = new("port", this);
    endfunction


    virtual function void write(SEQ_ITEM t);
        model_item#(SEQ_ITEM) item;
        item = model_item#(SEQ_ITEM)::type_id::create("item", this);
        item.item  = t;
        item.start = $time();
        port.write(item);
    endfunction
endclass

