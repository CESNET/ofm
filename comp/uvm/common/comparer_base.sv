/*
 * file       : comparer_base.sv
 * Copyright (C) 2022 CESNET z. s. p. o.
 * description: this component compare two output out of order. IF componet stays
 *              too long in fifo then erros is goint to occure.
 * date       : 2022
 * author     : Radek Iša <isa@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/

virtual class comparer_base#(type MODEL_ITEM, DUT_ITEM = MODEL_ITEM) extends uvm_component;

    localparam COMPARED_PRINT_WAIT = 5ms;

    typedef comparer_base#(MODEL_ITEM, DUT_ITEM) this_type;
    uvm_analysis_imp_model#(model_item#(MODEL_ITEM), this_type) analysis_imp_model;
    uvm_analysis_imp_dut  #(DUT_ITEM, this_type)                analysis_imp_dut;

    time                    delay_max;
    model_item#(MODEL_ITEM) model_items[$];

    int unsigned compared;
    int unsigned errors;
    int unsigned time_errors;

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
        compared = 0;
        errors = 0;
        time_errors = 0;
        delay_max = 10s;
        analysis_imp_model = new("analysis_imp_model", this);
        analysis_imp_dut   = new("analysis_imp_dut"  , this);
    endfunction

    function void delay_max_set(time max);
        delay_max = max;
    endfunction

    function int unsigned suceess();
        return (errors == 0) && (time_errors == 0);
    endfunction

    function void flush();
        model_items.delete();
    endfunction

    function int unsigned used();
        return (model_items.size() != 0);
    endfunction

    function void write_model(model_item#(MODEL_ITEM) tr);
        model_items.push_back(tr);
    endfunction

    virtual function void write_dut(DUT_ITEM tr);
        `uvm_fatal(this.get_full_name(), "\n\tThis function is virtual and have to be reimplemented");
    endfunction

    pure virtual function int unsigned compare(MODEL_ITEM tr_model, DUT_ITEM tr_dut);
    pure virtual function string message(MODEL_ITEM tr_model, DUT_ITEM tr_dut);

    task run_phase(uvm_phase phase);
        forever begin
            string  msg = "";

            #(COMPARED_PRINT_WAIT)
            $swrite(msg, "\n\tCompared %0d transactions in time %0dns", compared, $time()/1ns);
            `uvm_info(this.get_full_name(), msg, UVM_NONE);
        end
    endtask

endclass

/////////////////////////////////////////////
// Ordered checker. All data is compared chronologicaly.
virtual class comparer_base_ordered#(type MODEL_ITEM, DUT_ITEM = MODEL_ITEM) extends comparer_base#(MODEL_ITEM, DUT_ITEM);

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    //virtual function void process(DUT_ITEM tr);
    function void write_dut(DUT_ITEM tr);
        model_item#(MODEL_ITEM) tr_model;

        compared++;
        tr_model = model_items.pop_front();
        if (!this.compare(tr_model, tr)) begin
            string msg;
            errors++;
            $swrite(msg, "\n\tTransaction compared %0d erros %0d\n\tDUT transactin doesnt compare model transaction\n%s", compared, errors, this.message(tr_model, tr));
            `uvm_error(this.get_full_name(), msg);
        end
    endfunction
endclass

/////////////////////////////////////////////
// Disordered checker. Data is not check chronologicaly 
virtual class comparer_base_disordered#(type MODEL_ITEM, DUT_ITEM = MODEL_ITEM) extends comparer_base#(MODEL_ITEM, DUT_ITEM);

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    //virtual function void process(DUT_ITEM tr);
    function void write_dut(DUT_ITEM tr);
        int unsigned index = 0;
        time   time_act = $time();

        time_act = $time();
        if (model_items.size() > 0 && (time_act - model_items[0].start) > delay_max) begin
            string msg = "";
            int unsigned it = 0;
            time_errors++;

            while (it < model_items.size() && (time_act - model_items[it].start) > delay_max) begin
                $swrite(msg, "%s\n\tPacket received in %0dns is probubly stuck in design actual delay is %0dns\n%s", msg, model_items[it].start/1ns, (time_act - model_items[it].start)/1ns, model_items[it].item.convert2string());
                it++;
            end

            $swrite(msg, "%s\nActual transactions is\n%s", msg, tr.convert2string());
           `uvm_error(this.get_full_name(), msg);
        end

        compared++;
        while (index < model_items.size() && compare(model_items[index].item, tr) == 0)begin
           index++;
        end

        if (index >= model_items.size()) begin
            int unsigned it_end;
            string msg;
            errors++;
            $swrite(msg, "\n\tTransaction compared %0d erros %0d\n\tDUT transactin doesnt compare any of model %0d transactions in fifo\n%s", compared, errors, model_items.size(), tr.convert2string());
            it_end = 10 < model_items.size() ? 10 : model_items.size();
            for (int unsigned it = 0; it < it_end; it++) begin
                $swrite(msg, "%s\n\n\tModel Transaction %0d input in %0dns%s", msg, it, model_items[it].start/1ns, message(model_items[it].item, tr));
            end
            `uvm_error(this.get_full_name(), msg);
        end else begin
            model_items.delete(index);
        end
    endfunction
endclass
