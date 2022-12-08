//-- model.sv: Model of implementation
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 


class model #(LUT_WIDTH, REG_DEPTH) extends uvm_component;
    `uvm_component_param_utils(uvm_pipe::model#(LUT_WIDTH, REG_DEPTH))
    
    // Model inputs
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(REG_DEPTH)) model_mvb_in;

    uvm_analysis_port #(uvm_logic_vector::sequence_item #(LUT_WIDTH)) model_mvb_out;
    local regmodel#(REG_DEPTH) m_regmodel;

    function new(string name = "model", uvm_component parent = null);
        super.new(name, parent);

        model_mvb_in        = new("model_mvb_in",  this);
        model_mvb_out       = new("model_mvb_out", this);

    endfunction

    function void regmodel_set(regmodel#(REG_DEPTH) m_regmodel);
        this.m_regmodel = m_regmodel;
    endfunction


    task run_phase(uvm_phase phase);

        uvm_logic_vector::sequence_item #(REG_DEPTH) tr_mvb_in;
        uvm_logic_vector::sequence_item #(LUT_WIDTH) tr_mvb_out;
        uvm_reg_data_t value;
        uvm_reg_data_t value_in;
        uvm_status_e   status;

        forever begin
            tr_mvb_out = uvm_logic_vector::sequence_item #(LUT_WIDTH)::type_id::create("tr_mvb_out");

            model_mvb_in.get(tr_mvb_in);
            value_in = tr_mvb_in.data/4;
            m_regmodel.lut.read(status, value_in, value);

            tr_mvb_out.data = value;
            model_mvb_out.write(tr_mvb_out);

        end
    endtask
endclass
