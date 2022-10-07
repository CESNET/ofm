// scoreboard.sv: Scoreboard for verification
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


class scoreboard #(HEADER_SIZE, VERBOSITY, OUT_META_WIDTH) extends uvm_scoreboard;
    `uvm_component_param_utils(uvm_superunpacketer::scoreboard #(HEADER_SIZE, VERBOSITY, OUT_META_WIDTH))

    int unsigned compared;
    int unsigned errors;

    uvm_analysis_export #(uvm_logic_vector_array::sequence_item #(8))        input_data;
    uvm_analysis_export #(uvm_logic_vector_array::sequence_item #(8))        out_data;
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(OUT_META_WIDTH)) out_meta;
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(OUT_META_WIDTH)) out_mvb;

    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item #(8))        dut_data;
    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item #(8))        model_data;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(OUT_META_WIDTH)) dut_meta;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(OUT_META_WIDTH)) model_meta;

    model #(HEADER_SIZE, VERBOSITY, OUT_META_WIDTH) m_model;

    // Contructor of scoreboard.
    function new(string name, uvm_component parent);
        super.new(name, parent);

        input_data = new("input_data", this);
        out_data   = new("out_data", this);
        out_meta   = new("out_meta", this);

        dut_data   = new("dut_data", this);
        dut_meta   = new("dut_meta", this);
        model_data = new("model_data", this);
        model_meta = new("model_meta", this);
        compared   = 0;

    endfunction

    function int unsigned used(logic wr);
        int unsigned ret = 0;
        ret |= (dut_data.used()   != 0);
        ret |= (model_data.used() != 0);
        ret |= (dut_meta.used()   != 0);
        ret |= (model_meta.used() != 0);
        if (wr == 1'b1) begin
            $write("dut_data USED [%0d]\n",   dut_data.used());
            $write("model_data USED [%0d]\n", model_data.used());
            $write("dut_meta USED [%0d]\n",   dut_meta.used());
            $write("model_meta USED [%0d]\n", model_meta.used());
        end
        return ret;
    endfunction


    function void build_phase(uvm_phase phase);
        m_model = model#(HEADER_SIZE, VERBOSITY, OUT_META_WIDTH)::type_id::create("m_model", this);
    endfunction

    function void connect_phase(uvm_phase phase);

        // connects input data to the input of the model
        input_data.connect(m_model.input_data.analysis_export);

        // processed data from the output of the model connected to the analysis fifo
        m_model.out_data.connect(model_data.analysis_export);
        m_model.out_meta.connect(model_meta.analysis_export);
        // connects the data from the DUT to the analysis fifo
        out_data.connect(dut_data.analysis_export);
        out_meta.connect(dut_meta.analysis_export);

    endfunction

    task run_phase(uvm_phase phase);

        uvm_logic_vector_array::sequence_item #(8)        tr_dut;
        uvm_logic_vector_array::sequence_item #(8)        tr_model;
        uvm_logic_vector::sequence_item #(OUT_META_WIDTH) tr_dut_meta;
        uvm_logic_vector::sequence_item #(OUT_META_WIDTH) tr_model_meta;

        forever begin

            model_data.get(tr_model);
            model_meta.get(tr_model_meta);
            dut_data.get(tr_dut);
            dut_meta.get(tr_dut_meta);

            if (VERBOSITY >= 2) begin
                `uvm_info(this.get_full_name(), tr_dut_meta.convert2string() ,UVM_LOW)
                `uvm_info(this.get_full_name(), tr_model_meta.convert2string() ,UVM_LOW)
            end

            compared++;
            if ((compared % 1000) == 0) begin
                $write("%d transactions were compared\n", compared);
            end

            if (tr_model.compare(tr_dut) == 0) begin
                string msg;
                errors++;

                $swrite(msg, "\n\t Comparison failed at packet number %d! \n\tModel packet:\n%s\n\tDUT packet:\n%s", compared, tr_model.convert2string(), tr_dut.convert2string());
                `uvm_error(this.get_full_name(), msg);
            end

            if (tr_model_meta.compare(tr_dut_meta) == 0) begin
                string msg;
                errors++;

                $swrite(msg, "\n\t Comparison failed at meta number %d! \n\tModel meta:\n%s\n\tDUT meta:\n%s\n", compared, tr_model_meta.convert2string(), tr_dut_meta.convert2string());
                `uvm_error(this.get_full_name(), msg);
            end
        end

    endtask

    function void report_phase(uvm_phase phase);

        if (errors == 0 && this.used(1'b1) == 0) begin 
            string msg = "";

            $swrite(msg, "%sCompared packets: %0d", msg, compared);
            `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION SUCCESS      ----\n\t---------------------------------------"}, UVM_NONE)
        end else begin
            string msg = "";

            $swrite(msg, "%sCompared packets: %0d errors %0d", msg, compared, errors);
            `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION FAILED       ----\n\t---------------------------------------"}, UVM_NONE)
        end

    endfunction

endclass
