//-- sequence.sv:  virtual sequence
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

class virt_seq#(USR_REGIONS, USR_REGION_SIZE, USR_BLOCK_SIZE, USR_ITEM_WIDTH, CQ_ITEM_WIDTH, CHANNELS, PKT_SIZE_MAX, PCIE_LEN_MIN, PCIE_LEN_MAX) extends uvm_sequence;
    `uvm_object_param_utils(test::virt_seq#(USR_REGIONS, USR_REGION_SIZE, USR_BLOCK_SIZE, USR_ITEM_WIDTH, CQ_ITEM_WIDTH, CHANNELS, PKT_SIZE_MAX, PCIE_LEN_MIN, PCIE_LEN_MAX))
    `uvm_declare_p_sequencer(uvm_dma_ll::sequencer#(USR_REGIONS, USR_REGION_SIZE, USR_BLOCK_SIZE, USR_ITEM_WIDTH, CQ_ITEM_WIDTH, CHANNELS, PKT_SIZE_MAX))

    function new (string name = "virt_seq");
        super.new(name);
    endfunction

    localparam USER_META_WIDTH = 24 + $clog2(PKT_SIZE_MAX+1) + $clog2(CHANNELS);

    uvm_reset::sequence_start              m_reset;

    uvm_logic_vector_array::sequence_lib#(CQ_ITEM_WIDTH) m_packet;
    uvm_dma_ll_info::sequence_lib#(CHANNELS)  m_info;

    uvm_dma_ll::reg_sequence#(CHANNELS)     m_reg;
    uvm_sequence#(uvm_mfb::sequence_item #(USR_REGIONS, USR_REGION_SIZE, USR_BLOCK_SIZE, USR_ITEM_WIDTH, USER_META_WIDTH)) m_pcie[CHANNELS];
    uvm_mfb::sequence_lib_tx#(USR_REGIONS, USR_REGION_SIZE, USR_BLOCK_SIZE, USR_ITEM_WIDTH, USER_META_WIDTH) m_pcie_lib[CHANNELS];
    uvm_dma_size::sequence_lib #(1, PKT_SIZE_MAX/4) m_size_lib[CHANNELS];
    uvm_phase phase;

    virtual function void init(uvm_dma_ll::regmodel#(CHANNELS) m_regmodel, uvm_phase phase);

        m_reset = uvm_reset::sequence_start::type_id::create("rst_seq");

        m_packet = uvm_logic_vector_array::sequence_lib#(CQ_ITEM_WIDTH)::type_id::create("m_packet");
        m_packet.init_sequence();
        m_packet.cfg = new();
        m_packet.cfg.array_size_set(PCIE_LEN_MIN, PCIE_LEN_MAX);
        m_packet.min_random_count = 300;
        m_packet.max_random_count = 1000;
        // m_packet.min_random_count = 2000;
        // m_packet.max_random_count = 3000;

        m_info = uvm_dma_ll_info::sequence_lib#(CHANNELS)::type_id::create("m_info");
        m_info.init_sequence();
        m_info.min_random_count = 150;
        m_info.max_random_count = 200;

        m_reg            = uvm_dma_ll::reg_sequence#(CHANNELS)::type_id::create("m_reg");
        m_reg.m_regmodel = m_regmodel;

        for (int chan = 0; chan < CHANNELS; chan++) begin
            m_pcie_lib[chan]  = uvm_mfb::sequence_lib_tx#(USR_REGIONS, USR_REGION_SIZE, USR_BLOCK_SIZE, USR_ITEM_WIDTH, USER_META_WIDTH)::type_id::create($sformatf("m_pcie_lib%0d", chan));
            m_pcie_lib[chan].init_sequence();
            m_pcie[chan] = m_pcie_lib[chan];

            m_size_lib[chan]  = uvm_dma_size::sequence_lib#(1, PKT_SIZE_MAX/4)::type_id::create($sformatf("m_size_lib%0d", chan));
            m_size_lib[chan].init_sequence();
        end
        this.phase = phase;
    endfunction

    virtual task run_mfb(int unsigned index);
        forever begin
            assert(m_pcie[index].randomize());
            m_pcie[index].start(p_sequencer.m_pcie[index]);
        end
    endtask

    virtual task run_size(int unsigned index);
        forever begin
            assert(m_size_lib[index].randomize());
            m_size_lib[index].start(p_sequencer.m_packet.m_size[index]);
        end
    endtask

    virtual task run_reset();
        m_reset.randomize();
        m_reset.start(p_sequencer.m_reset);
    endtask

    function void pre_randomize();
         m_packet.randomize();
         m_reg.randomize();
    endfunction

    task body();
        fork
            run_reset();
            begin
                #(200ns)
                m_reg.start(null);
            end
        join_none

        for (int chan = 0; chan < CHANNELS; chan++) begin
            fork
                automatic int index = chan;
                run_mfb(index);
            join_none
        end

        for (int chan = 0; chan < CHANNELS; chan++) begin
            fork
                automatic int index = chan;
                run_size(index);
            join_none
        end

        fork
            m_packet.start(p_sequencer.m_packet.m_data);
            forever begin
                m_info.randomize();
                m_info.start(p_sequencer.m_packet.m_info);
            end
        join_any

    endtask
endclass
