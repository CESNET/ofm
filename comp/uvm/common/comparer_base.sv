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

    typedef struct {
        time     in_time;
        DUT_ITEM in_item;
    } dut_item_t;

    time                    dut_tr_timeout;
    time                    model_tr_timeout;
    model_item#(MODEL_ITEM) model_items[$];
    dut_item_t              dut_items[$];

    int unsigned compared;
    int unsigned errors;

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
        compared = 0;
        errors = 0;
        dut_tr_timeout  = 10s;
        model_tr_timeout = 0ns;
        analysis_imp_model = new("analysis_imp_model", this);
        analysis_imp_dut   = new("analysis_imp_dut"  , this);
    endfunction

    function void dut_tr_timeout_set(time timeout);
        dut_tr_timeout = timeout;
    endfunction

    function void model_tr_timeout_set(time timeout);
        model_tr_timeout = timeout;
    endfunction

    function int unsigned suceess();
        return (errors == 0);
    endfunction

    function void flush();
        model_items.delete();
    endfunction

    virtual function int unsigned used();
        return (model_items.size() != 0 || dut_items.size() != 0);
    endfunction

    virtual function void write_model(model_item#(MODEL_ITEM) tr);
        `uvm_fatal(this.get_full_name(), "WRITE MODEL FUNCTION IS NOT IMPLEMENTED");
    endfunction

    virtual function void write_dut(DUT_ITEM tr);
        `uvm_fatal(this.get_full_name(), "WRITE DUT FUNCTION IS NOT IMPLEMENTED");
    endfunction

    pure virtual function int unsigned compare(MODEL_ITEM tr_model, DUT_ITEM tr_dut);
    pure virtual function string message(MODEL_ITEM tr_model, DUT_ITEM tr_dut);

    function string dut_tr_get(MODEL_ITEM tr, time tr_time);
        string msg = "";
        for (int unsigned it = 0; it < dut_items.size(); it++) begin
            $swrite(msg, "%s\n\nOutput time %0dns (%0dns) \n%s", msg, dut_items[it].in_time/1ns, dut_items[it].in_time - tr_time, this.message(tr, dut_items[it].in_item));
        end
        return msg;
    endfunction

    function string model_tr_get(DUT_ITEM tr);
        string msg = "";
        for (int unsigned it = 0; it < model_items.size(); it++) begin
            $swrite(msg, "%s\n\n%s\n%s", msg, model_items[it].convert2string_time(), this.message(model_items[it].item, tr));
        end
        return msg;
    endfunction

    task run_wait_delay_check();
        time delay;
        forever begin
            wait(model_items.size() > 0);
            delay = $time() - model_items[0].time_last();
            if (delay >= dut_tr_timeout) begin
                errors++;
               `uvm_error(this.get_full_name(), $sformatf("\n\tTransaction from DUT is delayd %0dns. Probubly stack.\n%s\n\nDUT transactions:\n%s", delay/1ns, model_items[0].convert2string(), this.dut_tr_get(model_items[0].item, model_items[0].time_last())));
                model_items.delete(0);
            end else begin
                #(dut_tr_timeout - delay);
            end
        end
    endtask

    task run_dut_delay_check();
        time delay;
        forever begin
            wait(dut_items.size() > 0);
            delay = $time() - dut_items[0].in_time;
            if (delay >= model_tr_timeout) begin
                errors++;
                `uvm_error(this.get_full_name(), $sformatf("\n\tTransaction from DUT is unexpected. Output time %0dns. Delay %0dns. Probubly unexpected transaction.\n%s\n\n%s", dut_items[0].in_time, delay/1ns, dut_items[0].in_item.convert2string(), this.model_tr_get(dut_items[0].in_item)));
                dut_items.delete(0);
            end else begin
                #(model_tr_timeout - delay);
            end
        end
    endtask

    task run_phase(uvm_phase phase);
        fork
            run_wait_delay_check();
            run_dut_delay_check();
        join_none;

        forever begin
            string  msg = "";

            #(COMPARED_PRINT_WAIT)
            `uvm_info(this.get_full_name(), $sformatf("\n\tCompared %0d transactions in time %0dns", compared, $time()/1ns), UVM_LOW);
        end
    endtask

    function void check_phase(uvm_phase phase);
        if (model_items.size() != 0) begin
            string msg;

            $swrite(msg, "\n\t%0d transaction left in DUT. Errors/Compared %0d/%0d\n", model_items.size(), errors, compared);
            for (int unsigned it = 0; it < model_items.size(); it++) begin
                $swrite(msg, "%s\n%s", msg, model_items[it].convert2string());
            end
            `uvm_error(this.get_full_name(), msg);
        end
    endfunction
endclass

/////////////////////////////////////////////
// Ordered checker. All data is compared chronologicaly.
virtual class comparer_base_ordered#(type MODEL_ITEM, DUT_ITEM = MODEL_ITEM) extends comparer_base#(MODEL_ITEM, DUT_ITEM);

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void write_model(model_item#(MODEL_ITEM) tr);
        if (dut_items.size() != 0) begin
            dut_item_t item;

            item = dut_items.pop_front();
            if (this.compare(tr.item, item.in_item) == 0) begin
                errors++;
                `uvm_error(this.get_full_name(), $sformatf("\n\tTransaction doesn't match.\n\t\tInput times %s\n\t\toutput time %0dns\n%s\n", tr.convert2string_time(), item.in_time/1ns, this.message(item.in_item, tr.item)));
            end else begin
                compared++;
            end
        end else begin
            model_items.push_back(tr);
        end
    endfunction

    virtual function void write_dut(DUT_ITEM tr);
        if (model_items.size() != 0) begin
            model_item#(MODEL_ITEM) item;

            item = model_items.pop_front();
            if (this.compare(item.item, tr) == 0) begin
                errors++;
                `uvm_error(this.get_full_name(), $sformatf("\n\tTransaction doesn't match.\n\t\tInput times %s\n\t\toutput time %0dns\n%s\n", item.convert2string_time(), $time()/1ns, this.message(tr, item.item)));
            end else begin
                compared++;
            end
        end else begin
            dut_items.push_back({$time(), tr});
        end
    endfunction
endclass

/////////////////////////////////////////////
// Disordered checker. Data is not check chronologicaly 
virtual class comparer_base_disordered#(type MODEL_ITEM, DUT_ITEM = MODEL_ITEM) extends comparer_base#(MODEL_ITEM, DUT_ITEM);

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction


    virtual function void write_model(model_item#(MODEL_ITEM) tr);
        int unsigned w_end = 0;
        int unsigned it    = 0;
        //try get item from DUT
        while (it < dut_items.size() && w_end == 0) begin
            w_end = compare(tr.item, dut_items[it].in_item);
            if (w_end == 0) begin
                it++;
            end else begin
                compared++;
                dut_items.delete(it);
            end
        end

        if (w_end == 0) begin
            model_items.push_back(tr);
        end
    endfunction

    virtual function void write_dut(DUT_ITEM tr);
        int unsigned w_end = 0;
        int unsigned it    = 0;
        //try get item from DUT
        while (it < model_items.size() && w_end == 0) begin
            w_end = compare(model_items[it].item, tr);
            if (w_end == 0) begin
                it++;
            end else begin
                compared++;
                model_items.delete(it);
            end
        end

        if (w_end == 0) begin
            dut_items.push_back('{$time(), tr});
        end
    endfunction
endclass
