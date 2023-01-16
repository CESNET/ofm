// sequence.sv: Virtual sequence
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kriz <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


class virt_sequence#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH, EXTENDED_META_WIDTH) extends uvm_sequence;
    `uvm_object_param_utils(test::virt_sequence#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH, EXTENDED_META_WIDTH))
    `uvm_declare_p_sequencer(uvm_dropper::virt_sequencer#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH, EXTENDED_META_WIDTH))

    function new (string name = "virt_sequence");
        super.new(name);
    endfunction

    uvm_reset::sequence_start                                                           m_reset;
    uvm_dropper::sequence_mfb_data#(ITEM_WIDTH)                                         m_logic_vector_arr_sq;
    uvm_dropper::sequence_meta#(META_WIDTH, EXTENDED_META_WIDTH)                                    m_meta_sq;
    uvm_mfb::sequence_lib_tx#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) h_seq_tx;
    uvm_phase phase;

    virtual function void init(uvm_phase phase);

        m_reset               = uvm_reset::sequence_start::type_id::create("m_reset");
        m_logic_vector_arr_sq = uvm_dropper::sequence_mfb_data#(ITEM_WIDTH)::type_id::create("m_logic_vector_arr_sq");
        m_meta_sq             = uvm_dropper::sequence_meta#(META_WIDTH, EXTENDED_META_WIDTH)::type_id::create("m_meta_sq");
        h_seq_tx              = uvm_mfb::sequence_lib_tx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH)::type_id::create("h_seq_tx");

        h_seq_tx.init_sequence();
        h_seq_tx.cfg = new();
        h_seq_tx.cfg.probability_set(60, 100);
        h_seq_tx.min_random_count = 200;
        h_seq_tx.max_random_count = 500;
        this.phase = phase;

    endfunction

    task run_seq_tx(uvm_phase phase);
        forever begin
            h_seq_tx.randomize();
            h_seq_tx.start(p_sequencer.m_tx_sqr);
        end
    endtask

    virtual task run_reset();

        m_reset.randomize();
        m_reset.start(p_sequencer.m_reset);

    endtask

    task body();

        fork
            run_reset();
        join_none

        #(200ns)

        fork
            run_seq_tx(phase);
        join_none

        fork
            run_mfb();
            m_meta_sq.randomize();
            m_meta_sq.start(p_sequencer.m_meta_sqr);
        join
        #(200ns);

    endtask

    virtual task run_mfb();
        m_logic_vector_arr_sq.randomize();
        m_logic_vector_arr_sq.start(p_sequencer.m_logic_vector_array_scr);
    endtask

endclass
