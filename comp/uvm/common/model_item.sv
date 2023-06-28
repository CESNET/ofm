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
    string   tag;
    SEQ_ITEM item;

    function new(string name = "");
        super.new(name);
        tag = "";
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
        tag   = rhs_.tag;
        start = rhs_.start;
        item  = rhs_.item;
    endfunction: do_copy

    function string convert2string_time();
        string msg = "";
        $swrite(msg, "%s\n\tINPUT TIMES :", msg);
        foreach (start[it]) begin
            $swrite(msg, "%s\n\t\t%s : %0.2fns", msg, it, start[it]/1ns);
        end

        return msg;
    endfunction

    function string convert2string();
        string msg = "";

        $swrite(msg,"%s%s\n\tTAG  : %s\n\tDATA :\n%s", msg, this.convert2string_time(), this.tag, item.convert2string());
        return msg;
    endfunction
endclass

