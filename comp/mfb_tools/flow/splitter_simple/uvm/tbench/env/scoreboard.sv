//-- scoreboard.sv: Scoreboard for verification
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Radek Iša <isa@censet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause



class mfb_compare #(ITEM_WIDTH, META_WIDTH) extends uvm_component;
    `uvm_component_param_utils(uvm_splitter_simple::mfb_compare #(ITEM_WIDTH, META_WIDTH))

    int unsigned errors;
    int unsigned compared;
    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH))                 model_data;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(META_WIDTH)) model_meta;

    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH))                 dut_data;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(META_WIDTH)) dut_meta;


    function new(string name, uvm_component parent);
        super.new(name, parent);
        model_data = new("model_data", this);
        model_meta = new("model_meta", this);
        dut_data   = new("dut_data", this);
        dut_meta   = new("dut_meta", this);
        errors     = 0;
        compared   = 0;
    endfunction

    function int unsigned used();
        int unsigned ret = 0;
        ret |= (model_data.used() != 0);
        ret |= (model_meta.used() != 0);
        ret |= (dut_data.used() != 0);
        ret |= (dut_meta.used() != 0);
        return ret;
    endfunction

    task run_phase(uvm_phase phase);
        uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)                tr_model_packet;
        uvm_logic_vector::sequence_item#(META_WIDTH) tr_model_meta;

        uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)                tr_dut_packet;
        uvm_logic_vector::sequence_item#(META_WIDTH) tr_dut_meta;

        forever begin
            model_data.get(tr_model_packet);
            model_meta.get(tr_model_meta);

            dut_data.get(tr_dut_packet);
            dut_meta.get(tr_dut_meta);

            compared++;
            if (tr_model_packet.compare(tr_dut_packet) == 0 || tr_model_meta.compare(tr_dut_meta) == 0) begin
                string msg;

                errors++;
                $swrite(msg, "\n\tCheck meta or packet failed. errors %0d/%0d\n\tModel meta %s\n\tDUT meta %s\n\n\tModel Packet\n%s\n\tDUT PACKET\n%s", errors, compared, tr_model_meta.convert2string(), tr_dut_meta.convert2string(), tr_model_packet.convert2string(), tr_dut_packet.convert2string());
                `uvm_error(this.get_full_name(), msg);
            end
        end
    endtask

endclass

class scoreboard #(ITEM_WIDTH, META_WIDTH, CHANNELS) extends uvm_scoreboard;
    `uvm_component_param_utils(uvm_splitter_simple::scoreboard #(ITEM_WIDTH, META_WIDTH, CHANNELS))


    uvm_analysis_export #(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH))                                    input_data;
    uvm_analysis_export #(uvm_logic_vector::sequence_item #($clog2(CHANNELS) + META_WIDTH)) input_meta;

    uvm_analysis_export #(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH))                 out_data[CHANNELS];
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(META_WIDTH)) out_meta[CHANNELS];

    typedef scoreboard #(ITEM_WIDTH, META_WIDTH, CHANNELS) this_type;
    uvm_analysis_imp_reset#(uvm_reset::sequence_item, this_type) analysis_imp_reset;


    mfb_compare #(ITEM_WIDTH, META_WIDTH)     out_compare[CHANNELS];
    model #(ITEM_WIDTH, META_WIDTH, CHANNELS) m_model;

    // Contructor of scoreboard.
    function new(string name, uvm_component parent);
        super.new(name, parent);
        input_data = new("input_data", this);
        input_meta = new("input_meta", this);

        for (int unsigned it = 0; it < CHANNELS; it++) begin
            string it_str;
            it_str.itoa(it);
            out_data[it]   = new({"out_data_", it_str}, this);
            out_meta[it]   = new({"out_meta_", it_str}, this);
        end

        analysis_imp_reset = new("analysis_imp_reset", this);
    endfunction

    function void build_phase(uvm_phase phase);
        m_model = model #(ITEM_WIDTH, META_WIDTH, CHANNELS)::type_id::create("m_model", this);

        for (int it = 0; it < CHANNELS; it++) begin
            string it_string;

            it_string.itoa(it);
            out_compare[it] = mfb_compare #(ITEM_WIDTH, META_WIDTH)::type_id::create({"out_compare_", it_string}, this);
        end

    endfunction

    function void connect_phase(uvm_phase phase);
        input_data.connect(m_model.input_data.analysis_export);
        input_meta.connect(m_model.input_meta.analysis_export);


        for (int it = 0; it < CHANNELS; it++) begin
            string i_string;

            m_model.out_data[it].connect(out_compare[it].model_data.analysis_export);
            m_model.out_meta[it].connect(out_compare[it].model_meta.analysis_export);
            out_data[it].connect(out_compare[it].dut_data.analysis_export);
            out_meta[it].connect(out_compare[it].dut_meta.analysis_export);
        end
    endfunction

    function int unsigned used();
        int unsigned ret = 0;

        for (int unsigned it = 0; it < CHANNELS; it++) begin
            ret |= out_compare[it].used();
        end
        return ret;
    endfunction

    function void write_reset(uvm_reset::sequence_item tr);
        if (tr.reset == 1'b1) begin
            m_model.reset();
            for (int unsigned it = 0; it < CHANNELS; it++) begin
                out_compare[it].model_data.flush();
                out_compare[it].model_meta.flush();
                out_compare[it].dut_data.flush();
                out_compare[it].dut_meta.flush();
            end
        end
    endfunction


    function void report_phase(uvm_phase phase);
        int unsigned errors = 0;
        string msg = "";

        for (int unsigned it = 0; it < CHANNELS; it++) begin
            errors += out_compare[it].errors;
            $swrite(msg, "%s\n\tOUTPUT [%0d] compared %0d errors %0d", msg, it, out_compare[it].compared, out_compare[it].errors);
        end

        if (errors == 0 && this.used() == 0) begin
            `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION SUCCESS      ----\n\t---------------------------------------"}, UVM_NONE)
        end else begin
            `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION FAIL      ----\n\t---------------------------------------"}, UVM_NONE)
        end
    endfunction

endclass
