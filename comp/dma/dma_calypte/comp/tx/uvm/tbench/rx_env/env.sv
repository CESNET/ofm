//-- env.sv
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

class env #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, CHANNELS, PCIE_MTU, DATA_ADDR_W, DEVICE) extends uvm_env;
    `uvm_component_param_utils(uvm_dma_ll_rx::env #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, CHANNELS, PCIE_MTU, DATA_ADDR_W, DEVICE));

    sequencer                                                         m_sequencer[CHANNELS];
    driver #(CHANNELS, PCIE_MTU, ITEM_WIDTH, DATA_ADDR_W, DEVICE) m_driver[CHANNELS];
    //low level

    //implement later
    uvm_reset::sync_cbs reset_sync;
    uvm_logic_vector_array_mfb::env_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, sv_pcie_meta_pack::PCIE_CQ_META_WIDTH) m_env_rx;

    local driver_sync#(ITEM_WIDTH, sv_pcie_meta_pack::PCIE_CQ_META_WIDTH) data_export;
    local uvm_dma_regs::regmodel #(CHANNELS)                              m_regmodel;
    local config_item m_config;

    // Constructor of environment.
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void regmodel_set(uvm_dma_regs::regmodel#(CHANNELS) m_regmodel);
        this.m_regmodel = m_regmodel;
        for (int unsigned it = 0; it < CHANNELS; it++) begin
            m_sequencer[it].regmodel_set(m_regmodel.channel[it]);
            m_driver[it]   .regmodel_set(m_regmodel.channel[it]);
        end
    endfunction

    // Create base components of environment.
    function void build_phase(uvm_phase phase);
        uvm_logic_vector_array_mfb::config_item m_env_rx_cfg;

        if(!uvm_config_db #(config_item)::get(this, "", "m_config", m_config)) begin
            `uvm_fatal(this.get_full_name(), "Unable to get configuration object")
        end

        // LOW level agent
        m_env_rx_cfg                = new;
        m_env_rx_cfg.active         = m_config.active;
        m_env_rx_cfg.seq_type       = "PCIE";
        m_env_rx_cfg.interface_name = m_config.interface_name;
        m_env_rx_cfg.meta_behav     = uvm_logic_vector_array_mfb::config_item::META_SOF;

        uvm_config_db #(uvm_logic_vector_array_mfb::config_item)::set(this, "m_env_rx", "m_config", m_env_rx_cfg);
        m_env_rx  = uvm_logic_vector_array_mfb::env_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)::type_id::create("m_env_rx", this);

        for (int unsigned chan = 0; chan < CHANNELS; chan++) begin
            string i_string = $sformatf("%0d", chan);

            if (m_config.active == UVM_ACTIVE) begin
                m_sequencer[chan] = sequencer::type_id::create({"m_sequencer_", i_string}, this);
                m_driver[chan]    = driver#(CHANNELS, PCIE_MTU, ITEM_WIDTH, DATA_ADDR_W, DEVICE)::type_id::create({"m_driver_", i_string}, this);
                m_driver[chan].channel = chan;
            end else begin
                m_sequencer[chan] = null;
                m_driver[chan]    = null;
            end
        end
        reset_sync  = new();
        data_export = new();
    endfunction

    // Connect agent's ports with ports from scoreboard.
    function void connect_phase(uvm_phase phase);
        if (m_config.active == UVM_ACTIVE) begin

            for (int unsigned chan = 0; chan < CHANNELS; chan++) begin

                m_driver[chan].seq_item_port.connect(m_sequencer[chan].seq_item_export);
                m_driver[chan].data_export = data_export;
                //m_sequencer.m_data[chan] = m_logic_vector_array_agent[chan].m_sequencer;
                //reset_sync.push_back(m_driver[chan].reset_sync);
                reset_sync.push_back(m_sequencer[chan].reset_sync);
            end
        end

    endfunction

    virtual task run_phase(uvm_phase phase);
        if (m_config.active == UVM_ACTIVE) begin
            base_send_sequence#(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)) meta_seq;
            base_send_sequence#(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH))                      data_seq;

            meta_seq = base_send_sequence#(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH))::type_id::create("meta_seq", this);
            data_seq = base_send_sequence#(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH))                     ::type_id::create("data_seq", this);

            meta_seq.tr_export = data_export.pcie_meta;
            data_seq.tr_export = data_export.pcie_data;

            meta_seq.randomize();
            data_seq.randomize();

            fork
                meta_seq.start(m_env_rx.m_sequencer.m_meta);
                data_seq.start(m_env_rx.m_sequencer.m_data);
            join
        end
    endtask
endclass


