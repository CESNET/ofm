// env.sv: Verification environment
// Copyright (C) 2023 CESNET z. s. p. o.
// Author:   Oliver Gurka <xgurka00@stud.fit.vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause

class env #(ITEMS, ITEM_WIDTH, TX_MVB_CNT) extends uvm_env;

    `uvm_component_param_utils(uvm_mvb_demux::env #(ITEMS, ITEM_WIDTH, TX_MVB_CNT));

    uvm_logic_vector_mvb::env_rx #(ITEMS, ITEM_WIDTH + $clog2(TX_MVB_CNT)) rx_env;
    uvm_logic_vector_mvb::config_item                 cfg_rx;
    uvm_logic_vector_mvb::env_tx #(ITEMS, ITEM_WIDTH) tx_env[TX_MVB_CNT - 1 : 0];
    uvm_logic_vector_mvb::config_item                 cfg_tx[TX_MVB_CNT - 1 : 0];

    uvm_mvb_demux::virt_sequencer#(ITEM_WIDTH, TX_MVB_CNT) vscr;
    uvm_reset::agent         m_reset;
    uvm_reset::config_item   m_config_reset;

    scoreboard #(ITEM_WIDTH, TX_MVB_CNT) m_scoreboard;

    uvm_mvb::coverage #(ITEMS, ITEM_WIDTH + $clog2(TX_MVB_CNT)) m_cover_rx;
    uvm_mvb::coverage #(ITEMS, ITEM_WIDTH) m_cover_tx;

    // Constructor of environment.
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Create base components of environment.
    function void build_phase(uvm_phase phase);

        m_cover_rx            = new("m_cover_rx");
        m_cover_tx            = new("m_cover_tx");
        cfg_rx                = new;

        cfg_rx.active         = UVM_ACTIVE;
        cfg_rx.interface_name = "rx_vif";

        for (int i = 0; i < TX_MVB_CNT; i++) begin
            cfg_tx[i]                = new;
            cfg_tx[i].active         = UVM_ACTIVE;
            cfg_tx[i].interface_name = $sformatf("tx_vif_%0d", i);
            uvm_config_db #(uvm_logic_vector_mvb::config_item)::set(this, $sformatf("tx_env_%0d", i), "m_config", cfg_tx[i]);
            tx_env[i] = uvm_logic_vector_mvb::env_tx #(ITEMS, ITEM_WIDTH)::type_id::create($sformatf("tx_env_%0d", i), this);
        end

        m_config_reset                = new;
        m_config_reset.active         = UVM_ACTIVE;
        m_config_reset.interface_name = "vif_reset";

        uvm_config_db #(uvm_reset::config_item)::set(this, "m_reset", "m_config", m_config_reset);
        m_reset = uvm_reset::agent::type_id::create("m_reset", this);

        uvm_config_db #(uvm_logic_vector_mvb::config_item)::set(this, "rx_env", "m_config", cfg_rx);
        rx_env = uvm_logic_vector_mvb::env_rx #(ITEMS, ITEM_WIDTH + $clog2(TX_MVB_CNT))::type_id::create("rx_env", this);

        m_scoreboard  = scoreboard #(ITEM_WIDTH, TX_MVB_CNT)::type_id::create("m_scoreboard", this);
        vscr   = uvm_mvb_demux::virt_sequencer#(ITEM_WIDTH, TX_MVB_CNT)::type_id::create("vscr",this);
    endfunction

    // Connect agent's ports with ports from scoreboard.
    function void connect_phase(uvm_phase phase);

        rx_env.analysis_port.connect(m_scoreboard.analysis_imp_mvb_rx.analysis_export);

        for (int i = 0; i < TX_MVB_CNT; i++) begin
            m_reset.sync_connect(tx_env[i].reset_sync);
            tx_env[i].m_mvb_agent.analysis_port.connect(m_cover_tx.analysis_export);
            tx_env[i].analysis_port.connect(m_scoreboard.analysis_imp_mvb_tx[i]);
        end

        m_reset.sync_connect(rx_env.reset_sync);
        rx_env.m_mvb_agent.analysis_port.connect(m_cover_rx.analysis_export);

        vscr.m_reset                = m_reset.m_sequencer;
        vscr.m_logic_vector_scr     = rx_env.m_sequencer;

    endfunction
endclass
