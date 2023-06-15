// scoreboard.sv: Scoreboard for verification
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


class scoreboard #(HEADER_SIZE, MFB_ITEM_WIDTH, MVB_ITEM_WIDTH, VERBOSITY) extends uvm_scoreboard;
    `uvm_component_param_utils(uvm_superunpacketer::scoreboard #(HEADER_SIZE, MFB_ITEM_WIDTH, MVB_ITEM_WIDTH, VERBOSITY))

    int unsigned compared;
    int unsigned errors;

    uvm_analysis_export #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))       input_data;
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(MVB_ITEM_WIDTH))             input_mvb;
    uvm_analysis_export #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))       out_data;
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(HEADER_SIZE+MVB_ITEM_WIDTH)) out_meta;

    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))       dut_data;
    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))       model_data;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(HEADER_SIZE+MVB_ITEM_WIDTH)) dut_meta;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(HEADER_SIZE+MVB_ITEM_WIDTH)) model_meta;

    model #(HEADER_SIZE, MFB_ITEM_WIDTH, MVB_ITEM_WIDTH, VERBOSITY) m_model;

    // Contructor of scoreboard.
    function new(string name, uvm_component parent);
        super.new(name, parent);

        input_data = new("input_data", this);
        input_mvb  = new("input_mvb", this);
        out_data   = new("out_data", this);
        out_meta   = new("out_meta", this);

        dut_data   = new("dut_data", this);
        dut_meta   = new("dut_meta", this);
        model_data = new("model_data", this);
        model_meta = new("model_meta", this);
        compared   = 0;

    endfunction

    function int unsigned used();
        int unsigned ret = 0;
        ret |= (dut_data.used()   != 0);
        ret |= (model_data.used() != 0);
        ret |= (dut_meta.used()   != 0);
        ret |= (model_meta.used() != 0);
        return ret;
    endfunction


    function void build_phase(uvm_phase phase);
        m_model = model#(HEADER_SIZE, MFB_ITEM_WIDTH, MVB_ITEM_WIDTH, VERBOSITY)::type_id::create("m_model", this);
    endfunction

    function void connect_phase(uvm_phase phase);

        // connects input data to the input of the model
        input_data.connect(m_model.input_data.analysis_export);
        input_mvb.connect(m_model.input_mvb.analysis_export);

        // processed data from the output of the model connected to the analysis fifo
        m_model.out_data.connect(model_data.analysis_export);
        m_model.out_meta.connect(model_meta.analysis_export);
        // connects the data from the DUT to the analysis fifo
        out_data.connect(dut_data.analysis_export);
        out_meta.connect(dut_meta.analysis_export);

    endfunction

    task run_phase(uvm_phase phase);

        uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)       tr_dut_data;
        uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)       tr_model_data;
        uvm_logic_vector::sequence_item #(HEADER_SIZE+MVB_ITEM_WIDTH) tr_dut_meta;
        uvm_logic_vector::sequence_item #(HEADER_SIZE+MVB_ITEM_WIDTH) tr_model_meta;
        string msg;

        forever begin
            msg = "";

            model_data.get(tr_model_data);
            model_meta.get(tr_model_meta);
            dut_data.get(tr_dut_data);
            dut_meta.get(tr_dut_meta);

            compared++;

            if (VERBOSITY >= 2) begin
                $swrite(msg, "%s\n ================ SCOREBOARD DEBUG =============== \n", msg);
                $swrite(msg, "%sDUT TR number [%0d]\n", msg, compared);
                $swrite(msg, "%s\tDATA %s\n", msg, tr_dut_data.convert2string());
                $swrite(msg, "%s\tMETA %s\n", msg, tr_dut_meta.convert2string());
                $swrite(msg, "%sMODEL TR number [%0d]\n", msg, compared);
                $swrite(msg, "%s\tDATA %s\n", msg, tr_model_data.convert2string());
                $swrite(msg, "%s\tMETA %s\n", msg, tr_model_meta.convert2string());
                `uvm_info(this.get_full_name(), msg ,UVM_FULL)
            end

            if ((compared % 1000) == 0) begin
                $write("%d transactions were compared\n", compared);
            end

            if (tr_model_data.compare(tr_dut_data) == 0) begin
                msg = "";
                errors++;

                $swrite(msg, "\n\t Comparison failed at packet number %d! \n\tModel packet:\n%s\n\tDUT packet:\n%s", compared, tr_model_data.convert2string(), tr_dut_data.convert2string());
                `uvm_error(this.get_full_name(), msg);
            end

            if (tr_model_meta.compare(tr_dut_meta) == 0) begin
                msg = "";
                errors++;

                $swrite(msg, "\n\t Comparison failed at meta number %d! \n\tModel meta:\n%s\n\tDUT meta:\n%s\n", compared, tr_model_meta.convert2string(), tr_dut_meta.convert2string());
                `uvm_error(this.get_full_name(), msg);
            end
        end

    endtask

    function void report_phase(uvm_phase phase);
        string msg = "";

        $swrite(msg, "%s\tdut_data USED [%0d]\n"  , msg, dut_data.used());
        $swrite(msg, "%s\tmodel_data USED [%0d]\n", msg, model_data.used());
        $swrite(msg, "%s\tdut_meta USED [%0d]\n"  , msg, dut_meta.used());
        $swrite(msg, "%s\tmodel_meta USED [%0d]\n", msg, model_meta.used());

        if (errors == 0 && this.used() == 0) begin 
            $swrite(msg, "%sCompared packets: %0d", msg, compared);
            `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION SUCCESS      ----\n\t---------------------------------------"}, UVM_NONE)
        end else begin
            $swrite(msg, "%sCompared packets: %0d errors %0d", msg, compared, errors);
            `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION FAILED       ----\n\t---------------------------------------"}, UVM_NONE)
        end

    endfunction

endclass
