//-- env.sv: Verification environment
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

// Environment for functional verification of encode.
// This environment containts two mii agents.
class env_base #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH, SPLITTER_OUTPUTS) extends uvm_env;
    `uvm_component_param_utils(splitter_simple_env::env_base #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH, SPLITTER_OUTPUTS));

    byte_array_mfb_env::env_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, $clog2(SPLITTER_OUTPUTS) +META_WIDTH) m_env_rx;
    byte_array_mfb_env::env_tx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) m_env_tx[SPLITTER_OUTPUTS];

    byte_array_mfb_env::config_item m_config_rx;
    byte_array_mfb_env::config_item m_config_tx[SPLITTER_OUTPUTS];

    scoreboard #(META_WIDTH, SPLITTER_OUTPUTS) sc; 

    // Constructor of environment.
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Create base components of environment.
    function void build_phase(uvm_phase phase);

        m_config_rx= new;
        m_config_rx.active = UVM_ACTIVE;
        m_config_rx.interface_name = "vif_rx";
        m_config_rx.meta_behav = 1;

        uvm_config_db #(byte_array_mfb_env::config_item)::set(this, "m_env_rx", "m_config", m_config_rx);
        m_env_rx = byte_array_mfb_env::env_rx#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, $clog2(SPLITTER_OUTPUTS) +META_WIDTH)::type_id::create("m_env_rx", this);


        for(int i = 0; i < SPLITTER_OUTPUTS; i++) begin
            string i_string;
            i_string.itoa(i);

            m_config_tx[i] = new;
            m_config_tx[i].active = UVM_ACTIVE;
            m_config_tx[i].interface_name = {"vif_tx_", i_string};
            m_config_tx[i].meta_behav = 1;

            uvm_config_db #(byte_array_mfb_env::config_item)::set(this, {"m_env_tx_", i_string}, "m_config", m_config_tx[i]);
            m_env_tx[i]    = byte_array_mfb_env::env_tx#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH)::type_id::create({"m_env_tx_", i_string}, this);
        end

        sc  = scoreboard #(META_WIDTH, SPLITTER_OUTPUTS)::type_id::create("sc", this);

    endfunction

    // Connect agent's ports with ports from scoreboard.
    function void connect_phase(uvm_phase phase);

        m_env_rx.m_byte_array_agent.analysis_port.connect(sc.input_data);
        m_env_rx.m_logic_vector_agent.analysis_port.connect(sc.input_meta);

        for (int i = 0; i < SPLITTER_OUTPUTS; i++) begin
            m_env_tx[i].m_byte_array_agent.analysis_port.connect(sc.out_data[i]);
            m_env_tx[i].m_logic_vector_agent.analysis_port.connect(sc.out_meta[i]);
        end
    endfunction

endclass
