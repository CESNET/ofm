//-- test.sv: Verification test 
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 


class virt_seq_full_speed#(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH,
                           CHANNELS, PKT_SIZE_MAX) extends virt_seq#(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE,
                                                                                                 USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH,
                                                                                                  CHANNELS, PKT_SIZE_MAX);

    `uvm_object_param_utils(test::virt_seq_full_speed#(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH,
                                                        CHANNELS, PKT_SIZE_MAX))

    `uvm_declare_p_sequencer(uvm_dma_ll::sequencer#(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH,
                                                    CHANNELS, PKT_SIZE_MAX))

    localparam USER_META_WIDTH = 24 + $clog2(PKT_SIZE_MAX+1) + $clog2(CHANNELS);

    function new (string name = "virt_seq_full_speed");
        super.new(name);
    endfunction

    virtual function void init();
        super.init();
        m_pcie = uvm_mfb::sequence_full_speed_tx#(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH, USER_META_WIDTH)::type_id::create("m_pcie_lib");
    endfunction
endclass

class mfb_rx_speed#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) extends uvm_logic_vector_array_mfb::sequence_lib_rx#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH);
  `uvm_object_param_utils(    mfb_rx_speed#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH))
  `uvm_sequence_library_utils(mfb_rx_speed#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH))

    function new(string name = "mfb_rx_speed");
        super.new(name);
        init_sequence_library();
    endfunction

    virtual function void init_sequence(uvm_logic_vector_array_mfb::config_sequence param_cfg = null);
        if (param_cfg == null) begin
            this.cfg = new();
        end else begin
            this.cfg = param_cfg;
        end


        this.add_sequence(uvm_logic_vector_array_mfb::sequence_full_speed_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH)::get_type());
    endfunction
endclass


class speed extends base;
    typedef uvm_component_registry#(test::speed, "test::speed") type_id;


    uvm_dma_ll::env #(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH,
                      PCIE_CQ_MFB_REGIONS, PCIE_CQ_MFB_REGION_SIZE, PCIE_CQ_MFB_BLOCK_SIZE, PCIE_CQ_MFB_ITEM_WIDTH, PCIE_LEN_MAX,
                      CHANNELS, PKT_SIZE_MAX, MI_WIDTH, DEVICE, DATA_POINTER_WIDTH) m_env;
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
        uvm_logic_vector_array_mfb::sequence_lib_rx#(PCIE_CQ_MFB_REGIONS, PCIE_CQ_MFB_REGION_SIZE, PCIE_CQ_MFB_BLOCK_SIZE, PCIE_CQ_MFB_ITEM_WIDTH, sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)::type_id::set_inst_override(mfb_rx_speed#(PCIE_CQ_MFB_REGIONS, PCIE_CQ_MFB_REGION_SIZE, PCIE_CQ_MFB_BLOCK_SIZE, PCIE_CQ_MFB_ITEM_WIDTH, sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)::get_type(), {this.get_full_name(), ".m_env.m_env_rx.*"});

        m_env = uvm_dma_ll::env #(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH,
                                  PCIE_CQ_MFB_REGIONS, PCIE_CQ_MFB_REGION_SIZE, PCIE_CQ_MFB_BLOCK_SIZE, PCIE_CQ_MFB_ITEM_WIDTH, PCIE_LEN_MAX,
                                  CHANNELS, PKT_SIZE_MAX, MI_WIDTH, DEVICE, DATA_POINTER_WIDTH)::type_id::create("m_env", this);
    endfunction

    // ------------------------------------------------------------------------
    // Create environment and Run sequences o their sequencers
    virtual task run_phase(uvm_phase phase);
        virt_seq_full_speed#(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH,
                             CHANNELS, PKT_SIZE_MAX) m_vseq;

        //CREATE SEQUENCES
        m_vseq = virt_seq_full_speed#(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH, CHANNELS, PKT_SIZE_MAX)::type_id::create("m_vseq");

        //RISE OBJECTION
        phase.raise_objection(this);

        m_vseq.init();
        m_vseq.randomize();
        m_vseq.start(m_env.m_sequencer);

        timeout = 1;
        fork
            test_wait_timeout(3000);
            test_wait_result();
        join_any;

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

    task test_wait_timeout(int unsigned time_length);
        #(time_length*1us);
    endtask

    task test_wait_result();
        do begin
            #(6000ns);
        end while (m_env.sc.used() != 0);
        timeout = 0;
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info(this.get_full_name(), {"\n\tTEST : ", this.get_type_name(), " END\n"}, UVM_NONE);
        if (timeout) begin
            `uvm_error(this.get_full_name(), "\n\t===================================================\n\tTIMEOUT SOME PACKET STUCK IN DESIGN\n\t===================================================\n\n");
        end
    endfunction

endclass
