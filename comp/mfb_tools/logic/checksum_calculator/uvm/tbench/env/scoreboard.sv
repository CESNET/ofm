// scoreboard.sv: Scoreboard for verification
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


class compare #(META_WIDTH, MVB_DATA_WIDTH, MFB_ITEM_WIDTH, LAYER, VERBOSITY) extends uvm_component;
    `uvm_component_utils(uvm_checksum_calculator::compare #(META_WIDTH, MVB_DATA_WIDTH, MFB_ITEM_WIDTH, LAYER, VERBOSITY))

    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH+1)) dut_mvb;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH))   model_checksum_mvb;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(1))                model_bypass;

    int unsigned errors;
    int unsigned compared;
    logic bypass;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        dut_mvb = new("dut_mvb", this);
        model_checksum_mvb = new("model_checksum_mvb", this);
        model_bypass   = new("model_bypass", this);
        errors    = 0;
        compared  = 0;
    endfunction

    task run_phase(uvm_phase phase);
        uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH)   tr_dut_mvb;
        uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH+1) tr_dut_mvb_with_bypass;
        uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH)   tr_model_checksum_mvb;
        uvm_logic_vector::sequence_item #(1)                bypass_model;
        logic                                               bypass;

        forever begin
            tr_dut_mvb = uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH)::type_id::create("tr_dut_mvb");

            model_bypass.get(bypass_model);
            model_checksum_mvb.get(tr_model_checksum_mvb);
            dut_mvb.get(tr_dut_mvb_with_bypass);

            bypass          = tr_dut_mvb_with_bypass.data[MVB_DATA_WIDTH];
            tr_dut_mvb.data = tr_dut_mvb_with_bypass.data[MVB_DATA_WIDTH-1 : 0];

            // $write("%s CHSUM Model\n", LAYER);
            // `uvm_info(this.get_full_name(), tr_model_checksum_mvb.convert2string() ,UVM_NONE)
            // $write("%s CHSUM DUT\n", LAYER);
            // `uvm_info(this.get_full_name(), tr_dut_mvb.convert2string() ,UVM_NONE)

            if (VERBOSITY >= 2) begin
                $write("FLAG \n");
                `uvm_info(this.get_full_name(), bypass_model.convert2string() ,UVM_NONE)
            end

            compared++;
            if ((compared % 1000) == 0) begin
                $write("%d %s transactions were compared\n", compared, LAYER);
            end

            // if (bypass_model.data == 1 && bypass == 1) begin
            //     $write("%s BYPASSED CHSUM Model\n", LAYER);
            //     `uvm_info(this.get_full_name(), tr_model_checksum_mvb.convert2string() ,UVM_NONE)
            //     $write("%s BYPASS %h\n", LAYER, bypass);
            //     $write("%s BYPASSED CHSUM DUT\n", LAYER);
            //     `uvm_info(this.get_full_name(), tr_dut_mvb.convert2string() ,UVM_NONE)
            //     $write("%s BYPASS MODEL %h\n", LAYER, bypass_model.data);
            // end

            if (bypass_model.data != bypass) begin
                string b_msg;
                errors++;

                $swrite(b_msg, "%s\n\t %s\n\tComparison failed at packet number %d! \n\tModel checksum:\n%s\n\tDUT checksum:\n%s", b_msg, LAYER, compared, tr_model_checksum_mvb.convert2string(), tr_dut_mvb.convert2string());
                $swrite(b_msg, "%s\n\n\tModel BYPASS: %b\n\tDUT BYPASS: %b\n", b_msg, bypass_model.data, bypass);
                `uvm_error(this.get_full_name(), b_msg);
            end

            if (bypass_model.data == 1'b0) begin
                if (tr_model_checksum_mvb.compare(tr_dut_mvb) == 0) begin
                    string msg;
                    errors++;

                    $swrite(msg, "%s\n\t %s\n\tComparison failed at packet number %d! \n\tModel checksum:\n%s\n\tDUT checksum:\n%s", msg, LAYER, compared, tr_model_checksum_mvb.convert2string(), tr_dut_mvb.convert2string());
                    $swrite(msg, "%s\n\n\tModel BYPASS: %b\n\tDUT BYPASS: %b\n", msg, bypass_model.data[0], bypass);
                    `uvm_error(this.get_full_name(), msg);
                end
            end

        end

    endtask

endclass

class scoreboard #(META_WIDTH, MVB_DATA_WIDTH, MFB_ITEM_WIDTH, VERBOSITY) extends uvm_scoreboard;
    `uvm_component_param_utils(uvm_checksum_calculator::scoreboard #(META_WIDTH, MVB_DATA_WIDTH, MFB_ITEM_WIDTH, VERBOSITY))

    int unsigned compared;
    int unsigned errors;

    uvm_analysis_export #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)) input_mfb;
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(META_WIDTH))           input_meta;
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH+1))     out_mvb_l3;
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH+1))     out_mvb_l4;

    // uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH+1)) dut_mvb_l3;
    // uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH+1)) dut_mvb_l4;
    // uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH))   model_l3_checksum_mvb;
    // uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH))   model_l4_checksum_mvb;
    // uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(2))                model_bypass;

    model #(META_WIDTH, MVB_DATA_WIDTH, MFB_ITEM_WIDTH, VERBOSITY) m_model;
    uvm_checksum_calculator::compare #(META_WIDTH, MVB_DATA_WIDTH, MFB_ITEM_WIDTH, "L3", VERBOSITY) l3_compare;
    uvm_checksum_calculator::compare #(META_WIDTH, MVB_DATA_WIDTH, MFB_ITEM_WIDTH, "L4", VERBOSITY) l4_compare;

    // Contructor of scoreboard.
    function new(string name, uvm_component parent);
        super.new(name, parent);

        input_mfb             = new("input_mfb", this);
        input_meta            = new("input_meta", this);
        out_mvb_l3            = new("out_mvb_l3", this);
        out_mvb_l4            = new("out_mvb_l4", this);

        // dut_mvb_l3            = new("dut_mvb_l3", this);
        // dut_mvb_l4            = new("dut_mvb_l4", this);
        // model_l3_checksum_mvb = new("model_l3_checksum_mvb", this);
        // model_l4_checksum_mvb = new("model_l4_checksum_mvb", this);
        // model_bypass          = new("model_bypass", this);
        compared              = 0;
        errors                = 0;

    endfunction

    function int unsigned used();
        int unsigned ret = 0;
        // ret |= (dut_mvb_l3.used()            != 0);
        // ret |= (dut_mvb_l4.used()            != 0);
        // ret |= (model_l3_checksum_mvb.used() != 0);
        // ret |= (model_l4_checksum_mvb.used() != 0);
        // ret |= (model_bypass.used()          != 0);

        ret |= (l3_compare.dut_mvb.used()            != 0);
        ret |= (l4_compare.dut_mvb.used()            != 0);
        ret |= (l3_compare.model_checksum_mvb.used() != 0);
        ret |= (l4_compare.model_checksum_mvb.used() != 0);
        ret |= (l3_compare.model_bypass.used()          != 0);
        ret |= (l4_compare.model_bypass.used()          != 0);
        return ret;
    endfunction


    function void build_phase(uvm_phase phase);
        m_model    = model#(META_WIDTH, MVB_DATA_WIDTH, MFB_ITEM_WIDTH, VERBOSITY)::type_id::create("m_model", this);
        l3_compare = uvm_checksum_calculator::compare#(META_WIDTH, MVB_DATA_WIDTH, MFB_ITEM_WIDTH, "L3", VERBOSITY)::type_id::create("l3_compare", this);
        l4_compare = uvm_checksum_calculator::compare#(META_WIDTH, MVB_DATA_WIDTH, MFB_ITEM_WIDTH, "L4", VERBOSITY)::type_id::create("l4_compare", this);
    endfunction

    function void connect_phase(uvm_phase phase);

        // connects input data to the input of the model
        input_mfb.connect(m_model.input_mfb.analysis_export);
        input_meta.connect(m_model.input_meta.analysis_export);

        // processed data from the output of the model connected to the analysis fifo
        // m_model.out_l3_checksum_mvb.connect(model_l3_checksum_mvb.analysis_export);
        // m_model.out_l4_checksum_mvb.connect(model_l4_checksum_mvb.analysis_export);
        // m_model.out_bypass.connect(model_bypass.analysis_export);
        // // connects the data from the DUT to the analysis fifo
        // out_mvb_l3.connect(dut_mvb_l3.analysis_export);
        // out_mvb_l4.connect(dut_mvb_l4.analysis_export);

        m_model.out_l3_checksum_mvb.connect(l3_compare.model_checksum_mvb.analysis_export);
        m_model.out_l4_checksum_mvb.connect(l4_compare.model_checksum_mvb.analysis_export);
        m_model.out_l3_bypass.connect(l3_compare.model_bypass.analysis_export);
        m_model.out_l4_bypass.connect(l4_compare.model_bypass.analysis_export);
        // connects the data from the DUT to the analysis fifo
        out_mvb_l3.connect(l3_compare.dut_mvb.analysis_export);
        out_mvb_l4.connect(l4_compare.dut_mvb.analysis_export);

    endfunction

    // task run_phase(uvm_phase phase);

    //     uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH)   tr_dut_mvb_l3;
    //     uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH+1) tr_dut_mvb_l3_with_bypass;
    //     uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH)   tr_dut_mvb_l4;
    //     uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH+1) tr_dut_mvb_l4_with_bypass;
    //     uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH)   tr_model_l3_checksum_mvb;
    //     uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH)   tr_model_l4_checksum_mvb;
    //     uvm_logic_vector::sequence_item #(2)                bypass_model;
    //     logic                                               l3_bypass;
    //     logic                                               l4_bypass;

    //     forever begin

    //         tr_dut_mvb_l3 = uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH)::type_id::create("tr_dut_mvb_l3");
    //         tr_dut_mvb_l4 = uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH)::type_id::create("tr_dut_mvb_l4");

    //         model_bypass.get(bypass_model);
    //         model_l3_checksum_mvb.get(tr_model_l3_checksum_mvb);
    //         dut_mvb_l3.get(tr_dut_mvb_l3_with_bypass);
    //         model_l4_checksum_mvb.get(tr_model_l4_checksum_mvb);
    //         dut_mvb_l4.get(tr_dut_mvb_l4_with_bypass);

    //         l3_bypass          = tr_dut_mvb_l3_with_bypass.data[MVB_DATA_WIDTH];
    //         tr_dut_mvb_l3.data = tr_dut_mvb_l3_with_bypass.data[MVB_DATA_WIDTH-1 : 0];

    //         l4_bypass          = tr_dut_mvb_l4_with_bypass.data[MVB_DATA_WIDTH];
    //         tr_dut_mvb_l4.data = tr_dut_mvb_l4_with_bypass.data[MVB_DATA_WIDTH-1 : 0];

    //         $write("L3 BYPASS %h\n", l3_bypass);
    //         $write("L3 BYPASS MODEL %h\n", bypass_model.data[0]);
    //         $write("L4 BYPASS %h\n", l4_bypass);
    //         $write("L4 BYPASS MODEL %h\n", bypass_model.data[1]);
    //         $write("L3 CHSUM Model\n");
    //         `uvm_info(this.get_full_name(), tr_model_l3_checksum_mvb.convert2string() ,UVM_NONE)
    //         $write("L3 CHSUM DUT\n");
    //         `uvm_info(this.get_full_name(), tr_dut_mvb_l3.convert2string() ,UVM_NONE)
    //         $write("L4 CHSUM Model\n");
    //         `uvm_info(this.get_full_name(), tr_model_l4_checksum_mvb.convert2string() ,UVM_NONE)
    //         $write("L4 CHSUM DUT\n");
    //         `uvm_info(this.get_full_name(), tr_dut_mvb_l4.convert2string() ,UVM_NONE)

    //         if (VERBOSITY >= 2) begin
    //             $write("FLAG \n");
    //             `uvm_info(this.get_full_name(), bypass_model.convert2string() ,UVM_NONE)
    //         end

    //         compared++;
    //         if ((compared % 1000) == 0) begin
    //             $write("%d transactions were compared\n", compared);
    //         end

    //         if (bypass_model.data[0] == 1'b0) begin
    //             if (tr_model_l3_checksum_mvb.compare(tr_dut_mvb_l3) == 0) begin
    //                 string msg;
    //                 errors++;

    //                 $swrite(msg, "%s\n\t L3\n\tComparison failed at packet number %d! \n\tModel checksum:\n%s\n\tDUT checksum:\n%s", msg, compared, tr_model_l3_checksum_mvb.convert2string(), tr_dut_mvb_l3.convert2string());
    //                 $swrite(msg, "%s\n\n\tModel BYPASS: %b\n\tDUT BYPASS: %b\n", msg, bypass_model.data[0], l3_bypass);
    //                 `uvm_error(this.get_full_name(), msg);
    //             end
    //         end

    //         if (bypass_model.data[1] == 1'b0) begin
    //             if (tr_model_l4_checksum_mvb.compare(tr_dut_mvb_l4) == 0) begin
    //                 string msg;
    //                 errors++;

    //                 $swrite(msg, "%s\n\t L4\n\tComparison failed at packet number %d! \n\tModel checksum:\n%s\n\tDUT checksum:\n%s", msg, compared, tr_model_l4_checksum_mvb.convert2string(), tr_dut_mvb_l4.convert2string());
    //                 $swrite(msg, "%s\n\n\tModel BYPASS: %b\n\tDUT BYPASS: %b\n", msg, bypass_model.data[1], l4_bypass);
    //                 `uvm_error(this.get_full_name(), msg);
    //             end
    //         end

    //     end

    // endtask

    function void report_phase(uvm_phase phase);

        if (l3_compare.errors == 0 && l4_compare.errors == 0 && this.used() == 0) begin 
            string msg = "";

            $swrite(msg, "%s\nL3 Compared packets: %0d", msg, l3_compare.compared);
            $swrite(msg, "%s\nL4 Compared packets: %0d", msg, l4_compare.compared);
            `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION SUCCESS      ----\n\t---------------------------------------"}, UVM_NONE)
        end else begin
            string msg = "";

            $swrite(msg, "%s\nL3 Compared packets: %0d and errors %0d", msg, l3_compare.compared, l3_compare.errors);
            $swrite(msg, "%s\nL4 Compared packets: %0d and errors %0d", msg, l4_compare.compared, l4_compare.errors);
            `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION FAILED       ----\n\t---------------------------------------"}, UVM_NONE)
        end

    endfunction

endclass
