//-- sequence.sv:  virtual sequence
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

class virt_seq#(USR_REGIONS, USR_REGION_SIZE, USR_BLOCK_SIZE, USR_ITEM_WIDTH, CHANNELS, PKT_SIZE_MAX, PCIE_LEN_MIN, PCIE_LEN_MAX) extends uvm_sequence;
    `uvm_object_param_utils(test::virt_seq#(USR_REGIONS, USR_REGION_SIZE, USR_BLOCK_SIZE, USR_ITEM_WIDTH, CHANNELS, PKT_SIZE_MAX, PCIE_LEN_MIN, PCIE_LEN_MAX))
    `uvm_declare_p_sequencer(uvm_dma_ll::sequencer#(USR_REGIONS, USR_REGION_SIZE, USR_BLOCK_SIZE, USR_ITEM_WIDTH, CHANNELS, PKT_SIZE_MAX))

    localparam USER_META_WIDTH = 24 + $clog2(PKT_SIZE_MAX+1) + $clog2(CHANNELS);

    uvm_reset::sequence_start                            m_reset;

    //reg_sequence#(CQ_ITEM_WIDTH, PKT_SIZE_MAX, PCIE_LEN_MIN)                                                               m_reg;
    uvm_dma_ll::sequence_simple                                                                                            m_channel[CHANNELS];
    uvm_sequence#(uvm_mfb::sequence_item #(USR_REGIONS, USR_REGION_SIZE, USR_BLOCK_SIZE, USR_ITEM_WIDTH, USER_META_WIDTH)) m_pcie;
    logic [CHANNELS-1:0] done;

    function new (string name = "virt_seq");
        super.new(name);
    endfunction

    virtual function void init();
        uvm_mfb::sequence_lib_tx#(USR_REGIONS, USR_REGION_SIZE, USR_BLOCK_SIZE, USR_ITEM_WIDTH, USER_META_WIDTH)               m_pcie_lib;

        m_reset = uvm_reset::sequence_start::type_id::create("rst_seq");

        for (int unsigned it = 0; it < CHANNELS; it++) begin
            m_channel[it] = uvm_dma_ll::sequence_simple::type_id::create($sformatf("channel_%0d", it));
        end

        m_pcie_lib = uvm_mfb::sequence_lib_tx#(USR_REGIONS, USR_REGION_SIZE, USR_BLOCK_SIZE, USR_ITEM_WIDTH, USER_META_WIDTH)::type_id::create("m_pcie_lib");
        m_pcie_lib.init_sequence();
        m_pcie = m_pcie_lib;
    endfunction

    virtual task run_mfb();
        forever begin
            assert(m_pcie.randomize());
            m_pcie.start(p_sequencer.m_pcie);
        end
    endtask

    virtual task run_reset();
        m_reset.randomize();
        m_reset.start(p_sequencer.m_reset);
    endtask

    virtual task run_channels();
        #(200ns);

        for (int unsigned it = 0; it < CHANNELS; it++) begin
            fork
                automatic int unsigned index = it;
                begin
                    m_channel[index].randomize();
                    m_channel[index].start(p_sequencer.m_packet[index]);
                    done[index] = 1;
                end
            join_none
        end
    endtask


    task body();
        done = 0;


        fork
            run_reset();
            run_channels();
        join_none

        #(200ns);

        fork
            run_mfb();
        join_none

        wait((& done) == 1);

    endtask
endclass
