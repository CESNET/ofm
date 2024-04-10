// sequence.sv: Virtual sequence
// Copyright (C) 2024 CESNET z. s. p. o.
// Author(s): David Beneš <xbenes52@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


class virt_sequence#(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MVB_ITEM_WIDTH, RX_CHANNELS, FRAME_SIZE_MIN, FRAME_SIZE_MAX) extends uvm_sequence;
    `uvm_object_param_utils(test::virt_sequence#(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MVB_ITEM_WIDTH, RX_CHANNELS, FRAME_SIZE_MIN, FRAME_SIZE_MAX))
    `uvm_declare_p_sequencer(uvm_framepacker::virt_sequencer#(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MVB_ITEM_WIDTH, USR_RX_PKT_SIZE_MAX, RX_CHANNELS, HDR_META_WIDTH))

    function new (string name = "virt_sequence");
        super.new(name);
    endfunction

    //RX 
    uvm_reset::sequence_start                             m_reset;
    uvm_logic_vector_array::sequence_lib#(MFB_ITEM_WIDTH) m_mfb_data_seq;
    uvm_framepacker::sequence_mvb_data#(MVB_ITEM_WIDTH)   m_mvb_data_seq;

    //TX DST_RDY handle
    uvm_meta::sequence_lib #(USR_RX_PKT_SIZE_MAX, RX_CHANNELS, HDR_META_WIDTH)                 m_info_seq;
    uvm_mfb::sequence_lib_tx#(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, 0) m_mfb_tx_seq;
    uvm_mvb::sequence_lib_tx#(MFB_REGIONS, MVB_ITEM_WIDTH)                                     m_mvb_tx_seq;

    uvm_sequence#(uvm_mfb::sequence_item#(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, 0)) m_mfb_rdy_seq;
    uvm_sequence#(uvm_mvb::sequence_item#(MFB_REGIONS, MVB_ITEM_WIDTH))                                     m_mvb_rdy_seq;

    uvm_phase phase;

    virtual function void init(uvm_phase phase);

        m_reset         = uvm_reset::sequence_start::type_id::create("m_reset");
        m_mfb_data_seq  = uvm_logic_vector_array::sequence_lib#(MFB_ITEM_WIDTH)::type_id::create("m_mfb_data_seq");
        m_mfb_tx_seq    = uvm_mfb::sequence_lib_tx #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, 0)::type_id::create("m_mfb_tx_seq");
        m_mvb_tx_seq    = uvm_mvb::sequence_lib_tx #(MFB_REGIONS, MVB_ITEM_WIDTH)::type_id::create("m_mvb_tx_seq");

        m_info_seq      = uvm_meta::sequence_lib #(USR_RX_PKT_SIZE_MAX, RX_CHANNELS, HDR_META_WIDTH)::type_id::create("m_info_seq");

        m_mfb_tx_seq.init_sequence();
        m_mfb_tx_seq.min_random_count = 2000;
        m_mfb_tx_seq.max_random_count = 5000;
        m_mfb_rdy_seq = m_mfb_tx_seq;

        m_mfb_data_seq.init_sequence();
        m_mfb_data_seq.cfg = new();
        m_mfb_data_seq.cfg.array_size_set(FRAME_SIZE_MIN, FRAME_SIZE_MAX);
        m_mfb_data_seq.min_random_count = 100;
        m_mfb_data_seq.max_random_count = 200;


        m_info_seq.init_sequence();
        m_info_seq.min_random_count = 200000;
        m_info_seq.max_random_count = 500000;

        m_mvb_tx_seq.init_sequence();
        m_mvb_tx_seq.min_random_count = 200000;
        m_mvb_tx_seq.max_random_count = 500000;
        m_mvb_rdy_seq = m_mvb_tx_seq;
        
        this.phase = phase;

    endfunction

    task run_mfb_seq_tx();
        forever begin
            m_mfb_rdy_seq.randomize();
            m_mfb_rdy_seq.start(p_sequencer.m_mfb_tx_sqr);
        end
    endtask

    task run_mvb_seq_tx();
        forever begin
            m_mvb_rdy_seq.randomize();
            m_mvb_rdy_seq.start(p_sequencer.m_mvb_tx_sqr);
        end
    endtask

    virtual task run_reset();

        m_reset.randomize();
        m_reset.start(p_sequencer.m_reset);

    endtask

    task body();

        // init();

        fork
            run_reset();
        join_none

        #(200ns)

        fork
            run_mfb_seq_tx();
            run_mvb_seq_tx();
        join_none

        fork
            begin
                m_mfb_data_seq.randomize();
                m_mfb_data_seq.start(p_sequencer.m_mfb_data_sqr);
            end
            begin
                m_info_seq.randomize();
                m_info_seq.start(p_sequencer.m_info);
            end
        join_any


    endtask
endclass
