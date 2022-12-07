//-- model.sv: Model of implementation
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 


class model #(ITEM_WIDTH) extends uvm_component;
    `uvm_component_param_utils(uvm_pipe::model#(ITEM_WIDTH))
    
    // Model inputs
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(ITEM_WIDTH)) model_mvb_in;

    uvm_analysis_port #(uvm_logic_vector::sequence_item #(ITEM_WIDTH)) model_mvb_out;

    function new(string name = "model", uvm_component parent = null);
        super.new(name, parent);

        model_mvb_in        = new("model_mvb_in",  this);
        model_mvb_out       = new("model_mvb_out", this);

    endfunction

    task run_phase(uvm_phase phase);

        uvm_logic_vector::sequence_item #(ITEM_WIDTH) tr_mvb_in;
        uvm_logic_vector::sequence_item #(ITEM_WIDTH) tr_mvb_out;

        forever begin
            tr_mvb_out = uvm_logic_vector::sequence_item #(ITEM_WIDTH)::type_id::create("tr_mvb_out");

            model_mvb_in.get(tr_mvb_in);
            tr_mvb_out.copy(tr_mvb_in);
            model_mvb_out.write(tr_mvb_out);

        end
    endtask
endclass
