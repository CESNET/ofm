// scoreboard.sv: Scoreboard for verification
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause 

class scoreboard#(ITEM_WIDTH) extends uvm_scoreboard;
    `uvm_component_param_utils(uvm_ptc_pcie_axi2mfb::scoreboard#(ITEM_WIDTH))

    int unsigned print_regions = 2;
    int unsigned print_region_width = 8;

    int unsigned compared;
    int unsigned errors;

    uvm_analysis_export #(uvm_logic_vector_array::sequence_item #(ITEM_WIDTH))    input_data;
    uvm_analysis_export #(uvm_logic_vector_array::sequence_item #(ITEM_WIDTH))    out_data;

    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item #(ITEM_WIDTH))  dut_data;
    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item #(ITEM_WIDTH))  model_data;

    model#(ITEM_WIDTH) m_model;

    // Contructor of scoreboard.
    function new(string name, uvm_component parent);
        super.new(name, parent);

        input_data = new("input_data", this);
        out_data   = new("out_data", this);
        dut_data   = new("dut_data", this);
        model_data = new("model_data", this);
        compared   = 0;
        errors   = 0;

    endfunction

    function int unsigned used();
        int unsigned ret = 0;
        ret |= (dut_data.used() != 0);
        ret |= (model_data.used() != 0);
        return ret;
    endfunction

    function void build_phase(uvm_phase phase);
        m_model = model#(ITEM_WIDTH)::type_id::create("m_model", this);
    endfunction

    function void connect_phase(uvm_phase phase);

        // connects input data to the input of the model
        input_data.connect(m_model.input_data.analysis_export);

        // processed data from the output of the model connected to the analysis fifo
        m_model.out_data.connect(model_data.analysis_export);
        // connects the data from the DUT to the analysis fifo
        out_data.connect(dut_data.analysis_export);

    endfunction

    task run_phase(uvm_phase phase);

        uvm_logic_vector_array::sequence_item #(ITEM_WIDTH) tr_dut;
        uvm_logic_vector_array::sequence_item #(ITEM_WIDTH) tr_model;

        forever begin
            string debug_msg = "";

            model_data.get(tr_model);
            dut_data.get(tr_dut);

            $swrite(debug_msg, "%s\n\t Model TR: %s\n", debug_msg, tr_model.convert2block(print_regions, print_region_width));
            $swrite(debug_msg, "%s\n\t DUT TR: %s\n", debug_msg, tr_dut.convert2block(print_regions, print_region_width));
            `uvm_info(this.get_full_name(), debug_msg ,UVM_FULL);

            compared++;

            if (tr_model.compare(tr_dut) == 0) begin
                string msg;

                $swrite(msg, "\n\tPacket comparison failed! \n\tModel packet:\n%s\n\tDUT packet:\n%s", tr_model.convert2block(print_regions, print_region_width), tr_dut.convert2block(print_regions, print_region_width));
                `uvm_error(this.get_full_name(), msg);
                errors++;
            end
        end

    endtask

    function void report_phase(uvm_phase phase);

        string msg = "";

        $swrite(msg, "%s\n\t Transaction compared %0d, errors %0d", msg, compared, errors);
        $swrite(msg, "%s\n\t DUT USED: [%0d] Model USED: [%0d]", msg, dut_data.used(), model_data.used());

       if (errors == 0 && this.used() == 0) begin
           `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION SUCCESS      ----\n\t---------------------------------------"}, UVM_NONE)
       end else begin
           `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION FAIL      ----\n\t---------------------------------------"}, UVM_NONE)
       end
    endfunction

endclass
