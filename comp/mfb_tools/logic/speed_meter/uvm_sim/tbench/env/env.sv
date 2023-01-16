//-- env.sv: Verification environment
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author:   Daniel Kříž <xkrizd01@vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

// Environment for functional verification of encode.
// This environment containts two mii agents.
class env #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, MI_DATA_WIDTH, MI_ADDRESS_WIDTH, SPACE_SIZE_MIN_RX, SPACE_SIZE_MAX_RX, SPACE_SIZE_MIN_TX, SPACE_SIZE_MAX_TX) extends uvm_env;

    `uvm_component_param_utils(uvm_speed_meter::env #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, MI_DATA_WIDTH, MI_ADDRESS_WIDTH, SPACE_SIZE_MIN_RX, SPACE_SIZE_MAX_RX, SPACE_SIZE_MIN_TX, SPACE_SIZE_MAX_TX));

    uvm_logic_vector_array_mfb::env_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, 0) rx_env;
    uvm_logic_vector_array_mfb::env_tx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, 0) tx_env;
    uvm_logic_vector_array_mfb::config_item                                               cfg_rx;
    uvm_logic_vector_array_mfb::config_item                                               cfg_tx;

    uvm_speed_meter::virt_sequencer#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, MI_DATA_WIDTH, MI_ADDRESS_WIDTH) vscr;

    uvm_reset::agent         m_reset;
    uvm_reset::config_item   m_config_reset;

    uvm_mi::agent_slave #(MI_DATA_WIDTH, MI_ADDRESS_WIDTH) m_mi_agent;
    uvm_mi::config_item                                    m_mi_config;


    // Constructor of environment.
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Create base components of environment.
    function void build_phase(uvm_phase phase);

        cfg_rx                = new;
        cfg_rx.active         = UVM_ACTIVE;
        cfg_rx.interface_name = "vif_rx";
        cfg_rx.meta_behav     = uvm_logic_vector_array_mfb::config_item::META_NONE;
        cfg_rx.seq_cfg        = new();
        cfg_rx.seq_cfg.space_size_set(SPACE_SIZE_MIN_RX, SPACE_SIZE_MAX_RX);

        cfg_tx                = new;
        cfg_tx.active         = UVM_ACTIVE;
        cfg_tx.interface_name = "vif_tx";
        cfg_tx.meta_behav     = uvm_logic_vector_array_mfb::config_item::META_NONE;
        cfg_tx.seq_cfg        = new();
        cfg_tx.seq_cfg.space_size_set(SPACE_SIZE_MIN_TX, SPACE_SIZE_MAX_TX);

        m_config_reset                = new;
        m_config_reset.active         = UVM_ACTIVE;
        m_config_reset.interface_name = "vif_reset";

        m_mi_config                = new();
        m_mi_config.active         = UVM_ACTIVE;
        m_mi_config.interface_name = "vif_mi";
        uvm_config_db#(uvm_mi::config_item)::set(this, "m_mi_agent", "m_config", m_mi_config);
        m_mi_agent = uvm_mi::agent_slave #(MI_DATA_WIDTH, MI_ADDRESS_WIDTH)::type_id::create("m_mi_agent", this);

        uvm_config_db#(uvm_reset::config_item)::set(this, "m_reset", "m_config", m_config_reset);
        m_reset = uvm_reset::agent::type_id::create("m_reset", this);

        uvm_config_db#(uvm_logic_vector_array_mfb::config_item)::set(this, "rx_env", "m_config", cfg_rx);
        uvm_config_db#(uvm_logic_vector_array_mfb::config_item)::set(this, "tx_env", "m_config", cfg_tx);

        rx_env = uvm_logic_vector_array_mfb::env_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, 0)::type_id::create("rx_env", this);
        tx_env = uvm_logic_vector_array_mfb::env_tx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, 0)::type_id::create("tx_env", this);

        vscr   = uvm_speed_meter::virt_sequencer#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, MI_DATA_WIDTH, MI_ADDRESS_WIDTH)::type_id::create("vscr",this);
    endfunction

    // Connect agent's ports with ports from scoreboard.
    function void connect_phase(uvm_phase phase);

        vscr.m_mi_sqr                 = m_mi_agent.m_sequencer;
        vscr.m_reset                  = m_reset.m_sequencer;
        vscr.m_logic_vector_array_scr = rx_env.m_sequencer.m_data;
        vscr.m_tx_sqr                 = tx_env.m_sequencer;
        m_reset.sync_connect(rx_env.reset_sync);

    endfunction
endclass
