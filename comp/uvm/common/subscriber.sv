/*
 * file       :  subscriber.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: item to model add time;
 * date       : 2021
 * author     : Radek Iša <isa@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/


////////////////////////////////////////////////
// change item to model_item which carry input time of transactions
virtual class subscriber_base#(type SEQ_ITEM, OUTPUT_ITEM) extends uvm_subscriber#(SEQ_ITEM);
   `uvm_component_param_utils(uvm_common::subscriber_base#(SEQ_ITEM, OUTPUT_ITEM))

    uvm_analysis_port#(model_item#(OUTPUT_ITEM)) port;
    protected string inf_name;

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
        port = new("port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(string)::get(this, "", "inf_name", inf_name)) begin
            inf_name = this.get_full_name();
        end
    endfunction


    pure virtual function void write(SEQ_ITEM t);
endclass

////////////////////////////////////////////////
// subscriber add time to item 
class subscriber#(type SEQ_ITEM) extends subscriber_base#(SEQ_ITEM, SEQ_ITEM);
   `uvm_component_param_utils(uvm_common::subscriber#(SEQ_ITEM))

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void write(SEQ_ITEM t);
        model_item#(SEQ_ITEM) item;
        item = model_item#(SEQ_ITEM)::type_id::create("item", this);
        item.item  = t;
        item.start[inf_name] = $time();
        port.write(item);
    endfunction
endclass
