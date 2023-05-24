// model.sv: Model of implementation
// Copyright (C) 2023 CESNET z. s. p. o.
// Author(s): Daniel Kříž <danielkriz@cesnet.cz>

// SPDX-License-Identifier: BSD-3-Clause

class ts_limiter_item#(MFB_ITEM_WIDTH, TIMESTAMP_WIDTH);

    logic [TIMESTAMP_WIDTH-1 : 0]                           timestamp;
    uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH) data_tr;

    function string convert2string();
        string msg;

        $swrite(msg, "\n\ttimestamp %0d", timestamp);
        return msg;
    endfunction

endclass


class model #(MFB_ITEM_WIDTH, RX_MFB_META_WIDTH, TX_MFB_META_WIDTH, TIMESTAMP_WIDTH) extends uvm_component;
    `uvm_component_param_utils(uvm_timestamp_limiter::model #(MFB_ITEM_WIDTH, RX_MFB_META_WIDTH, TX_MFB_META_WIDTH, TIMESTAMP_WIDTH))

    uvm_tlm_analysis_fifo #(uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)))              input_data;
    uvm_tlm_analysis_fifo #(uvm_common::model_item #(uvm_logic_vector::sequence_item #(RX_MFB_META_WIDTH)))                 input_meta;
    uvm_analysis_port #(uvm_common::model_item #(uvm_timestamp_limiter::ts_limiter_item#(MFB_ITEM_WIDTH, TIMESTAMP_WIDTH))) out_data;
    uvm_analysis_port #(uvm_common::model_item #(uvm_logic_vector::sequence_item #(TX_MFB_META_WIDTH)))                     out_meta;

    function new(string name = "model", uvm_component parent = null);
        super.new(name, parent);

        input_data = new("input_data", this);
        input_meta = new("input_meta", this);
        out_data   = new("out_data", this);
        out_meta   = new("out_meta", this);

    endfunction

    task run_phase(uvm_phase phase);

        uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))                  tr_input_data;
        uvm_common::model_item #(uvm_logic_vector::sequence_item #(RX_MFB_META_WIDTH))                     tr_input_meta;
        uvm_common::model_item #(uvm_timestamp_limiter::ts_limiter_item#(MFB_ITEM_WIDTH, TIMESTAMP_WIDTH)) tr_output_data;
        uvm_common::model_item #(uvm_logic_vector::sequence_item #(TX_MFB_META_WIDTH))                     tr_output_meta;

        forever begin
            string msg = "\n";

            input_data.get(tr_input_data);
            input_meta.get(tr_input_meta);

            tr_output_data      = uvm_common::model_item #(uvm_timestamp_limiter::ts_limiter_item#(MFB_ITEM_WIDTH, TIMESTAMP_WIDTH))::type_id::create("tr_output_data");
            tr_output_data.item = new();
            tr_output_data.item.data_tr = uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)::type_id::create("tr_output_data_item");
            tr_output_meta      = uvm_common::model_item #(uvm_logic_vector::sequence_item #(TX_MFB_META_WIDTH))::type_id::create("tr_output_data");
            tr_output_meta.item = uvm_logic_vector::sequence_item #(TX_MFB_META_WIDTH)::type_id::create("tr_output_data_item");

            $swrite(msg, "%s INPUT DATA\n", msg);
            $swrite(msg, "%s %s\n", msg, tr_input_data.convert2string());
            $swrite(msg, "%s INPUT TS %h\n", msg, tr_input_meta.item.data[TIMESTAMP_WIDTH-1 : 0]);
            $swrite(msg, "%s INPUT META %h\n", msg, tr_input_meta.item.data[RX_MFB_META_WIDTH-1 : TIMESTAMP_WIDTH]);
            $swrite(msg, "%s %s\n", msg, tr_input_meta.convert2string());

            tr_output_data.time_array_add(tr_input_data.start);
            tr_output_data.time_array_add(tr_input_meta.start);
            tr_output_meta.time_array_add(tr_input_data.start);
            tr_output_meta.time_array_add(tr_input_meta.start);

            tr_output_meta.item.data = tr_input_meta.item.data[RX_MFB_META_WIDTH-1 : TIMESTAMP_WIDTH];
            $swrite(msg, "%s OUTPUT META\n", msg);
            $swrite(msg, "%s %s\n", msg, tr_output_meta.convert2string());
            `uvm_info(get_type_name(), msg, UVM_MEDIUM)

            tr_output_data.item.data_tr.copy(tr_input_data.item);
            tr_output_data.item.timestamp = tr_input_meta.item.data[TIMESTAMP_WIDTH-1 : 0];

            out_data.write(tr_output_data);
            if (TX_MFB_META_WIDTH > 0) begin 
                out_meta.write(tr_output_meta);
            end

        end

    endtask
endclass
