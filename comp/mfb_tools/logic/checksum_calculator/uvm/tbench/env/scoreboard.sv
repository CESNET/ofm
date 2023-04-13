// scoreboard.sv: Scoreboard for verification
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause

class scoreboard #(META_WIDTH, MVB_DATA_WIDTH, MFB_ITEM_WIDTH, OFFSET_WIDTH, LENGTH_WIDTH, VERBOSITY) extends uvm_scoreboard;
    `uvm_component_param_utils(uvm_checksum_calculator::scoreboard #(META_WIDTH, MVB_DATA_WIDTH, MFB_ITEM_WIDTH, OFFSET_WIDTH, LENGTH_WIDTH, VERBOSITY))

    int unsigned compared;
    int unsigned errors;

    uvm_analysis_export #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)) input_mfb;
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(META_WIDTH))           input_meta;
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH+1))     out_mvb;

    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH+1)) dut_mvb;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH))   model_checksum_mvb;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(1))                model_bypass;

    model #(META_WIDTH, MVB_DATA_WIDTH, MFB_ITEM_WIDTH, OFFSET_WIDTH, LENGTH_WIDTH, VERBOSITY) m_model;

    // Contructor of scoreboard.
    function new(string name, uvm_component parent);
        super.new(name, parent);

        input_mfb          = new("input_mfb", this);
        input_meta         = new("input_meta", this);
        out_mvb            = new("out_mvb", this);

        dut_mvb            = new("dut_mvb", this);
        model_checksum_mvb = new("model_checksum_mvb", this);
        model_bypass       = new("model_bypass", this);
        compared           = 0;
        errors             = 0;

    endfunction

    function int unsigned used();
        int unsigned ret = 0;
        ret |= (dut_mvb.used()            != 0);
        ret |= (model_checksum_mvb.used() != 0);
        ret |= (model_bypass.used()          != 0);
        return ret;
    endfunction


    function void build_phase(uvm_phase phase);
        m_model    = model#(META_WIDTH, MVB_DATA_WIDTH, MFB_ITEM_WIDTH, OFFSET_WIDTH, LENGTH_WIDTH, VERBOSITY)::type_id::create("m_model", this);
    endfunction

    function void connect_phase(uvm_phase phase);

        // connects input data to the input of the model
        input_mfb.connect(m_model.input_mfb.analysis_export);
        input_meta.connect(m_model.input_meta.analysis_export);

        // processed data from the output of the model connected to the analysis fifo
        m_model.out_checksum_mvb.connect(model_checksum_mvb.analysis_export);
        m_model.out_bypass.connect(model_bypass.analysis_export);
        // connects the data from the DUT to the analysis fifo
        out_mvb.connect(dut_mvb.analysis_export);

    endfunction

    task run_phase(uvm_phase phase);

        uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH)   tr_dut_mvb;
        uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH+1) tr_dut_mvb_with_bypass;
        uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH)   tr_model_checksum_mvb;
        uvm_logic_vector::sequence_item #(1)                bypass_model;
        logic                                               bypass_dut;

        forever begin

            tr_dut_mvb = uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH)::type_id::create("tr_dut_mvb");

            model_bypass.get(bypass_model);
            model_checksum_mvb.get(tr_model_checksum_mvb);
            dut_mvb.get(tr_dut_mvb_with_bypass);

            bypass_dut      = tr_dut_mvb_with_bypass.data[MVB_DATA_WIDTH];
            tr_dut_mvb.data = tr_dut_mvb_with_bypass.data[MVB_DATA_WIDTH-1 : 0];


            // $write("BYPASS %h\n", bypass_dut);
            // $write("BYPASS MODEL %h\n", bypass_model.data);
            // $write("CHSUM Model\n");
            // `uvm_info(this.get_full_name(), tr_model_checksum_mvb.convert2string() ,UVM_MEDIUM)
            // $write("CHSUM DUT\n");
            // `uvm_info(this.get_full_name(), tr_dut_mvb.convert2string() ,UVM_MEDIUM)

            if (VERBOSITY >= 2) begin
                $write("BYPASS \n");
                `uvm_info(this.get_full_name(), bypass_model.convert2string() ,UVM_MEDIUM)
            end

            compared++;
            if ((compared % 1000) == 0) begin
                $write("%d transactions were compared\n", compared);
            end

            if (bypass_model.data == 1'b0) begin
                if (tr_model_checksum_mvb.compare(tr_dut_mvb) == 0) begin
                    string msg;
                    errors++;

                    $swrite(msg, "%s\n\tComparison failed at packet number %d! \n\tModel checksum:\n%s\n\tDUT checksum:\n%s", msg, compared, tr_model_checksum_mvb.convert2string(), tr_dut_mvb.convert2string());
                    $swrite(msg, "%s\n\n\tModel BYPASS: %b\n\tDUT BYPASS: %b\n", msg, bypass_model.data[0], bypass_dut);
                    `uvm_error(this.get_full_name(), msg);
                end
            end

        end

    endtask

    function void report_phase(uvm_phase phase);

        if (errors == 0 && this.used() == 0) begin 
            string msg = "";

            $swrite(msg, "%s\nCompared packets: %0d", msg, compared);
            `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION SUCCESS      ----\n\t---------------------------------------"}, UVM_NONE)
        end else begin
            string msg = "";

            $swrite(msg, "%s\nCompared packets: %0d and errors %0d", msg, compared, errors);
            `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION FAILED       ----\n\t---------------------------------------"}, UVM_NONE)
        end

    endfunction

endclass
