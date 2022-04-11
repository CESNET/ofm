/*
 * file       : env.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: byte_array to lii_rx enviroment
 * date       : 2021
 * author     : Daniel Kriz <xkrizd01@vutbr.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/

`ifndef RX_ENV_SV
`define RX_ENV_SV

class env_base #(DATA_WIDTH, FAST_SOF, DIC_EN, VERBOSITY, META_WIDTH, LOGIC_WIDTH) extends uvm_env;

    `uvm_component_param_utils(byte_array_lii_rx_env::env_base #(DATA_WIDTH, FAST_SOF, DIC_EN, VERBOSITY, META_WIDTH, LOGIC_WIDTH));

    uvm_analysis_port #(byte_array::sequence_item) analysis_port_packet;
    uvm_analysis_port #(logic_vector::sequence_item#(LOGIC_WIDTH)) analysis_port_meta;

    // Definition of agents, high level agents are used on both sides.
    byte_array::agent m_byte_array_agent;
    byte_array::config_item byte_array_cfg_tx;

    logic_vector::agent#(LOGIC_WIDTH) m_logic_vector_agent;
    logic_vector::config_item logic_vector_agent_cfg;

    // Definition of agents, lII agents are used on both sides.
    lii_rx::agent #(DATA_WIDTH, FAST_SOF, META_WIDTH) m_lii_agent;
    lii_rx::config_item lii_cfg_tx;

    config_item m_config;

    //lii_rx::coverage_rx #(DATA_WIDTH, META_WIDTH) m_cover_tx;

    // Constructor of environment.
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Create base components of environment.
    function void build_phase(uvm_phase phase);

        if(!uvm_config_db #(config_item)::get(this, "", "m_config", m_config)) begin
            `uvm_fatal(get_type_name(), "Unable to get configuration object")
        end

        //m_cover_tx = new("m_cover_tx_mac");
        byte_array_cfg_tx = new;
        lii_cfg_tx = new;
        logic_vector_agent_cfg = new;

        byte_array_cfg_tx.active = m_config.active;

        lii_cfg_tx.active = m_config.active;
        lii_cfg_tx.interface_name = m_config.interface_name;

        logic_vector_agent_cfg.active = m_config.active;

        uvm_config_db #(byte_array::config_item)::set(this, "m_byte_array_agent", "m_config", byte_array_cfg_tx);
        uvm_config_db #(lii_rx::config_item)::set(this, "m_lii_agent", "m_config", lii_cfg_tx);
        uvm_config_db #(logic_vector::config_item)::set(this, "m_logic_vector_agent", "m_config", logic_vector_agent_cfg);

        byte_array::monitor::type_id::set_inst_override(monitor_byte_array #(DATA_WIDTH, DIC_EN, VERBOSITY, META_WIDTH)::get_type(), {this.get_full_name(), ".m_byte_array_agent.*"});
        logic_vector::monitor#(LOGIC_WIDTH)::type_id::set_inst_override(monitor_logic_vector #(DATA_WIDTH, DIC_EN, VERBOSITY, META_WIDTH, LOGIC_WIDTH)::get_type(), {this.get_full_name(), ".m_logic_vector_agent.*"});

        m_byte_array_agent    = byte_array::agent::type_id::create("m_byte_array_agent", this);
        m_lii_agent        = lii_rx::agent #(DATA_WIDTH, FAST_SOF, META_WIDTH)::type_id::create("m_lii_agent", this);
        m_logic_vector_agent = logic_vector::agent#(LOGIC_WIDTH)::type_id::create("m_logic_vector_agent", this);

    endfunction

    // Connect agent's ports with ports from scoreboard.
    function void connect_phase(uvm_phase phase);
        monitor_byte_array #(DATA_WIDTH, DIC_EN, VERBOSITY, META_WIDTH) m_byte_array_monitor;
        monitor_logic_vector #(DATA_WIDTH, DIC_EN, VERBOSITY, META_WIDTH, LOGIC_WIDTH) m_logic_vector_monitor;

        $cast(m_byte_array_monitor, m_byte_array_agent.m_monitor);
        m_lii_agent.analysis_port.connect(m_byte_array_monitor.analysis_export);

        $cast(m_logic_vector_monitor, m_logic_vector_agent.m_monitor);
        m_lii_agent.analysis_port.connect(m_logic_vector_monitor.analysis_export);

        analysis_port_packet = m_byte_array_agent.analysis_port;
        analysis_port_meta   = m_logic_vector_agent.analysis_port;

    endfunction

endclass

`endif