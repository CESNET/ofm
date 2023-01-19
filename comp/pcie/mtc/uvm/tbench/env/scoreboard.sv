//-- scoreboard.sv: Scoreboard for verification
//-- Copyright (C) 2023 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause



class cc_compare #(MFB_ITEM_WIDTH, DEVICE, ENDPOINT_TYPE) extends uvm_component;
    `uvm_component_param_utils(uvm_mtc::cc_compare #(MFB_ITEM_WIDTH, DEVICE, ENDPOINT_TYPE))

    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH))                  model_cc_data;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CC_META_WIDTH)) model_cc_meta;

    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH))                  dut_cc_data;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CC_META_WIDTH)) dut_cc_meta;

    uvm_pcie_hdr::sync_tag tag_sync;

    int unsigned errors;
    int unsigned compared;
    int unsigned unsupported;
    int unsigned tr_cnt;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        model_cc_data = new("model_cc_data", this);
        model_cc_meta = new("model_cc_meta", this);
        dut_cc_data   = new("dut_cc_data", this);
        dut_cc_meta   = new("dut_cc_meta", this);
        errors        = 0;
        compared      = 0;
        unsupported   = 0;
    endfunction

    function int unsigned used();
        int unsigned ret = 0;

        ret |= dut_cc_data.used() != 0;
        ret |= dut_cc_meta.used() != 0;
        ret |= model_cc_data.used()   != 0;
        ret |= model_cc_meta.used()   != 0;

        return ret;
    endfunction


    task run_phase(uvm_phase phase);

        localparam IS_INTEL_DEV    = (DEVICE == "STRATIX10" || DEVICE == "AGILEX");
        localparam IS_XILINX_DEV   = (DEVICE == "ULTRASCALE" || DEVICE == "7SERIES");
        localparam IS_MFB_META_DEV = (ENDPOINT_TYPE == "P_TILE" || ENDPOINT_TYPE == "R_TILE") && IS_INTEL_DEV;

        uvm_logic_vector_array::sequence_item#(32)                              tr_model_data;
        uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CC_META_WIDTH) tr_model_meta;

        uvm_logic_vector_array::sequence_item#(32)                              tr_dut_data;
        uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CC_META_WIDTH) tr_dut_meta;
        logic [8-1 : 0]                                                         dut_tag;
        logic [8-1 : 0]                                                         model_tag;
        logic [3-1 : 0]                                                         comp_st;
        // In case of Intel (P_TILE, R_TILE) and there is unsupported type than ignore data comparison.
        // In other cases, there is header in data, compared it.
        logic [3-1 : 0]                                                         error = 0;

        forever begin
            string msg = "";

            model_cc_data.get(tr_model_data);
            model_cc_meta.get(tr_model_meta);
            dut_cc_data.get(tr_dut_data);
            dut_cc_meta.get(tr_dut_meta);

            $swrite(msg, "\n\t =============== CC COMPARE =============== \n");
            $swrite(msg, "%s\nTransaction number: %0d\n", msg, tr_cnt);
            $swrite(msg, "%s\nDUT CC Response Data %s\n", msg, tr_dut_data.convert2string());
            $swrite(msg, "%s\nDUT CC Response Meta %s\n", msg, tr_dut_meta.convert2string());
            $swrite(msg, "%s\nMODEL CC Response Data %s\n", msg, tr_model_data.convert2string());
            $swrite(msg, "%s\nMODEL CC Response Meta %s\n", msg, tr_model_meta.convert2string());
            `uvm_info(this.get_full_name(), msg, UVM_FULL)

            if (IS_MFB_META_DEV) begin
                // Only Intel
                dut_tag   = tr_dut_meta.data[80-1 : 72];
                model_tag = tr_model_meta.data[80-1 : 72];
                comp_st   = tr_model_meta.data[48-1 : 45];
                error     = comp_st;
            end else begin
                if (IS_INTEL_DEV) begin
                    dut_tag   = tr_dut_data.data[2][16-1 : 8];
                    model_tag = tr_model_data.data[2][16-1 : 8];
                    comp_st = tr_model_meta.data[48-1 : 45];
                end else begin
                    dut_tag   = tr_dut_data.data[2][8-1 : 0];
                    model_tag = tr_model_data.data[2][8-1 : 0];
                    comp_st = tr_model_meta.data[46-1 : 43];
                end
            end

            if (error == '0) begin
                if ((tr_model_data.compare(tr_dut_data) == 0) || (dut_tag != model_tag)) begin
                    string msg;
                    errors++;

                    $swrite(msg, "\n\t Comparison failed at packet number %d! \n\t Model tag: %h\n\tModel packet:\n%s\n\tDUT packet:\n%s\n\t DUT tag: %h\n", compared, model_tag, tr_model_data.convert2string(), tr_dut_data.convert2string(), dut_tag);
                    `uvm_error(this.get_full_name(), msg);
                end
            end

            if ((tr_model_meta.compare(tr_dut_meta) == 0)) begin
                string msg;
                errors++;

                $swrite(msg, "\n\t Comparison failed at packet number %d! \n\tModel meta:\n%s\n\tDUT meta:\n%s\n", compared, tr_model_meta.convert2string(), tr_dut_meta.convert2string());
                `uvm_error(this.get_full_name(), msg);
            end

            if (comp_st != '0)
                unsupported++;
            else
                compared++;

            tr_cnt++;

            if ((tag_sync.list_of_tags.exists(dut_tag))) begin
                string msg;
                tag_sync.print_all();
                $swrite(msg, "%sTAG %h EXISTS\n", msg, dut_tag);
                $swrite(msg, "%sNUMBER %d\n", msg, compared);
                `uvm_error(this.get_full_name(), msg);
            end
            tag_sync.add_element(dut_tag);

        end
    endtask

endclass

class scoreboard #(MFB_ITEM_WIDTH, DEVICE, ENDPOINT_TYPE, MI_DATA_WIDTH, MI_ADDR_WIDTH) extends uvm_scoreboard;
    `uvm_component_param_utils(uvm_mtc::scoreboard #(MFB_ITEM_WIDTH, DEVICE, ENDPOINT_TYPE, MI_DATA_WIDTH, MI_ADDR_WIDTH))

    //INPUT TO DUT
    uvm_analysis_export #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH))                  analysis_export_cq_data;
    uvm_analysis_export #(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)) analysis_export_cq_meta;
    //DUT OUTPUT
    uvm_analysis_export #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH))                  analysis_export_cc_data;
    uvm_analysis_export #(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CC_META_WIDTH)) analysis_export_cc_meta;
    uvm_analysis_export #(uvm_mi::sequence_item_response #(MI_DATA_WIDTH))                         analysis_export_cc_mi;
    uvm_analysis_export #(uvm_mi::sequence_item_request #(MI_DATA_WIDTH, MI_ADDR_WIDTH, 0))        analysis_export_mi_data;
    uvm_analysis_port   #(uvm_logic_vector::sequence_item #(MI_DATA_WIDTH))                        mi_analysis_port_out;
    //OUTPUT FIFO MODEL
    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH))                  model_fifo_cc_data;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CC_META_WIDTH)) model_fifo_cc_meta;
    //OUTPUT FIFO DUT
    uvm_tlm_analysis_fifo #(uvm_mi::sequence_item_request #(MI_DATA_WIDTH, MI_ADDR_WIDTH, 0)) dut_fifo_mi_data;
    uvm_tlm_analysis_fifo #(uvm_mi::sequence_item_request #(MI_DATA_WIDTH, MI_ADDR_WIDTH, 0)) model_fifo_mi_data;

    model #(MFB_ITEM_WIDTH, DEVICE, ENDPOINT_TYPE, MI_DATA_WIDTH, MI_ADDR_WIDTH) m_model;
    response_model #(MFB_ITEM_WIDTH, DEVICE, ENDPOINT_TYPE, MI_DATA_WIDTH, MI_ADDR_WIDTH) m_resp_model;

    uvm_mtc::cc_compare #(MFB_ITEM_WIDTH, DEVICE, ENDPOINT_TYPE) response_compare;

    local int unsigned read_compared;
    local int unsigned write_compared;
    local int unsigned compared;
    local int unsigned errors;

    // Contructor of scoreboard.
    function new(string name, uvm_component parent);
        super.new(name, parent);
        // DUT MODEL COMUNICATION 
        analysis_export_cq_data = new("analysis_export_cq_data", this);
        analysis_export_cq_meta = new("analysis_export_cq_meta", this);
        analysis_export_cc_data = new("analysis_export_cc_data", this);
        analysis_export_cc_meta = new("analysis_export_cc_meta", this);
        analysis_export_mi_data = new("analysis_export_mi_data", this);
        analysis_export_cc_mi   = new("analysis_export_cc_mi", this);
        mi_analysis_port_out    = new("mi_analysis_port_out"   , this);

        model_fifo_cc_data      = new("model_fifo_cc_data", this);
        model_fifo_cc_meta      = new("model_fifo_cc_meta", this);
        dut_fifo_mi_data        = new("dut_fifo_mi_data"  , this);
        model_fifo_mi_data      = new("model_fifo_mi_data", this);

        read_compared  = 0;
        write_compared = 0;
        compared       = 0;
        errors         = 0;
    endfunction

    function int unsigned used();
        int unsigned ret = 0;

        ret |= model_fifo_cc_data.used() != 0;
        ret |= model_fifo_cc_meta.used() != 0;
        ret |= dut_fifo_mi_data.used()   != 0;
        ret |= model_fifo_mi_data.used() != 0;
        ret |= response_compare.used() != 0;

        return ret;
    endfunction

    //build phase
    function void build_phase(uvm_phase phase);
        m_model = model #(MFB_ITEM_WIDTH, DEVICE, ENDPOINT_TYPE, MI_DATA_WIDTH, MI_ADDR_WIDTH)::type_id::create("m_model", this);
        m_resp_model = response_model #(MFB_ITEM_WIDTH, DEVICE, ENDPOINT_TYPE, MI_DATA_WIDTH, MI_ADDR_WIDTH)::type_id::create("m_resp_model", this);
        response_compare = uvm_mtc::cc_compare #(MFB_ITEM_WIDTH, DEVICE, ENDPOINT_TYPE)::type_id::create("response_compare", this);
    endfunction

    function int unsigned error_cnt();
        int unsigned ret = 0;
        ret |= (response_compare.errors != 0);
        ret |= (errors != 0);
        return ret;
    endfunction

    function void connect_phase(uvm_phase phase);
        analysis_export_cq_data.connect(m_model.analysis_imp_cq_data.analysis_export);
        analysis_export_cq_meta.connect(m_model.analysis_imp_cq_meta.analysis_export);
        analysis_export_cq_data.connect(m_resp_model.analysis_imp_cq_data.analysis_export);
        analysis_export_cq_meta.connect(m_resp_model.analysis_imp_cq_meta.analysis_export);
        analysis_export_cc_mi.connect(m_resp_model.analysis_imp_cc_mi.analysis_export);

        m_model.analysis_port_mi_data.connect(model_fifo_mi_data.analysis_export);
        analysis_export_mi_data.connect(dut_fifo_mi_data.analysis_export);

        analysis_export_cc_data.connect(response_compare.dut_cc_data.analysis_export);
        analysis_export_cc_meta.connect(response_compare.dut_cc_meta.analysis_export);

        m_resp_model.analysis_port_cc_meta.connect(response_compare.model_cc_meta.analysis_export);
        m_resp_model.analysis_port_cc_data.connect(response_compare.model_cc_data.analysis_export);

    endfunction

    task run_phase(uvm_phase phase);

        uvm_mi::sequence_item_request #(MI_DATA_WIDTH, MI_ADDR_WIDTH, 0)         dut_mi_tr;
        uvm_mi::sequence_item_request #(MI_DATA_WIDTH, MI_ADDR_WIDTH, 0)         model_mi_tr;
        uvm_logic_vector::sequence_item #(MI_DATA_WIDTH)                         lv_mi_tr;
        uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)                  dut_cc_data_tr;
        uvm_logic_vector::sequence_item #(sv_pcie_meta_pack::PCIE_CC_META_WIDTH) dut_cc_meta_tr;

        forever begin
            string msg = "";

            dut_fifo_mi_data.get(dut_mi_tr);
            if (dut_mi_tr.ardy && (dut_mi_tr.wr || dut_mi_tr.rd)) begin
                lv_mi_tr = uvm_logic_vector::sequence_item #(MI_DATA_WIDTH)::type_id::create("lv_mi_tr");

                model_fifo_mi_data.get(model_mi_tr);

                $swrite(msg, "\n\t =============== MI CQ COMPARE =============== \n");
                $swrite(msg, "%s\nTransaction number: %0d\n", msg, compared);
                $swrite(msg, "%s\nDUT MI Request %s\n", msg, dut_mi_tr.convert2string());
                $swrite(msg, "%s\nMODEL MI Request %s\n", msg, model_mi_tr.convert2string());
                `uvm_info(this.get_full_name(), msg, UVM_FULL)

                if (model_mi_tr.compare(dut_mi_tr) == 0) begin
                    string msg;
                    errors++;

                    $swrite(msg, "\n\t Comparison failed at packet number %d! \n\tModel packet:\n%s\n\tDUT packet:\n%s", compared, model_mi_tr.convert2string(), dut_mi_tr.convert2string());
                    `uvm_error(this.get_full_name(), msg);
                end

                if (dut_mi_tr.rd) begin
                    lv_mi_tr.data = '1;
                    mi_analysis_port_out.write(lv_mi_tr);
                    read_compared++;
                end
                if (dut_mi_tr.wr) begin
                    write_compared++;
                end
                compared++;
            end

        end

    endtask


    function void report_phase(uvm_phase phase);
        string msg = "";

        if (this.error_cnt() == 0 && this.used() == 0) begin
            $swrite(msg, "%s\nCompared MI Write Requests: %0d\n", msg, write_compared);
            $swrite(msg, "%sCompared MI Read Requests: %0d\n", msg, read_compared);
            $swrite(msg, "%sCompared MFB Read Responses: %0d\n", msg, response_compare.compared);
            $swrite(msg, "%sCompared MFB Unsupported messages: %0d\n", msg, response_compare.unsupported);
            `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION SUCCESS      ----\n\t---------------------------------------"}, UVM_NONE)
        end else begin
            $swrite(msg, "%s\nCompared MI Write Requests: %0d errors %0d\n", msg, write_compared, errors);
            $swrite(msg, "%sCompared MI Read Requests: %0d errors %0d\n", msg, read_compared, errors);
            $swrite(msg, "%sCompared MFB Read Responses: %0d\n", msg, response_compare.compared);
            $swrite(msg, "%sCompared MFB Unsupported messages: %0d\n", msg, response_compare.unsupported);
            `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION FAILED       ----\n\t---------------------------------------"}, UVM_NONE)
        end

    endfunction
endclass
