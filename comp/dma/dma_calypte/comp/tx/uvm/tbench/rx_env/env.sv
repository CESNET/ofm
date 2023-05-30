//-- env.sv
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

class env #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, CHANNELS, PKT_SIZE_MAX, DATA_ADDR_W, DEVICE) extends uvm_env;
    `uvm_component_param_utils(uvm_dma_ll_rx::env #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, CHANNELS, PKT_SIZE_MAX, DATA_ADDR_W, DEVICE));

    //top sequencer
    sequencer#(ITEM_WIDTH, CHANNELS)                                  m_sequencer;
    driver #(CHANNELS, PKT_SIZE_MAX, ITEM_WIDTH, DATA_ADDR_W, DEVICE) m_driver[CHANNELS];
    channel_binder #(CHANNELS, ITEM_WIDTH)                            m_channel_binder;
    local uvm_dma_regs::regmodel #(CHANNELS)                          m_regmodel;

    //toplevel
    uvm_logic_vector_array::agent#(ITEM_WIDTH) m_logic_vector_array_agent[CHANNELS];
    //low level
    uvm_logic_vector_array_mfb::env_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, sv_pcie_meta_pack::PCIE_CQ_META_WIDTH) m_env_rx;
    //implement later
    uvm_reset::sync_cbs reset_sync;
    //configuration
    config_item m_config;
    uvm_dma_ll_info::watchdog #(CHANNELS) m_watch_dog;

    // Constructor of environment.
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void regmodel_set(uvm_dma_regs::regmodel#(CHANNELS) m_regmodel);
        this.m_regmodel = m_regmodel;
    endfunction

    // Create base components of environment.
    function void build_phase(uvm_phase phase);
        uvm_logic_vector_array::config_item     m_logic_vector_array_agent_cfg[CHANNELS];
        uvm_logic_vector_array_mfb::config_item m_env_rx_cfg;

        if(!uvm_config_db #(config_item)::get(this, "", "m_config", m_config)) begin
            `uvm_fatal(get_type_name(), "Unable to get configuration object")
        end

        // LOW level agent
        m_env_rx_cfg                = new;
        m_env_rx_cfg.active         = m_config.active;
        m_env_rx_cfg.seq_type       = "PCIE";
        m_env_rx_cfg.interface_name = m_config.interface_name;
        m_env_rx_cfg.meta_behav     = uvm_logic_vector_array_mfb::config_item::META_SOF;

        uvm_config_db #(uvm_logic_vector_array_mfb::config_item)::set(this, "m_env_rx", "m_config", m_env_rx_cfg);
        m_env_rx  = uvm_logic_vector_array_mfb::env_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)::type_id::create("m_env_rx", this);
        m_channel_binder = channel_binder #(CHANNELS, ITEM_WIDTH)::type_id::create("m_channel_binder", this);

        for (int unsigned chan = 0; chan < CHANNELS; chan++) begin
            string i_string;
            i_string.itoa(chan);

            m_logic_vector_array_agent_cfg[chan]        = new();
            m_logic_vector_array_agent_cfg[chan].active = m_config.active;

            uvm_config_db #(uvm_logic_vector_array::config_item)::set(this, {"m_logic_vector_array_agent_", i_string}, "m_config", m_logic_vector_array_agent_cfg[chan]);

            m_logic_vector_array_agent[chan] = uvm_logic_vector_array::agent#(ITEM_WIDTH)::type_id::create({"m_logic_vector_array_agent_", i_string}, this);
            m_driver[chan]                   = driver#(CHANNELS, PKT_SIZE_MAX, ITEM_WIDTH, DATA_ADDR_W, DEVICE)::type_id::create({"m_driver_", i_string}, this);

            m_driver[chan].channel    = chan;
        end

        if (m_config.active == UVM_ACTIVE) begin
            m_sequencer = sequencer#(ITEM_WIDTH, CHANNELS)::type_id::create("m_sequencer", this);
        end

        reset_sync = new();
    endfunction

    // Connect agent's ports with ports from scoreboard.
    function void connect_phase(uvm_phase phase);
        if (m_config.active == UVM_ACTIVE) begin

            for (int unsigned chan = 0; chan < CHANNELS; chan++) begin
                m_sequencer.m_data[chan] = m_logic_vector_array_agent[chan].m_sequencer;
                m_driver[chan].seq_item_port_logic_vector_array.connect(m_logic_vector_array_agent[chan].m_sequencer.seq_item_export);
                m_channel_binder.data_in_export[chan] = m_driver[chan].logic_vector_array_export;
                m_channel_binder.meta_in_export[chan] = m_driver[chan].logic_vector_export;
                m_channel_binder.sdp_in_export[chan]  = m_driver[chan].sdp_export;
            end
        end

        reset_sync.push_back(m_env_rx.reset_sync);
    endfunction

    virtual task run_phase(uvm_phase phase);
        if (m_config.active == UVM_ACTIVE) begin
            logic_vector_sequence#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH, CHANNELS) logic_vector_seq;
            logic_vector_array_sequence#(ITEM_WIDTH, CHANNELS)                      logic_vector_array_seq;

            logic_vector_array_seq = logic_vector_array_sequence#(ITEM_WIDTH, CHANNELS)::type_id::create("logic_vector_array_seq", this);
            logic_vector_seq       = logic_vector_sequence#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH, CHANNELS)::type_id::create("logic_vector_seq", this);

            logic_vector_seq.tr_export            = m_channel_binder.meta_out_export;
            logic_vector_array_seq.tr_export      = m_channel_binder.data_out_export;
            logic_vector_array_seq.m_watch_dog    = m_watch_dog;
            logic_vector_array_seq.tr_sdp_export  = m_channel_binder.sdp_out_export;
            logic_vector_array_seq.channel_export = m_channel_binder.chan_out_export;

            logic_vector_array_seq.regmodel_set(m_regmodel);
            m_channel_binder.m_watch_dog = m_watch_dog;
            for (int unsigned chan = 0; chan < CHANNELS; chan++) begin
                m_driver[chan].regmodel_set(m_regmodel);
                m_driver[chan].m_watch_dog = m_watch_dog;
            end

            logic_vector_seq.randomize();
            logic_vector_array_seq.randomize();

            fork
                logic_vector_seq.start(m_env_rx.m_sequencer.m_meta);
                logic_vector_array_seq.start(m_env_rx.m_sequencer.m_data);
            join
        end

    endtask
endclass

