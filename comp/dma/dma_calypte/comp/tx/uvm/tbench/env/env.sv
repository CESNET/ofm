//-- env.sv: Verification environment
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

// Environment for functional verification of encode.
// This environment containts two mii agents.
class env #(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH, PCIE_CQ_MFB_REGIONS,
            PCIE_CQ_MFB_REGION_SIZE, PCIE_CQ_MFB_BLOCK_SIZE, PCIE_CQ_MFB_ITEM_WIDTH, CHANNELS, PKT_SIZE_MAX, MI_WIDTH, DEVICE, DEBUG, DATA_PTR_WIDTH) extends uvm_env;
    `uvm_component_param_utils(uvm_dma_ll::env #(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH,
                                                 PCIE_CQ_MFB_REGIONS, PCIE_CQ_MFB_REGION_SIZE, PCIE_CQ_MFB_BLOCK_SIZE, PCIE_CQ_MFB_ITEM_WIDTH,
                                                 CHANNELS, PKT_SIZE_MAX, MI_WIDTH, DEVICE, DEBUG, DATA_PTR_WIDTH));

    localparam USER_META_WIDTH = 24 + $clog2(PKT_SIZE_MAX+1) + $clog2(CHANNELS);

    sequencer#(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH, PCIE_CQ_MFB_ITEM_WIDTH,
              CHANNELS, PKT_SIZE_MAX) m_sequencer;

    uvm_reset::agent m_reset;
    uvm_dma_ll_rx::env #(PCIE_CQ_MFB_REGIONS, PCIE_CQ_MFB_REGION_SIZE, PCIE_CQ_MFB_BLOCK_SIZE, PCIE_CQ_MFB_ITEM_WIDTH, CHANNELS,
                         PKT_SIZE_MAX, DATA_PTR_WIDTH, DEVICE)                                                         m_env_rx;
    uvm_logic_vector_array_mfb::env_tx #(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE,
                                         USER_TX_MFB_ITEM_WIDTH, USER_META_WIDTH)                                      m_env_tx;
    uvm_logic_vector_mvb::env_tx #(1, 1)                                                                               m_dma;
    uvm_mi::regmodel#(uvm_dma_regs::regmodel#(CHANNELS), MI_WIDTH, MI_WIDTH)                                           m_regmodel;

    uvm_dma_ll_info::watchdog #(CHANNELS) m_watch_dog;

    scoreboard #(CHANNELS, PKT_SIZE_MAX, DEVICE, USER_TX_MFB_ITEM_WIDTH, USER_META_WIDTH, PCIE_CQ_MFB_ITEM_WIDTH,
                 DATA_PTR_WIDTH, DEBUG) sc;

    // Constructor of environment.
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Create base components of environment.
    function void build_phase(uvm_phase phase);
        uvm_reset::config_item                  m_config_reset;
        uvm_dma_ll_rx::config_item              m_config_rx;
        uvm_logic_vector_array_mfb::config_item m_config_tx;
        uvm_logic_vector_mvb::config_item       m_dma_config;
        uvm_mi::regmodel_config                 m_mi_config;

        m_watch_dog = uvm_dma_ll_info::watchdog#(CHANNELS)::type_id::create("m_watch_dog", this);

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
                                        CHANNELS, PKT_SIZE_MAX, DATA_PTR_WIDTH, DEVICE)::type_id::create("m_env_rx", this);

        m_mi_config                      = new();
        m_mi_config.addr_base            = 'h0;
        m_mi_config.agent.active         = UVM_ACTIVE;
        m_mi_config.agent.interface_name = "vif_mi";
        uvm_config_db#(uvm_mi::regmodel_config)::set(this, "m_regmodel", "m_config", m_mi_config);
        m_regmodel = uvm_mi::regmodel#(uvm_dma_regs::regmodel#(CHANNELS), MI_WIDTH, MI_WIDTH)::type_id::create("m_regmodel", this);

        sc  = scoreboard #(CHANNELS, PKT_SIZE_MAX, DEVICE, USER_TX_MFB_ITEM_WIDTH, USER_META_WIDTH, PCIE_CQ_MFB_ITEM_WIDTH,
                           DATA_PTR_WIDTH, DEBUG)::type_id::create("sc", this);

        m_sequencer = sequencer#(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH,
                                 PCIE_CQ_MFB_ITEM_WIDTH, CHANNELS, PKT_SIZE_MAX)::type_id::create("m_sequencer", this);

        m_config_tx                = new;
        m_config_tx.active         = UVM_ACTIVE;
        m_config_tx.interface_name = "vif_tx";
        m_config_tx.meta_behav     = uvm_logic_vector_array_mfb::config_item::META_SOF;
        uvm_config_db #(uvm_logic_vector_array_mfb::config_item)::set(this, "m_env_tx", "m_config", m_config_tx);
        m_env_tx = uvm_logic_vector_array_mfb::env_tx #(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH, USER_META_WIDTH)::type_id::create("m_env_tx", this);

        m_dma_config                = new;
        m_dma_config.active         = UVM_PASSIVE;
        m_dma_config.interface_name = "vif_dma";
        uvm_config_db #(uvm_logic_vector_mvb::config_item)::set(this, "m_dma", "m_config", m_dma_config);
        m_dma = uvm_logic_vector_mvb::env_tx #(1, 1)::type_id::create("m_dma", this);

    endfunction

    // Connect agent's ports with ports from scoreboard.
    function void connect_phase(uvm_phase phase);
        m_env_rx.m_env_rx.analysis_port_data.connect(sc.analysis_export_rx_packet);
        m_env_rx.m_env_rx.analysis_port_meta.connect(sc.analysis_export_rx_meta);
        m_sequencer.m_reset    = m_reset.m_sequencer;
        m_sequencer.m_packet   = m_env_rx.m_sequencer;
        m_sequencer.m_regmodel = m_regmodel.m_regmodel;
        sc.regmodel_set(m_regmodel.m_regmodel);
        m_env_rx.regmodel_set(m_regmodel.m_regmodel);
        m_env_rx.m_watch_dog = m_watch_dog;
        m_reset.sync_connect(m_env_rx.reset_sync);

        m_dma.analysis_port.connect(sc.analysis_export_dma);
        m_env_tx.analysis_port_data.connect(sc.analysis_export_tx_packet);
        m_env_tx.analysis_port_meta.connect(sc.analysis_export_tx_meta);
        m_sequencer.m_pcie = m_env_tx.m_sequencer;

        m_reset.sync_connect(m_env_rx.reset_sync);
    endfunction

endclass
