//-- env.sv: Verification environment
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

// Environment for functional verification of encode.
// This environment containts two mii agents.
class env #(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH, PCIE_CQ_MFB_REGIONS,
            PCIE_CQ_MFB_REGION_SIZE, PCIE_CQ_MFB_BLOCK_SIZE, PCIE_CQ_MFB_ITEM_WIDTH, CHANNELS, PKT_SIZE_MAX, MI_WIDTH, DEVICE,
            FIFO_DEPTH, DEBUG, CHANNEL_ARBITER_EN) extends uvm_env;
    `uvm_component_param_utils(uvm_dma_ll::env #(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH,
                                                 PCIE_CQ_MFB_REGIONS, PCIE_CQ_MFB_REGION_SIZE, PCIE_CQ_MFB_BLOCK_SIZE, PCIE_CQ_MFB_ITEM_WIDTH,
                                                 CHANNELS, PKT_SIZE_MAX, MI_WIDTH, DEVICE, FIFO_DEPTH, DEBUG, CHANNEL_ARBITER_EN));

    localparam USER_META_WIDTH = 24 + $clog2(PKT_SIZE_MAX+1) + $clog2(CHANNELS);
    localparam MFB_WIDTH       = PCIE_CQ_MFB_REGIONS*PCIE_CQ_MFB_REGION_SIZE*PCIE_CQ_MFB_BLOCK_SIZE*PCIE_CQ_MFB_ITEM_WIDTH;
    localparam DATA_ADDR_W     = $clog2(FIFO_DEPTH*(MFB_WIDTH/8));
    localparam HDR_ADDR_W      = $clog2(FIFO_DEPTH);

    sequencer#(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH, PCIE_CQ_MFB_ITEM_WIDTH,
              CHANNELS, PKT_SIZE_MAX) m_sequencer;

    uvm_reset::agent m_reset;
    uvm_dma_ll_rx::env #(PCIE_CQ_MFB_REGIONS, PCIE_CQ_MFB_REGION_SIZE, PCIE_CQ_MFB_BLOCK_SIZE, PCIE_CQ_MFB_ITEM_WIDTH, CHANNELS,
                         PKT_SIZE_MAX, DATA_ADDR_W, HDR_ADDR_W, DEVICE)                                                         m_env_rx;
    uvm_logic_vector_array_mfb::env_tx #(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE,
                                         USER_TX_MFB_ITEM_WIDTH, USER_META_WIDTH)                                               m_env_tx[CHANNELS];
    uvm_logic_vector_mvb::env_tx #(1, 1)                                                                                        m_dma[CHANNELS];
    uvm_mi::regmodel#(regmodel#(CHANNELS), MI_WIDTH, MI_WIDTH)                                                                  m_regmodel;

    scoreboard #(CHANNELS, PKT_SIZE_MAX, DEVICE, USER_TX_MFB_ITEM_WIDTH, USER_META_WIDTH, PCIE_CQ_MFB_ITEM_WIDTH,
                 DATA_ADDR_W, DEBUG, CHANNEL_ARBITER_EN) sc;

    // Constructor of environment.
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Create base components of environment.
    function void build_phase(uvm_phase phase);
        uvm_reset::config_item                  m_config_reset;
        uvm_dma_ll_rx::config_item              m_config_rx;
        uvm_logic_vector_array_mfb::config_item m_config_tx[CHANNELS];
        uvm_logic_vector_mvb::config_item       m_dma_config[CHANNELS];
        uvm_mi::regmodel_config                 m_mi_config;

        m_config_reset                = new;
        m_config_reset.active         = UVM_ACTIVE;
        m_config_reset.interface_name = "vif_reset";
        uvm_config_db #(uvm_reset::config_item)::set(this, "m_reset", "m_config", m_config_reset);
        m_reset = uvm_reset::agent::type_id::create("m_reset", this);

        m_config_rx                = new;
        m_config_rx.active         = UVM_ACTIVE;
        m_config_rx.interface_name = "vif_rx";
        uvm_config_db #(uvm_dma_ll_rx::config_item)::set(this, "m_env_rx", "m_config", m_config_rx);
        m_env_rx = uvm_dma_ll_rx::env #(PCIE_CQ_MFB_REGIONS, PCIE_CQ_MFB_REGION_SIZE, PCIE_CQ_MFB_BLOCK_SIZE, PCIE_CQ_MFB_ITEM_WIDTH,
                                        CHANNELS, PKT_SIZE_MAX, DATA_ADDR_W, HDR_ADDR_W, DEVICE)::type_id::create("m_env_rx", this);

        m_mi_config                      = new();
        m_mi_config.addr_base            = 'h0;
        m_mi_config.agent.active         = UVM_ACTIVE;
        m_mi_config.agent.interface_name = "vif_mi";
        uvm_config_db#(uvm_mi::regmodel_config)::set(this, "m_regmodel", "m_config", m_mi_config);
        m_regmodel = uvm_mi::regmodel#(regmodel#(CHANNELS), MI_WIDTH, MI_WIDTH)::type_id::create("m_regmodel", this);

        sc  = scoreboard #(CHANNELS, PKT_SIZE_MAX, DEVICE, USER_TX_MFB_ITEM_WIDTH, USER_META_WIDTH, PCIE_CQ_MFB_ITEM_WIDTH,
                           DATA_ADDR_W, DEBUG, CHANNEL_ARBITER_EN)::type_id::create("sc", this);

        m_sequencer = sequencer#(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH,
                                 PCIE_CQ_MFB_ITEM_WIDTH, CHANNELS, PKT_SIZE_MAX)::type_id::create("m_sequencer", this);

        for(int chan = 0; chan < CHANNELS; chan++) begin
            string i_string;
            i_string.itoa(chan);

            m_config_tx[chan]                = new;
            m_config_tx[chan].active         = UVM_ACTIVE;
            m_config_tx[chan].interface_name = {"vif_tx_", i_string};
            m_config_tx[chan].meta_behav     = uvm_logic_vector_array_mfb::config_item::META_SOF;

            uvm_config_db #(uvm_logic_vector_array_mfb::config_item)::set(this, {"m_env_tx_", i_string}, "m_config", m_config_tx[chan]);
            m_env_tx[chan] = uvm_logic_vector_array_mfb::env_tx #(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH,
                                                                  USER_META_WIDTH)::type_id::create({"m_env_tx_", i_string}, this);

            m_dma_config[chan]                = new;
            m_dma_config[chan].active         = UVM_PASSIVE;
            m_dma_config[chan].interface_name = {"vif_dma_", i_string};
            uvm_config_db #(uvm_logic_vector_mvb::config_item)::set(this, {"m_dma_", i_string}, "m_config", m_dma_config[chan]);
            m_dma[chan] = uvm_logic_vector_mvb::env_tx #(1, 1)::type_id::create({"m_dma_", i_string}, this);
        end

    endfunction

    // Connect agent's ports with ports from scoreboard.
    function void connect_phase(uvm_phase phase);
        m_env_rx.m_env_rx.analysis_port_data.connect(sc.analysis_export_rx_packet);
        m_env_rx.m_env_rx.analysis_port_meta.connect(sc.analysis_export_rx_meta);
        m_sequencer.m_reset    = m_reset.m_sequencer;
        m_sequencer.m_packet   = m_env_rx.m_sequencer;
        m_sequencer.m_regmodel = m_regmodel.m_regmodel;
        sc.regmodel_set(m_regmodel.m_regmodel);
        m_reset.sync_connect(m_env_rx.reset_sync);

        for(int chan = 0; chan < CHANNELS; chan++) begin
            m_dma[chan].analysis_port.connect(sc.analysis_export_dma[chan]);
            m_env_tx[chan].analysis_port_data.connect(sc.analysis_export_tx_packet[chan]);
            m_env_tx[chan].analysis_port_meta.connect(sc.analysis_export_tx_meta[chan]);
            m_sequencer.m_pcie[chan] = m_env_tx[chan].m_sequencer;
        end
        m_reset.sync_connect(m_env_rx.reset_sync);
    endfunction

endclass
