//-- test.sv: Verification test
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Radek Iša <isa@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause


class virt_seq_full_speed#(PCIE_UP_REGIONS, PCIE_UP_REGION_SIZE, PCIE_UP_BLOCK_SIZE, PCIE_UP_ITEM_WIDTH, PCIE_UP_META_WIDTH, CHANNELS) extends virt_seq#(PCIE_UP_REGIONS, PCIE_UP_REGION_SIZE, PCIE_UP_BLOCK_SIZE, PCIE_UP_ITEM_WIDTH, PCIE_UP_META_WIDTH, CHANNELS);
    `uvm_object_param_utils(test::virt_seq_full_speed#(PCIE_UP_REGIONS, PCIE_UP_REGION_SIZE, PCIE_UP_BLOCK_SIZE, PCIE_UP_ITEM_WIDTH, PCIE_UP_META_WIDTH, CHANNELS))
    `uvm_declare_p_sequencer(uvm_dma_ll::sequencer#(PCIE_UP_REGIONS, PCIE_UP_REGION_SIZE, PCIE_UP_BLOCK_SIZE, PCIE_UP_ITEM_WIDTH, PCIE_UP_META_WIDTH, CHANNELS))

    function new (string name = "virt_seq_full_speed");
        super.new(name);
    endfunction

    virtual function void init(uvm_dma_ll::regmodel#(CHANNELS) m_regmodel);
        super.init(m_regmodel);
        m_pcie = uvm_mfb::sequence_full_speed_tx#(PCIE_UP_REGIONS, PCIE_UP_REGION_SIZE, PCIE_UP_BLOCK_SIZE, PCIE_UP_ITEM_WIDTH, PCIE_UP_META_WIDTH)::type_id::create();
    endfunction
endclass

class mfb_rx_speed#(REGIONS, REGION_SIZE, BLOCK_SIZE, META_WIDTH) extends uvm_byte_array_mfb::sequence_lib_rx#(REGIONS, REGION_SIZE, BLOCK_SIZE, META_WIDTH);
  `uvm_object_param_utils(    test::mfb_rx_speed#(REGIONS, REGION_SIZE, BLOCK_SIZE,  META_WIDTH))
  `uvm_sequence_library_utils(test::mfb_rx_speed#(REGIONS, REGION_SIZE, BLOCK_SIZE,  META_WIDTH))

    function new(string name = "mfb_rx_speed");
        super.new(name);
        init_sequence_library();
    endfunction

    virtual function void init_sequence(uvm_byte_array_mfb::config_sequence param_cfg = null);
        super.init_sequence(param_cfg);
        this.add_sequence(uvm_byte_array_mfb::sequence_full_speed_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, META_WIDTH)::get_type());
        //this.add_sequence(byte_array_mfb_env::sequence_stop_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH)::get_type());
    endfunction
endclass


class speed#(USER_REGIONS, USER_REGION_SIZE, USER_BLOCK_SIZE, USER_ITEM_WIDTH, PCIE_UP_REGIONS, PCIE_UP_REGION_SIZE, PCIE_UP_BLOCK_SIZE, PCIE_UP_ITEM_WIDTH, PCIE_UP_META_WIDTH, CHANNELS, PKT_SIZE_MAX, MI_WIDTH, DEVICE) extends base#(USER_REGIONS, USER_REGION_SIZE, USER_BLOCK_SIZE, USER_ITEM_WIDTH, PCIE_UP_REGIONS, PCIE_UP_REGION_SIZE, PCIE_UP_BLOCK_SIZE, PCIE_UP_ITEM_WIDTH, PCIE_UP_META_WIDTH, CHANNELS, PKT_SIZE_MAX, MI_WIDTH, DEVICE);
    typedef uvm_component_registry#(test::speed#(USER_REGIONS, USER_REGION_SIZE, USER_BLOCK_SIZE, USER_ITEM_WIDTH, PCIE_UP_REGIONS, PCIE_UP_REGION_SIZE, PCIE_UP_BLOCK_SIZE, PCIE_UP_ITEM_WIDTH, PCIE_UP_META_WIDTH, CHANNELS, PKT_SIZE_MAX, MI_WIDTH, DEVICE), "test::speed") type_id;


    uvm_dma_ll::env #(USER_REGIONS, USER_REGION_SIZE, USER_BLOCK_SIZE, USER_ITEM_WIDTH, PCIE_UP_REGIONS, PCIE_UP_REGION_SIZE, PCIE_UP_BLOCK_SIZE, PCIE_UP_ITEM_WIDTH, PCIE_UP_META_WIDTH, CHANNELS, PKT_SIZE_MAX, MI_WIDTH, DEVICE) m_env;
    localparam USER_META_WIDTH = 24 + $clog2(PKT_SIZE_MAX+1) + $clog2(CHANNELS);

    // ------------------------------------------------------------------------
    // Functions
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    static function type_id get_type();
        return type_id::get();
    endfunction

    function string get_type_name();
        return get_type().get_type_name();
    endfunction

    function void build_phase(uvm_phase phase);
        uvm_byte_array_mfb::sequence_lib_rx#(USER_REGIONS, USER_REGION_SIZE, USER_BLOCK_SIZE, USER_META_WIDTH)::type_id::set_inst_override(mfb_rx_speed#(USER_REGIONS, USER_REGION_SIZE, USER_BLOCK_SIZE, USER_META_WIDTH)::get_type(),
            {this.get_full_name(), ".m_env.m_env_rx.*"});

        m_env = uvm_dma_ll::env #(USER_REGIONS, USER_REGION_SIZE, USER_BLOCK_SIZE, USER_ITEM_WIDTH, PCIE_UP_REGIONS, PCIE_UP_REGION_SIZE, PCIE_UP_BLOCK_SIZE, PCIE_UP_ITEM_WIDTH, PCIE_UP_META_WIDTH, CHANNELS, PKT_SIZE_MAX, MI_WIDTH, DEVICE)::type_id::create("m_env", this);
    endfunction

    // ------------------------------------------------------------------------
    // Create environment and Run sequences o their sequencers
    virtual task run_phase(uvm_phase phase);
        virt_seq_full_speed#(PCIE_UP_REGIONS, PCIE_UP_REGION_SIZE, PCIE_UP_BLOCK_SIZE, PCIE_UP_ITEM_WIDTH, PCIE_UP_META_WIDTH, CHANNELS) m_vseq;

        //CREATE SEQUENCES
        m_vseq = virt_seq_full_speed#(PCIE_UP_REGIONS, PCIE_UP_REGION_SIZE, PCIE_UP_BLOCK_SIZE, PCIE_UP_ITEM_WIDTH, PCIE_UP_META_WIDTH, CHANNELS)::type_id::create("m_vseq");

        //RISE OBJECTION
        phase.raise_objection(this);

        m_vseq.init(m_env.m_regmodel.m_regmodel);
        m_vseq.randomize();
        m_vseq.start(m_env.m_sequencer);

        #(1000ns)
        phase.drop_objection(this);
    endtask
endclass
