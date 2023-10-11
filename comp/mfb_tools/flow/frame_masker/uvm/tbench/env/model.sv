// model.sv: Model of implementation
// Copyright (C) 2023 CESNET z. s. p. o.
// Author(s): Daniel Kondys <kondys@cesnet.cz>

// SPDX-License-Identifier: BSD-3-Clause


class model #(MFB_REGIONS, MFB_ITEM_WIDTH, MFB_META_WIDTH) extends uvm_component;
    `uvm_component_param_utils(frame_masker::model #(MFB_REGIONS, MFB_ITEM_WIDTH, MFB_META_WIDTH))

    localparam string DUT_PATH = "testbench.DUT_U.VHDL_DUT_U";

    uvm_tlm_analysis_fifo #(uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))) input_data;
    uvm_tlm_analysis_fifo #(uvm_common::model_item #(uvm_logic_vector::sequence_item #(MFB_META_WIDTH)))       input_meta;
    uvm_analysis_port     #(uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))) out_data;
    uvm_analysis_port     #(uvm_common::model_item #(uvm_logic_vector::sequence_item #(MFB_META_WIDTH)))       out_meta;


    function new(string name = "model", uvm_component parent = null);
        super.new(name, parent);

        input_data = new("input_data", this);
        input_meta = new("input_meta", this);
        out_data   = new("out_data",   this);
        out_meta   = new("out_meta",   this);

    endfunction


    task run_mask_packets();

        frame_masker::probe_cbs#(MFB_REGIONS)                                             discards;
        uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)) input_data_tr;
        uvm_common::model_item #(uvm_logic_vector::sequence_item #(MFB_META_WIDTH))       input_meta_tr;
        logic discard;

        discards = frame_masker::probe_cbs#(MFB_REGIONS)::type_id::create("discards", this);
        //register
        uvm_probe::pool::get_global_pool().get({"probe_event_component_", DUT_PATH, ".probe_mask2discard"}).add_callback(discards);


        forever begin
            
            string msg = "\n";

            discards.get(discard);
            input_data.get(input_data_tr);
            input_meta.get(input_meta_tr);

            $swrite(msg, "%s Processing packet:\n", msg);
            $swrite(msg, "%s %s\n", msg, input_data_tr.convert2string());
            $swrite(msg, "%s With metadata:\n", msg);
            $swrite(msg, "%s %s\n", msg, input_meta_tr.convert2string());

            if (MFB_REGIONS > 1) begin
                if (discard == 0) begin
                    out_data.write(input_data_tr);
                    out_meta.write(input_meta_tr);
                    $swrite(msg, "%s Packet WAS NOT discarded!\n", msg);
                    // $write(msg, "%s INPUT META\n", msg);
                    // $swrite(msg, "%s %s\n", msg, input_meta_tr.convert2string());
                    // `uvm_info(get_type_name(), msg, UVM_NONE)
                end else begin
                    $swrite(msg, "%s Packet WAS discarded!\n", msg);
                end
            end else begin
                out_data.write(input_data_tr);
                out_meta.write(input_meta_tr);
            end

            `uvm_info(get_type_name(), msg, UVM_HIGH)
        end

    endtask

    task run_phase(uvm_phase phase);

        run_mask_packets();

    endtask
endclass
