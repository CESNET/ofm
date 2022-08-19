// env.sv: Verification environment
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Mikuláš Brázda <xbrazd21@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause



// Environment for the functional verification.
class env #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) extends uvm_env;
    `uvm_component_param_utils(uvm_mfb_fifox::env #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH));

    uvm_logic_vector_array_mfb::env_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) m_env_rx;
    uvm_logic_vector_array_mfb::env_tx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) m_env_tx;

    uvm_mfb_fifox::virt_sequencer#(ITEM_WIDTH, META_WIDTH) vscr;
    uvm_reset::agent m_reset;

    scoreboard#(ITEM_WIDTH, META_WIDTH) sc;

    // Constructor of the environment.
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Create base components of the environment.
    function void build_phase(uvm_phase phase);

        uvm_reset::config_item            m_config_reset;
        uvm_logic_vector_array_mfb::config_item   m_config_rx;
        uvm_logic_vector_array_mfb::config_item   m_config_tx;

        m_config_reset                  = new;
        m_config_reset.active           = UVM_ACTIVE;
        m_config_reset.interface_name   = "vif_reset";

        uvm_config_db #(uvm_reset::config_item)::set(this, "m_reset", "m_config", m_config_reset);
        m_reset = uvm_reset::agent::type_id::create("m_reset", this);

        // Passing the virtual interfaces
        m_config_rx                  = new;
        m_config_rx.active           = UVM_ACTIVE;
        m_config_rx.interface_name   = "vif_rx";
        m_config_rx.meta_behav       = 1;

        uvm_config_db #(uvm_logic_vector_array_mfb::config_item)::set(this, "m_env_rx", "m_config", m_config_rx);
        m_env_rx = uvm_logic_vector_array_mfb::env_rx#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH)::type_id::create("m_env_rx", this);

        m_config_tx                  = new;
        m_config_tx.active           = UVM_ACTIVE;
        m_config_tx.interface_name   = "vif_tx";
        m_config_tx.meta_behav       = 1;

        uvm_config_db #(uvm_logic_vector_array_mfb::config_item)::set(this, "m_env_tx", "m_config", m_config_tx);
        m_env_tx = uvm_logic_vector_array_mfb::env_tx#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH)::type_id::create("m_env_tx", this);

        sc     = scoreboard#(ITEM_WIDTH, META_WIDTH)::type_id::create("sc", this);
        vscr   = uvm_mfb_fifox::virt_sequencer#(ITEM_WIDTH, META_WIDTH)::type_id::create("vscr",this);

    endfunction

    // Connect agent's ports with ports from the scoreboard.
    function void connect_phase(uvm_phase phase);

        m_env_rx.m_byte_array_agent.analysis_port.connect(sc.input_data);
        m_env_rx.m_logic_vector_agent.analysis_port.connect(sc.input_meta);

        m_env_tx.m_byte_array_agent.analysis_port.connect(sc.out_data);
        m_env_tx.m_logic_vector_agent.analysis_port.connect(sc.out_meta);

        m_reset.sync_connect(m_env_rx.reset_sync);
        m_reset.sync_connect(m_env_tx.reset_sync);

        vscr.m_reset = m_reset.m_sequencer;
        vscr.m_mfb_byte_array_scr = m_env_rx.m_sequencer;


    endfunction

endclass
