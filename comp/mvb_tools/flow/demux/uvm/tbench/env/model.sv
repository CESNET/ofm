// model.sv: Model of implementation
// Copyright (C) 2023 CESNET z. s. p. o.
// Author(s): Oliver Gurka <xgurka00@stud.fit.vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


class model #(ITEM_WIDTH, TX_MVB_CNT) extends uvm_component;
    `uvm_component_param_utils(uvm_mvb_demux::model#(ITEM_WIDTH, TX_MVB_CNT))
    
    // Model inputs
    uvm_tlm_analysis_fifo #(uvm_common::model_item #(uvm_logic_vector::sequence_item #(ITEM_WIDTH + $clog2(TX_MVB_CNT)))) model_mvb_in;
    uvm_analysis_port #(uvm_common::model_item #(uvm_logic_vector::sequence_item #(ITEM_WIDTH))) model_mvb_out[TX_MVB_CNT - 1 : 0];

    function new(string name = "model", uvm_component parent = null);
        super.new(name, parent);

        model_mvb_in     = new("model_mvb_in",  this);
        for (int i = 0; i < TX_MVB_CNT; i++) begin
            model_mvb_out[i] = new($sformatf("model_mvb_out_%0d", i), this);
        end
    endfunction

    task run_phase(uvm_phase phase);
        int unsigned port = 0;

        uvm_common::model_item #(uvm_logic_vector::sequence_item #(ITEM_WIDTH + $clog2(TX_MVB_CNT))) tr_mvb_in;
        uvm_common::model_item #(uvm_logic_vector::sequence_item #(ITEM_WIDTH)) tr_mvb_out;


        forever begin
            model_mvb_in.get(tr_mvb_in);
            tr_mvb_out = uvm_common::model_item #(uvm_logic_vector::sequence_item #(ITEM_WIDTH))::type_id::create("tr_mvb_out");

            port          = tr_mvb_in.item.data[ITEM_WIDTH + $clog2(TX_MVB_CNT) - 1 : ITEM_WIDTH];

            tr_mvb_out.item = uvm_logic_vector::sequence_item #(ITEM_WIDTH)::type_id::create("tr_mvb_out_si");
            tr_mvb_out.item.data = tr_mvb_in.item.data[ITEM_WIDTH - 1 : 0];
            model_mvb_out[port].write(tr_mvb_out);
        end
    endtask
endclass
