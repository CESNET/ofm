// model.sv: Model of implementation
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause 


class model #(ITEM_WIDTH) extends uvm_component;
    `uvm_component_param_utils(uvm_ptc_mfb2pcie_axi::model#(ITEM_WIDTH))

    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item #(ITEM_WIDTH))   input_data;
    uvm_analysis_port #(uvm_logic_vector_array::sequence_item #(ITEM_WIDTH))       out_data;

    function new(string name = "model", uvm_component parent = null);
        super.new(name, parent);

        input_data    = new("input_data", this);
        out_data      = new("out_data", this);

    endfunction


    task run_phase(uvm_phase phase);

        uvm_logic_vector_array::sequence_item #(ITEM_WIDTH) tr_input_packet;

        forever begin

            input_data.get(tr_input_packet);
            out_data.write(tr_input_packet);

        end

    endtask
endclass
