/*
 * file       : fifo.sv
 * Copyright (C) 2023 CESNET z. s. p. o.
 * description:
 * date       : 2023
 * author     : Radek Iša <isa@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/

virtual class fifo #(type ITEM_TYPE) extends uvm_component;
    `uvm_component_param_utils(uvm_common::fifo#(ITEM_TYPE))

    protected ITEM_TYPE queue[$];

    function new (string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    protected function void push_back(ITEM_TYPE item);
        queue.push_back(item);
    endfunction

    virtual function void flush();
        queue.delete();
    endfunction

    virtual function int unsigned used();
        return (size() != 0);
    endfunction

    function int unsigned size();
        return queue.size();
    endfunction

    function void try_get(output ITEM_TYPE tr);
        if(queue.size() != 0) begin
            tr = queue.pop_front();
        end else begin
            tr = null;
        end
    endfunction

    task get(output ITEM_TYPE tr);
        wait(queue.size() != 0);
        tr = queue.pop_front();
    endtask
endclass

////////////////////////////////////////////////
// SIMPLE FIFO 
class fifo_convertor#(type INPUT_ITEM) extends fifo#(INPUT_ITEM);
    `uvm_component_param_utils(uvm_common::fifo_convertor#(INPUT_ITEM))

    typedef fifo_convertor#(INPUT_ITEM) this_type;
    uvm_analysis_imp_export#(INPUT_ITEM, this_type) analysis_export;

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
    endfunction

    virtual function void write_export(INPUT_ITEM tr);
        this.push_back(tr);
    endfunction
endclass

////////////////////////////////////////////////
// Convert item to model_item
class fifo_model_input#(type INPUT_ITEM) extends fifo#(model_item#(INPUT_ITEM));
    `uvm_component_param_utils(uvm_common::fifo_model_input#(INPUT_ITEM))

    typedef fifo_model_input#(INPUT_ITEM) this_type;
    uvm_analysis_imp_export#(INPUT_ITEM, this_type) analysis_export;
    protected string tag_name;
    protected int unsigned received;

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        received = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(string)::get(this, "", "tag", tag_name)) begin
            tag_name = this.get_full_name();
        end
    endfunction

    virtual function void write_export(INPUT_ITEM tr);
        model_item#(INPUT_ITEM) item;

        item = model_item#(INPUT_ITEM)::type_id::create("item", this);
        item.item  = tr;
        item.tag   = tag_name;
        item.start[tag_name] = $time();
        this.push_back(item);

        received++;
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(this.get_full_name(), $sformatf("\n\tReceive %0d transactions", received), UVM_LOW)
    endfunction

endclass

