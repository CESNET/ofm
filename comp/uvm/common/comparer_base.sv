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

class comparer_dut #(type ITEM_TYPE);
    int unsigned in_id;
    time      in_time;
    ITEM_TYPE in_item;

    function new (int unsigned id = 0, time t = 0ns, ITEM_TYPE item = null);
        in_id   = id;
        in_time = t;
        in_item = item;
    endfunction
endclass


virtual class comparer_base#(type MODEL_ITEM, DUT_ITEM = MODEL_ITEM) extends uvm_component;

    localparam COMPARED_PRINT_WAIT = 5ms;

    typedef comparer_base#(MODEL_ITEM, DUT_ITEM) this_type;
    uvm_analysis_imp_model#(model_item#(MODEL_ITEM), this_type) analysis_imp_model;
    uvm_analysis_imp_dut  #(DUT_ITEM, this_type)                analysis_imp_dut;

    time                    dut_tr_timeout;
    time                    model_tr_timeout;

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
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

    pure virtual function int unsigned success();
    pure virtual function void flush();
    pure virtual function int unsigned used();

    virtual function void write_model(model_item#(MODEL_ITEM) tr);
        `uvm_fatal(this.get_full_name(), "WRITE MODEL FUNCTION IS NOT IMPLEMENTED");
    endfunction

    virtual function void write_dut(DUT_ITEM tr);
        `uvm_fatal(this.get_full_name(), "WRITE DUT FUNCTION IS NOT IMPLEMENTED");
    endfunction

    pure virtual function int unsigned compare(MODEL_ITEM tr_model, DUT_ITEM tr_dut);
    pure virtual function string message(MODEL_ITEM tr_model, DUT_ITEM tr_dut);


    pure virtual task run_model_delay_check();
    pure virtual task run_dut_delay_check();
    pure virtual function string info();

    task run_phase(uvm_phase phase);
        fork
            run_model_delay_check();
            run_dut_delay_check();
            print_info();
        join_none;
    endtask

    task print_info();
        forever begin
            #(COMPARED_PRINT_WAIT)
            `uvm_info(this.get_full_name(), $sformatf("Time : %0dns%s", $time()/1ns, info()), UVM_LOW);
        end
    endtask

    function void check_phase(uvm_phase phase);
        int unsigned index_valid;
        string index;
        string msg;

        if (this.used()) begin
            msg = "";
            `uvm_error(this.get_full_name(), {"\n\tWait for some transaction", info()});
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info(this.get_full_name(), info(), UVM_NONE);
    endfunction
endclass

