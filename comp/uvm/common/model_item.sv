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

    time     start[string];
    SEQ_ITEM item;

    function new(string name = "");
        super.new(name);
    endfunction

    function void time_add(string name, time t);
        start[name] = t;
    endfunction

    function void time_array_add(time input_time[string]);
        foreach (input_time[it]) begin
            start[it] = input_time[it];
        end
    endfunction

    function time time_last();
        time ret = 0ns;
        foreach (start[it]) begin
            if (ret < start[it]) begin
                ret = start[it];
            end
        end
        return ret;
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

    function string convert2string_time();
        string msg = "";
        $swrite(msg, "%s\n\tINPUT TIMES :", msg);
        foreach (start[it]) begin
            $swrite(msg, "\n\t\t%s : %0dns", it, start[it]/1ns);
        end

        return msg;
    endfunction

    function string convert2string();
        string msg = "";

        $swrite(msg,"%s%s\n\tDATA : %s", msg, this.convert2string_time(), item.convert2string());
        return msg;
    endfunction
endclass


////////////////////////////////////////////////
// subscriber add time to item 
class subscriber#(type SEQ_ITEM) extends uvm_subscriber#(SEQ_ITEM);
   `uvm_component_param_utils(uvm_common::subscriber#(SEQ_ITEM))

    uvm_analysis_port#(model_item#(SEQ_ITEM)) port;
    string inf_name;

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


    virtual function void write(SEQ_ITEM t);
        model_item#(SEQ_ITEM) item;
        item = model_item#(SEQ_ITEM)::type_id::create("item", this);
        item.item  = t;
        item.start[inf_name] = $time();
        port.write(item);
    endfunction
endclass

