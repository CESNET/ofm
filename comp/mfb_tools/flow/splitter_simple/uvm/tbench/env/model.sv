//-- model.sv: Model of implementation
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Radek Iša  <isa@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

class model #(META_WIDTH, CHANNELS) extends uvm_component;
    `uvm_component_param_utils(uvm_splitter_simple::model#(META_WIDTH, CHANNELS))

    localparam SEL_WIDTH = $clog2(CHANNELS);
    

    uvm_tlm_analysis_fifo #(uvm_byte_array::sequence_item)                             input_data;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(SEL_WIDTH + META_WIDTH)) input_meta;

    uvm_analysis_port #(uvm_byte_array::sequence_item)                 out_data[CHANNELS];
    uvm_analysis_port #(uvm_logic_vector::sequence_item #(META_WIDTH)) out_meta[CHANNELS];

    function new(string name = "model", uvm_component parent = null);
        super.new(name, parent);

        input_data = new("input_data", this);
        input_meta = new("input_meta", this);
        for (int unsigned it = 0; it < CHANNELS; it++) begin
            string str_it;

            str_it.itoa(it);
            out_data[it] = new({"out_data_", str_it}, this);
            out_meta[it] = new({"out_meta_", str_it}, this);
        end
    endfunction


    task run_phase(uvm_phase phase);
        int unsigned channel;
        uvm_byte_array::sequence_item                               tr_input_packet;
        uvm_logic_vector::sequence_item #(SEL_WIDTH + META_WIDTH)   tr_input_meta;
        uvm_logic_vector::sequence_item #(META_WIDTH)               tr_output_meta;

        forever begin
            input_data.get(tr_input_packet);
            input_meta.get(tr_input_meta);

            channel = tr_input_meta.data[SEL_WIDTH + META_WIDTH-1 : META_WIDTH];
            
            if (channel >= CHANNELS) begin
                string msg;
                $swrite(msg, "\n\tWrong channel num %0d Channel range is 0-%0d", channel, CHANNELS-1);
                `uvm_fatal(this.get_full_name(), msg);
            end else begin
                tr_output_meta      = uvm_logic_vector::sequence_item #(META_WIDTH)::type_id::create("tr_output_meta"); 
                tr_output_meta.data = tr_input_meta.data[META_WIDTH-1:0];
                out_data[channel].write(tr_input_packet);
                out_meta[channel].write(tr_output_meta);
            end
        end
    endtask
endclass
