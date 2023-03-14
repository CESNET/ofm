//-- model.sv: Model of implementation
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Copyright (C) 2023 CESNET z. s. p. o.
//-- Author(s): Radek Iša  <isa@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 


//uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH))                     input_data;
//uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(SEL_WIDTH + META_WIDTH)) input_meta;


class model_data #(ITEM_WIDTH, META_WIDTH) extends uvm_object;
    `uvm_object_param_utils(uvm_splitter_simple::model_data #(ITEM_WIDTH, META_WIDTH))

    uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)  data;
    uvm_logic_vector::sequence_item #(META_WIDTH)       meta;

    function new(string name = "");
        super.new(name);
    endfunction
endclass


class model #(ITEM_WIDTH, META_WIDTH, CHANNELS) extends uvm_component;
    `uvm_component_param_utils(uvm_splitter_simple::model#(ITEM_WIDTH, META_WIDTH, CHANNELS))

    localparam SEL_WIDTH = $clog2(CHANNELS);

    uvm_common::fifo  #(uvm_common::model_item#(model_data#(ITEM_WIDTH, SEL_WIDTH + META_WIDTH))) in;
    uvm_analysis_port #(uvm_common::model_item#(model_data#(ITEM_WIDTH, META_WIDTH)))             out[CHANNELS];

    function new(string name = "model", uvm_component parent = null);
        super.new(name, parent);

        in = null;
        for (int unsigned it = 0; it < CHANNELS; it++) begin
            string str_it;

            str_it.itoa(it);
            out[it] = new({"out_data_", str_it}, this);
        end
    endfunction

    function void reset();
       in.flush();
    endfunction

    task run_phase(uvm_phase phase);
        uvm_common::model_item#(model_data #(ITEM_WIDTH, SEL_WIDTH + META_WIDTH)) tr_input;
        uvm_common::model_item#(model_data #(ITEM_WIDTH, META_WIDTH)) tr_output;
        int unsigned channel;

        if (in == null) begin
            `uvm_fatal(this.get_full_name(), "\n\tInput fifo \"in\" is null");
        end

        forever begin
            in.get(tr_input);

            channel = tr_input.item.meta.data[SEL_WIDTH + META_WIDTH-1 : META_WIDTH];

            if (channel >= CHANNELS) begin
                string msg;
                $swrite(msg, "\n\tWrong channel num %0d Channel range is 0-%0d", channel, CHANNELS-1);
                `uvm_fatal(this.get_full_name(), msg);
            end else begin
                tr_output = uvm_common::model_item#(model_data#(ITEM_WIDTH, META_WIDTH))::type_id::create("tr_output", this);
                tr_output.tag   = tr_input.tag;
                tr_output.start = tr_input.start;
                tr_output.item  =  model_data #(ITEM_WIDTH, META_WIDTH)::type_id::create("tr_output.item", this);
                //create data
                tr_output.item.data = tr_input.item.data;
                //create meta
                tr_output.item.meta      = uvm_logic_vector::sequence_item #(META_WIDTH)::type_id::create("tr_output_meta");
                tr_output.item.meta.data = tr_input.item.meta.data[META_WIDTH-1:0];
                out[channel].write(tr_output);
            end
        end
    endtask
endclass
