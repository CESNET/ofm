//-- env.sv: Verification environment
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

// Environment for functional verification of encode.
// This environment containts two mii agents.
class env #(ITEM_WIDTH) extends uvm_env;

    `uvm_component_param_utils(uvm_asfifox::env #(ITEM_WIDTH));

    uvm_mvb::agent_rx #(1, ITEM_WIDTH) agent_rx;
    uvm_mvb::config_item cfg_rx;

    uvm_mvb::agent_tx #(1, ITEM_WIDTH) agent_tx;
    uvm_mvb::config_item cfg_tx;

    scoreboard #(ITEM_WIDTH) m_scoreboard;

    uvm_mvb::coverage #(1, ITEM_WIDTH) m_cover_rx;
    uvm_mvb::coverage #(1, ITEM_WIDTH) m_cover_tx;

    // Constructor of environment.
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Create base components of environment.
    function void build_phase(uvm_phase phase);

        m_cover_rx = new("m_cover_rx");
        m_cover_tx = new("m_cover_tx");
        cfg_tx = new;
        cfg_rx = new;

        cfg_tx.active = UVM_ACTIVE;
        cfg_rx.active = UVM_ACTIVE;

        cfg_tx.interface_name = "vif_tx";
        cfg_rx.interface_name = "vif_rx";

        uvm_config_db #(uvm_mvb::config_item)::set(this, "agent_tx", "m_config", cfg_tx);
        uvm_config_db #(uvm_mvb::config_item)::set(this, "agent_rx", "m_config", cfg_rx);

        agent_tx    = uvm_mvb::agent_tx #(1, ITEM_WIDTH)::type_id::create("agent_tx", this);
        agent_rx    = uvm_mvb::agent_rx #(1, ITEM_WIDTH)::type_id::create("agent_rx", this);

        m_scoreboard  = scoreboard #(ITEM_WIDTH)::type_id::create("m_scoreboard", this);
    endfunction

    // Connect agent's ports with ports from scoreboard.
    function void connect_phase(uvm_phase phase);

        agent_rx.analysis_port.connect(m_scoreboard.analysis_imp_mvb_rx);
        agent_tx.analysis_port.connect(m_scoreboard.analysis_imp_mvb_tx);

        agent_rx.analysis_port.connect(m_cover_rx.analysis_export);
        agent_tx.analysis_port.connect(m_cover_tx.analysis_export);
    endfunction
endclass
