//-- base.sv: Basic test
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

class base extends uvm_test;
    typedef uvm_component_registry#(test::base, "test::base") type_id;


    uvm_dma_ll::env #(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH, PCIE_CQ_MFB_REGIONS,
                      PCIE_CQ_MFB_REGION_SIZE, PCIE_CQ_MFB_BLOCK_SIZE, PCIE_CQ_MFB_ITEM_WIDTH, PCIE_LEN_MAX, CHANNELS, PKT_SIZE_MAX, MI_WIDTH, DEVICE, DATA_POINTER_WIDTH) m_env;

    bit            timeout;
    uvm_reg_data_t dma_cnt          [CHANNELS];
    uvm_reg_data_t byte_cnt         [CHANNELS];
    uvm_reg_data_t discard_dma_cnt  [CHANNELS];
    uvm_reg_data_t discard_byte_cnt [CHANNELS];
    uvm_status_e   status_r;

    // ------------------------------------------------------------------------
    // Functions
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    static function type_id get_type();
        return type_id::get();
    endfunction

    function string get_type_name();
        return get_type().get_type_name();
    endfunction

    function void build_phase(uvm_phase phase);
        m_env = uvm_dma_ll::env #(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH, PCIE_CQ_MFB_REGIONS,
                                  PCIE_CQ_MFB_REGION_SIZE, PCIE_CQ_MFB_BLOCK_SIZE, PCIE_CQ_MFB_ITEM_WIDTH, PCIE_LEN_MAX, CHANNELS, PKT_SIZE_MAX, MI_WIDTH, DEVICE, DATA_POINTER_WIDTH)::type_id::create("m_env", this);
    endfunction

    // ------------------------------------------------------------------------
    // Create environment and Run sequences o their sequencers
    virtual task run_phase(uvm_phase phase);
        time time_start;
        virt_seq#(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH,
                  CHANNELS, PKT_SIZE_MAX) m_vseq;

        //CREATE SEQUENCES
        m_vseq = virt_seq#(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH,
                           CHANNELS, PKT_SIZE_MAX)::type_id::create("m_vseq");

        //RISE OBJECTION
        phase.raise_objection(this);

        m_vseq.init();
        m_vseq.randomize();
        m_vseq.start(m_env.m_sequencer);

        time_start = $time();
        while((time_start + 500us) > $time() && m_env.sc.used()) begin
            #(600ns);
        end


        for (int unsigned chan = 0; chan < CHANNELS; chan++) begin
            m_env.m_regmodel.m_regmodel.channel[chan].sent_packets.write(status_r, {32'h1, 32'h1});
            m_env.m_regmodel.m_regmodel.channel[chan].sent_packets.read(status_r, dma_cnt[chan]);
            m_env.m_regmodel.m_regmodel.channel[chan].sent_bytes.write(status_r, {32'h1, 32'h1});
            m_env.m_regmodel.m_regmodel.channel[chan].sent_bytes.read(status_r, byte_cnt[chan]);

            m_env.m_regmodel.m_regmodel.channel[chan].discarded_packets.write(status_r, {32'h1, 32'h1});
            m_env.m_regmodel.m_regmodel.channel[chan].discarded_packets.read(status_r, discard_dma_cnt[chan]);
            m_env.m_regmodel.m_regmodel.channel[chan].discarded_bytes.write(status_r, {32'h1, 32'h1});
            m_env.m_regmodel.m_regmodel.channel[chan].discarded_bytes.read(status_r, discard_byte_cnt[chan]);

            m_env.sc.byte_cnt[chan]         = byte_cnt[chan];
            m_env.sc.dma_cnt[chan]          = dma_cnt[chan];
            m_env.sc.discard_byte_cnt[chan] = discard_byte_cnt[chan];
            m_env.sc.discard_dma_cnt[chan]  = discard_dma_cnt[chan];
        end

        phase.drop_objection(this);
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info(this.get_full_name(), {"\n\tTEST : ", this.get_type_name(), " END\n"}, UVM_NONE);
    endfunction

endclass
