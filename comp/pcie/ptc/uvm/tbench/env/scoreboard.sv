//-- scoreboard.sv: Scoreboard for verification
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause


class up_catch extends uvm_component;
    `uvm_component_utils(uvm_ptc::up_catch)

    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item#(32))          up_mfb_gen;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item#(sv_dma_bus_pack::DMA_UPHDR_WIDTH))   up_mvb_gen;

    uvm_logic_vector_array::sequence_item #(32)        dut_up_mfb_array [logic [8-1 : 0]];
    uvm_logic_vector::sequence_item #(sv_dma_bus_pack::DMA_UPHDR_WIDTH) dut_up_mvb_array [logic [8-1 : 0]];
    int unsigned up_mfb_cnt;
    int unsigned up_mvb_cnt;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        up_mfb_gen   = new("up_mfb_gen", this);
        up_mvb_gen   = new("up_mvb_gen", this);
        up_mfb_cnt   = 0;
        up_mvb_cnt   = 0;
    endfunction

    task run_phase(uvm_phase phase);

        uvm_logic_vector_array::sequence_item#(32)          tr_up_mfb_gen;
        uvm_logic_vector::sequence_item#(sv_dma_bus_pack::DMA_UPHDR_WIDTH)   tr_up_mvb_gen;

        forever begin
            string msg;
            string debug_msg = "";

            up_mvb_gen.get(tr_up_mvb_gen);
            up_mvb_cnt++;

            if (tr_up_mvb_gen.data[sv_dma_bus_pack::DMA_REQUEST_FIRSTIB_O-1 : sv_dma_bus_pack::DMA_REQUEST_TYPE_O] == 1'b1) begin
                up_mfb_gen.get(tr_up_mfb_gen);
                up_mfb_cnt++;
            end

            $swrite(debug_msg, "%s\n\t GEN UP MVB TR NUMBER: %d: %s\n", debug_msg, up_mvb_cnt, tr_up_mvb_gen.convert2string());
            if (tr_up_mfb_gen != null) begin
                $swrite(debug_msg, "%s\n\t GEN UP MFB TR NUMBER: %d: %s\n", debug_msg, up_mfb_cnt, tr_up_mfb_gen.convert2string());
            end
            `uvm_info(this.get_full_name(), debug_msg ,UVM_MEDIUM);

            // IF READ REQ, load the UP request
            if (tr_up_mvb_gen.data[sv_dma_bus_pack::DMA_REQUEST_FIRSTIB_O-1 : sv_dma_bus_pack::DMA_REQUEST_TYPE_O] == 1'b0) begin
                if (dut_up_mvb_array.exists(tr_up_mvb_gen.data[sv_dma_bus_pack::DMA_REQUEST_UNITID_O-1 : sv_dma_bus_pack::DMA_REQUEST_TAG_O])) begin
                    $write("FATAL TAG: %h\n", tr_up_mvb_gen.data[sv_dma_bus_pack::DMA_REQUEST_UNITID_O-1 : sv_dma_bus_pack::DMA_REQUEST_TAG_O]);
                    `uvm_fatal(this.get_full_name(), "Transaction exists");
                end else begin
                    dut_up_mfb_array[tr_up_mvb_gen.data[sv_dma_bus_pack::DMA_REQUEST_UNITID_O-1 : sv_dma_bus_pack::DMA_REQUEST_TAG_O]] = tr_up_mfb_gen;
                    dut_up_mvb_array[tr_up_mvb_gen.data[sv_dma_bus_pack::DMA_REQUEST_UNITID_O-1 : sv_dma_bus_pack::DMA_REQUEST_TAG_O]] = tr_up_mvb_gen;
                end
            end
        end
    endtask

endclass


class rc_compare extends uvm_component;
    `uvm_component_utils(uvm_ptc::rc_compare)

    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item#(32))          model_mfb;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item#(sv_dma_bus_pack::DMA_DOWNHDR_WIDTH)) model_mvb;

    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item#(32))          dut_mfb;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item#(sv_dma_bus_pack::DMA_DOWNHDR_WIDTH)) dut_mvb;

    uvm_logic_vector_array::sequence_item #(32)          dut_down_mfb_array [logic [8-1 : 0]];
    uvm_logic_vector::sequence_item #(sv_dma_bus_pack::DMA_DOWNHDR_WIDTH) dut_down_mvb_array [logic [8-1 : 0]];

    uvm_ptc_info::sync_tag tag_sync;
    uvm_ptc::up_catch catch_up;
    int unsigned errors;
    int unsigned compared;
    int unsigned down_cnt;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        model_mfb = new("model_mfb", this);
        model_mvb = new("model_mvb", this);
        dut_mfb   = new("dut_mfb", this);
        dut_mvb   = new("dut_mvb", this);
        errors    = 0;
        compared  = 0;
    endfunction

    task run_phase(uvm_phase phase);
        uvm_logic_vector_array::sequence_item#(32)          tr_model_mfb;
        uvm_logic_vector::sequence_item#(sv_dma_bus_pack::DMA_DOWNHDR_WIDTH) tr_model_mvb;

        uvm_logic_vector_array::sequence_item#(32)          tr_dut_mfb;
        uvm_logic_vector::sequence_item#(sv_dma_bus_pack::DMA_DOWNHDR_WIDTH) tr_dut_mvb;

        forever begin
            string msg;
            string debug_msg = "";

            model_mfb.get(tr_model_mfb);
            model_mvb.get(tr_model_mvb);
            dut_mfb.get(tr_dut_mfb);
            dut_mvb.get(tr_dut_mvb);
            down_cnt++;

            $swrite(debug_msg, "%s\n\t Model MFB DOWN TR NUMBER %d: %s\n", debug_msg, down_cnt, tr_model_mfb.convert2string());
            $swrite(debug_msg, "%s\n\t Model MVB DOWN TR NUMBER %d: %s\n", debug_msg, down_cnt, tr_model_mvb.convert2string());
            $swrite(debug_msg, "%s\n\t DUT MFB DOWN TR NUMBER   %d: %s\n", debug_msg, down_cnt, tr_dut_mfb.convert2string());
            $swrite(debug_msg, "%s\n\t DUT MVB DOWN TR NUMBER   %d: %s\n", debug_msg, down_cnt, tr_dut_mvb.convert2string());
            `uvm_info(this.get_full_name(), debug_msg ,UVM_MEDIUM);

            if (dut_down_mfb_array.exists(tr_dut_mvb.data[20-1 : 12])) begin
                `uvm_fatal(this.get_full_name(), "Transaction exists");
            end else begin
                dut_down_mfb_array[tr_dut_mvb.data[20-1 : 12]] = tr_dut_mfb;
                dut_down_mvb_array[tr_dut_mvb.data[20-1 : 12]] = tr_dut_mvb;
                tag_sync.remove_element(tr_dut_mvb.data[20-1 : 12]);
            end

            if (dut_down_mfb_array.size() != 0) begin
                comp(tr_dut_mvb, tr_dut_mfb, tr_model_mfb);
            end
        end
    endtask

    task comp(uvm_logic_vector::sequence_item#(sv_dma_bus_pack::DMA_DOWNHDR_WIDTH) mvb, uvm_logic_vector_array::sequence_item#(32) dut_mfb, uvm_logic_vector_array::sequence_item#(32) model_mfb);
        string msg;

        if (catch_up.dut_up_mvb_array.exists(mvb.data[20-1 : 12])) begin

            if (mvb.data[10-1 : 0] != dut_mfb.size() || mvb.data[10-1 : 0] != model_mfb.size()) begin
                string msg_1;

                $swrite(msg_1, "\n\tCheck of MFB data size and header size failed.\n\tMFB DUT size %d\n\tHeader size %d\ntMFB Model size %d\n\t", dut_mfb.size(), mvb.data[10-1 : 0], model_mfb.size());
                `uvm_error(this.get_full_name(), msg_1);
                errors++;
            end

            if (catch_up.dut_up_mvb_array[mvb.data[20-1 : 12]].data[sv_dma_bus_pack::DMA_REQUEST_UNITID_O-1 : sv_dma_bus_pack::DMA_REQUEST_TAG_O] != mvb.data[20-1 : 12]) begin
                string msg_1;

                $swrite(msg_1, "\n\tCheck TAG failed.\n\tModel tag %h\n\tDUT TAG %h\n", catch_up.dut_up_mvb_array[mvb.data[20-1 : 12]].data[sv_dma_bus_pack::DMA_REQUEST_UNITID_O-1 : sv_dma_bus_pack::DMA_REQUEST_TAG_O], mvb.data[20-1 : 12]);
                `uvm_error(this.get_full_name(), msg_1);
                errors++;
            end
            if (model_mfb.compare(dut_mfb) == 0) begin
                string msg_1;

                $swrite(msg_1, "\n\tCheck MFB failed.\n\tModel data %s\n\tDUT data %s\n", model_mfb.convert2string(), dut_mfb.convert2string());
                `uvm_error(this.get_full_name(), msg_1);
                errors++;
            end
            if (catch_up.dut_up_mvb_array[mvb.data[20-1 : 12]].data[sv_dma_bus_pack::DMA_REQUEST_LENGTH_W-1 : 0] != mvb.data[10-1 : 0]) begin
                string msg_1;

                $swrite(msg_1, "\n\tCheck LENGTH failed.\n\tModel LENGTH %h\n\tDUT LENGTH %h\n", catch_up.dut_up_mvb_array[mvb.data[20-1 : 12]].data[sv_dma_bus_pack::DMA_REQUEST_LENGTH_W-1 : 0], mvb.data[10-1 : 0]);
                `uvm_error(this.get_full_name(), msg_1);
                errors++;
            end
            compared++;
        end else begin
            $displayh("UP LIST of MVB %p\n", catch_up.dut_up_mvb_array);
            $write("DOWN MVB TR %h\n", mvb.data);
            $write("DOWN MVB TR TAG %h\n", mvb.data[20-1 : 12]);
            `uvm_error(this.get_full_name(), "Wrong port or read request was not send");
        end

        catch_up.dut_up_mfb_array.delete(mvb.data[20-1 : 12]);
        catch_up.dut_up_mvb_array.delete(mvb.data[20-1 : 12]);
        dut_down_mvb_array.delete(mvb.data[20-1 : 12]);
        dut_down_mfb_array.delete(mvb.data[20-1 : 12]);
    endtask

endclass


class compare #(PCIE_UPHDR_WIDTH, PCIE_PREFIX_WIDTH) extends uvm_component;
    `uvm_component_param_utils(uvm_ptc::compare #(PCIE_UPHDR_WIDTH, PCIE_PREFIX_WIDTH))

    int unsigned errors;
    int unsigned compared;

    uvm_logic_vector_array::sequence_item #(32)         mfb_tr_table[$];
    uvm_logic_vector::sequence_item #(PCIE_UPHDR_WIDTH) mvb_tr_table[$];

    uvm_logic_vector_array::sequence_item #(32)         rq_mfb_tr_table[$];
    uvm_logic_vector::sequence_item #(PCIE_UPHDR_WIDTH) rq_mvb_tr_table[$];
    uvm_logic_vector::sequence_item #(PCIE_UPHDR_WIDTH) rq_prefix_mvb_tr_table[$];

    function new(string name, uvm_component parent);
        super.new(name, parent);
        errors     = 0;
        compared   = 0;
    endfunction

    task comp();
        uvm_logic_vector_array::sequence_item #(32)         tr_model_up_mfb;
        uvm_logic_vector::sequence_item #(PCIE_UPHDR_WIDTH) tr_model_up_mvb;

        uvm_logic_vector_array::sequence_item #(32)          tr_dut_rq_mfb;
        uvm_logic_vector::sequence_item #(PCIE_UPHDR_WIDTH)  tr_dut_rq_mvb;
        uvm_logic_vector::sequence_item #(PCIE_PREFIX_WIDTH) tr_dut_rq_mvb_pref;
        string debug_msg = "";

        if (mvb_tr_table.size() != 0 && rq_mvb_tr_table.size() != 0) begin

            tr_model_up_mvb = mvb_tr_table.pop_front();
            tr_dut_rq_mvb = rq_mvb_tr_table.pop_front();
            tr_model_up_mfb = mfb_tr_table.pop_front();
            tr_dut_rq_mfb = rq_mfb_tr_table.pop_front();

            $swrite(debug_msg, "%s\n\t Model MFB RQ TR: %s\n", debug_msg, tr_model_up_mfb.convert2string());
            $swrite(debug_msg, "%s\n\t Model MVB RQ TR: %s\n", debug_msg, tr_model_up_mvb.convert2string());
            $swrite(debug_msg, "%s\n\t DUT MFB RQ TR:   %s\n", debug_msg, tr_dut_rq_mfb.convert2string());
            $swrite(debug_msg, "%s\n\t DUT MVB RQ TR:   %s\n", debug_msg, tr_dut_rq_mvb.convert2string());
            `uvm_info(this.get_full_name(), debug_msg ,UVM_MEDIUM);

            compared++;
            if (tr_dut_rq_mfb.compare(tr_model_up_mfb) == 0 || tr_dut_rq_mvb.compare(tr_model_up_mvb) == 0) begin
                string msg;

                errors++;
                $swrite(msg, "\n\tCheck MVB or MFB packet failed.\n\tModel MFB %s\n\tDUT MFB %s\n\n\tModel MVB\n%s\n\tDUT MVB\n%s\n COMPARED %d\n", tr_model_up_mfb.convert2string(),
                tr_dut_rq_mfb.convert2string(), tr_model_up_mvb.convert2string(), tr_dut_rq_mvb.convert2string(), compared);
                `uvm_error(this.get_full_name(), msg);
            end
        end
    endtask
endclass


class scoreboard #(META_WIDTH, MFB_DOWN_REGIONS, MFB_UP_REGIONS, DMA_MVB_UP_ITEMS, PCIE_PREFIX_WIDTH, PCIE_UPHDR_WIDTH, DMA_MVB_DOWN_ITEMS, PCIE_DOWNHDR_WIDTH, DMA_PORTS, ENDPOINT_TYPE) extends uvm_scoreboard;
    `uvm_component_param_utils(uvm_ptc::scoreboard #(META_WIDTH, MFB_DOWN_REGIONS, MFB_UP_REGIONS, DMA_MVB_UP_ITEMS, PCIE_PREFIX_WIDTH, PCIE_UPHDR_WIDTH, DMA_MVB_DOWN_ITEMS, PCIE_DOWNHDR_WIDTH, DMA_PORTS, ENDPOINT_TYPE))


    uvm_analysis_export #(uvm_logic_vector_array::sequence_item #(32))           rc_mfb_in;
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(PCIE_DOWNHDR_WIDTH)) rc_mvb_in;
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(PCIE_PREFIX_WIDTH))  rc_prefix_mvb_in;

    uvm_analysis_export #(uvm_logic_vector_array::sequence_item #(32))           rq_mfb_out;
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(PCIE_UPHDR_WIDTH))   rq_mvb_out;
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(PCIE_PREFIX_WIDTH))  rq_prefix_mvb_out;

    uvm_analysis_export #(uvm_logic_vector_array::sequence_item #(32))          up_mfb_in[DMA_PORTS];
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(sv_dma_bus_pack::DMA_UPHDR_WIDTH))   up_mvb_in[DMA_PORTS];

    uvm_analysis_export #(uvm_logic_vector_array::sequence_item #(32))           down_mfb_out[DMA_PORTS];
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(sv_dma_bus_pack::DMA_DOWNHDR_WIDTH)) down_mvb_out[DMA_PORTS];

    // Model FIFO

    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item #(32))          model_up_mfb_out;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(PCIE_UPHDR_WIDTH))  model_up_mvb_out;
    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item #(32))          model_down_mfb_out[DMA_PORTS];
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(sv_dma_bus_pack::DMA_DOWNHDR_WIDTH)) model_down_mvb_out[DMA_PORTS];

    // DUT FIFO
    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item #(32))           dut_down_mfb_out[DMA_PORTS];
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(sv_dma_bus_pack::DMA_DOWNHDR_WIDTH))  dut_down_mvb_out[DMA_PORTS];

    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item #(32))           dut_rq_mfb_out;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(PCIE_UPHDR_WIDTH))   dut_rq_mvb_out;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(PCIE_PREFIX_WIDTH))  dut_rq_prefix_mvb_out;

    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item #(32))           dut_rc_mfb_out;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(PCIE_DOWNHDR_WIDTH)) dut_rc_mvb_out;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(PCIE_PREFIX_WIDTH))  dut_rc_prefix_mvb_out;

    //uvm_ptc_info::sync_tag tag_sync[DMA_PORTS];
    model #(META_WIDTH, MFB_DOWN_REGIONS, MFB_UP_REGIONS, DMA_PORTS, DMA_MVB_UP_ITEMS, PCIE_UPHDR_WIDTH, PCIE_DOWNHDR_WIDTH, PCIE_PREFIX_WIDTH, ENDPOINT_TYPE) m_model;
    down_model #(DMA_PORTS, PCIE_DOWNHDR_WIDTH, PCIE_PREFIX_WIDTH) m_down_model;
    uvm_ptc::compare #(PCIE_UPHDR_WIDTH, PCIE_PREFIX_WIDTH) out_compare[DMA_PORTS];
    uvm_ptc::rc_compare answer_compare[DMA_PORTS];
    uvm_ptc::up_catch catch_up[DMA_PORTS];
    int unsigned errors;
    int unsigned compared;
    int unsigned rq_read_cnt[DMA_PORTS];
    int unsigned rq_write_cnt[DMA_PORTS];

    // Contructor of scoreboard.
    function new(string name, uvm_component parent);
        super.new(name, parent);
        rc_mfb_in             = new("rc_mfb_in",             this);
        rc_mvb_in             = new("rc_mvb_in",             this);
        rc_prefix_mvb_in      = new("rc_prefix_mvb_in",      this);

        dut_rc_mfb_out        = new("dut_rc_mfb_out",        this);
        dut_rc_mvb_out        = new("dut_rc_mvb_out",        this);
        dut_rc_prefix_mvb_out = new("dut_rc_prefix_mvb_out", this);

        rq_mfb_out            = new("rq_mfb_out",            this);
        rq_mvb_out            = new("rq_mvb_out",            this);
        rq_prefix_mvb_out     = new("rq_prefix_mvb_out",     this);

        dut_rq_mfb_out        = new("dut_rq_mfb_out",        this);
        dut_rq_mvb_out        = new("dut_rq_mvb_out",        this);
        dut_rq_prefix_mvb_out = new("dut_rq_prefix_mvb_out", this);

        model_up_mfb_out      = new("model_up_mfb_out",      this);
        model_up_mvb_out      = new("model_up_mvb_out",      this);

        for (int unsigned it = 0; it < DMA_PORTS; it++) begin
            string it_str;
            it_str.itoa(it);
            up_mfb_in[it]        = new({"up_mfb_in_", it_str}, this);
            up_mvb_in[it]        = new({"up_mvb_in_", it_str}, this);
            down_mvb_out[it]       = new({"down_mvb_out_", it_str}, this);
            down_mfb_out[it]       = new({"down_mfb_out_", it_str}, this);
            dut_down_mfb_out[it]   = new({"dut_down_mfb_out_", it_str}, this);
            dut_down_mvb_out[it]   = new({"dut_down_mvb_out_", it_str}, this);
            model_down_mfb_out[it] = new({"model_down_mfb_out_", it_str}, this);
            model_down_mvb_out[it] = new({"model_down_mvb_out_", it_str}, this);

            rq_read_cnt[it] = '0;
            rq_write_cnt[it] = '0;
        end
        errors = 0;
        compared = 0;
    endfunction

    function int unsigned used();
        int unsigned ret = 0;
        ret |= (dut_rq_mfb_out.used() != 0);
        ret |= (dut_rq_mvb_out.used() != 0);
        ret |= (dut_rc_mfb_out.used() != 0);
        ret |= (dut_rc_mvb_out.used() != 0);
        ret |= (model_up_mfb_out.used() != 0);
        ret |= (model_up_mvb_out.used() != 0);

        for (int it = 0; it < DMA_PORTS; it++) begin
            ret |= (model_down_mfb_out[it].used() != 0);
            ret |= (model_down_mvb_out[it].used() != 0);
        end
        return ret;
    endfunction

    function void build_phase(uvm_phase phase);
        m_model = model #(META_WIDTH, MFB_DOWN_REGIONS, MFB_UP_REGIONS, DMA_PORTS, DMA_MVB_UP_ITEMS, PCIE_UPHDR_WIDTH, PCIE_DOWNHDR_WIDTH, PCIE_PREFIX_WIDTH, ENDPOINT_TYPE)::type_id::create("m_model", this);
        m_down_model = down_model #(DMA_PORTS, PCIE_DOWNHDR_WIDTH, PCIE_PREFIX_WIDTH)::type_id::create("m_down_model", this);

        for (int it = 0; it < DMA_PORTS; it++) begin
            string it_string;

            it_string.itoa(it);
            out_compare[it]    = uvm_ptc::compare #(PCIE_UPHDR_WIDTH, PCIE_PREFIX_WIDTH)::type_id::create({"out_compare_", it_string}, this);
            answer_compare[it] = uvm_ptc::rc_compare::type_id::create({"answer_compare_", it_string}, this);
            catch_up[it]       = uvm_ptc::up_catch::type_id::create({"catch_up_", it_string}, this);
        end

    endfunction

    function int unsigned error_cnt();
        int unsigned ret = 0;
        ret |= (out_compare[0].errors != 0);
        ret |= (answer_compare[0].errors != 0);
        return ret;
    endfunction

    function void connect_phase(uvm_phase phase);
        // Model inputs
        rc_mfb_in.connect(m_down_model.model_rc_mfb_in.analysis_export);
        rc_mvb_in.connect(m_down_model.model_rc_mvb_in.analysis_export);
        rc_prefix_mvb_in.connect(m_down_model.model_rc_prefix_mvb_in.analysis_export);

        // DUT outputs
        rq_mfb_out.connect(dut_rq_mfb_out.analysis_export);
        rq_mvb_out.connect(dut_rq_mvb_out.analysis_export);
        rq_prefix_mvb_out.connect(dut_rq_prefix_mvb_out.analysis_export);

        // Model outputs
        for (int it = 0; it < DMA_PORTS; it++) begin
            string i_string;
            // Model inputs
            up_mfb_in[it].connect(m_model.model_up_mfb_in[it].analysis_export);
            up_mvb_in[it].connect(m_model.model_up_mvb_in[it].analysis_export);

            // Model outputs
            m_down_model.model_down_mfb_out[it].connect(answer_compare[it].model_mfb.analysis_export);
            m_down_model.model_down_mvb_out[it].connect(answer_compare[it].model_mvb.analysis_export);
            down_mfb_out[it].connect(answer_compare[it].dut_mfb.analysis_export);
            down_mvb_out[it].connect(answer_compare[it].dut_mvb.analysis_export);

            up_mfb_in[it].connect(catch_up[it].up_mfb_gen.analysis_export);
            up_mvb_in[it].connect(catch_up[it].up_mvb_gen.analysis_export);
            answer_compare[it].catch_up = catch_up[it];

        end
        m_model.model_up_mfb_out.connect(model_up_mfb_out.analysis_export);
        m_model.model_up_mvb_out.connect(model_up_mvb_out.analysis_export);
    endfunction

    task run_phase(uvm_phase phase);
        uvm_logic_vector_array::sequence_item #(32)          tr_model_up_mfb;
        uvm_logic_vector::sequence_item #(PCIE_UPHDR_WIDTH)  tr_model_up_mvb;

        uvm_logic_vector_array::sequence_item #(32)          tr_dut_rq_mfb;
        uvm_logic_vector::sequence_item #(PCIE_UPHDR_WIDTH)  tr_dut_rq_mvb;
        uvm_logic_vector::sequence_item #(PCIE_PREFIX_WIDTH) tr_dut_rq_mvb_pref;

        uvm_logic_vector_array::sequence_item #(32)          tr_dut_down_mfb[DMA_PORTS];
        uvm_logic_vector::sequence_item #(sv_dma_bus_pack::DMA_DOWNHDR_WIDTH) tr_dut_down_mvb[DMA_PORTS];

        forever begin

            model_up_mfb_out.get(tr_model_up_mfb);
            model_up_mvb_out.get(tr_model_up_mvb);
            dut_rq_mfb_out.get(tr_dut_rq_mfb);
            dut_rq_mvb_out.get(tr_dut_rq_mvb);

            if (tr_model_up_mvb.data[30] == 1'b1) begin
                out_compare[int'(tr_model_up_mvb.data[64-16])].mfb_tr_table.push_back(tr_model_up_mfb);
                out_compare[int'(tr_model_up_mvb.data[64-16])].mvb_tr_table.push_back(tr_model_up_mvb);
            end
            if (tr_dut_rq_mvb.data[30] == 1'b1) begin
                out_compare[int'(tr_dut_rq_mvb.data[64-16])].rq_mfb_tr_table.push_back(tr_dut_rq_mfb);
                out_compare[int'(tr_dut_rq_mvb.data[64-16])].rq_mvb_tr_table.push_back(tr_dut_rq_mvb);
                rq_write_cnt[tr_dut_rq_mvb.data[64-16]]++;
            end else
                rq_read_cnt[tr_dut_rq_mvb.data[64-16]]++;

            for (int i = 0; i < DMA_PORTS; i++) begin
                out_compare[i].comp();
            end
        end
    endtask

    // TODO
    function void report_phase(uvm_phase phase);
       int unsigned errors = 0;
       string msg = "";

       for (int unsigned it = 0; it < DMA_PORTS; it++) begin
            $swrite(msg, "%s\n\t OUT OUTPUT [%0d] compared %0d errors %0d",              msg, it, out_compare[it].compared, out_compare[it].errors);
            $swrite(msg, "%s\n\t ANSWER OUTPUT [%0d] compared %0d errors %0d",           msg, it, answer_compare[it].compared, answer_compare[it].errors);
            $swrite(msg, "%s\n\t RQ TR TABLE [%0d] size %0d UP TR TABLE [%0d] size %0d\n", msg, it, out_compare[it].rq_mvb_tr_table.size(), it,  out_compare[it].mvb_tr_table.size());
            $swrite(msg, "%s\n\t model_down_mfb_out[%0d] USED [%0d]",                  msg, it, model_down_mfb_out[it].used());
            $swrite(msg, "%s\n\t model_down_mvb_out[%0d] USED [%0d]\n",                  msg, it, model_down_mvb_out[it].used());
       end
            $swrite(msg, "%s\n\t dut_rq_mfb_out USED [%0d]",   msg, dut_rq_mfb_out.used());
            $swrite(msg, "%s\n\t dut_rq_mvb_out USED [%0d]",   msg, dut_rq_mvb_out.used());
            $swrite(msg, "%s\n\t dut_rc_mfb_out USED [%0d]",   msg, dut_rc_mfb_out.used());
            $swrite(msg, "%s\n\t dut_rc_mvb_out USED [%0d]",   msg, dut_rc_mvb_out.used());
            $swrite(msg, "%s\n\t model_up_mfb_out USED [%0d]", msg, model_up_mfb_out.used());
            $swrite(msg, "%s\n\t model_up_mvb_out USED [%0d]\n", msg, model_up_mvb_out.used());
            $swrite(msg, "%s\n\t Final USED [%0d]",              msg, this.used());

       if (this.error_cnt() == 0 && this.used() == 0) begin
           `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION SUCCESS      ----\n\t---------------------------------------"}, UVM_NONE)
       end else begin
           `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION FAIL      ----\n\t---------------------------------------"}, UVM_NONE)
       end
    endfunction

endclass
