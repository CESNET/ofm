// sequence.sv: Virtual sequence
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kriz <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


class virt_sequence#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, MI_DATA_WIDTH, MI_ADDRESS_WIDTH, CLK_PERIOD) extends uvm_sequence;
    `uvm_object_param_utils(test::virt_sequence#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, MI_DATA_WIDTH, MI_ADDRESS_WIDTH, CLK_PERIOD))
    `uvm_declare_p_sequencer(uvm_speed_meter::virt_sequencer#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, MI_DATA_WIDTH, MI_ADDRESS_WIDTH))

    function new (string name = "virt_sequence");
        super.new(name);
    endfunction

    uvm_reset::sequence_start                                                  m_reset;
    uvm_speed_meter::sequence_mfb_data#(ITEM_WIDTH)                            m_logic_vector_arr_sq;
    // uvm_logic_vector_array::sequence_lib#(ITEM_WIDTH)                       m_logic_vector_arr_sq;
    uvm_speed_meter::sequence_mi#(MI_DATA_WIDTH, MI_ADDRESS_WIDTH, CLK_PERIOD) m_mi_sq;
    uvm_mfb::sequence_lib_tx#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, 0) h_seq_tx;
    uvm_phase phase;

    virtual function void init(uvm_phase phase);

        m_reset               = uvm_reset::sequence_start::type_id::create("m_reset");
        m_logic_vector_arr_sq = uvm_speed_meter::sequence_mfb_data#(ITEM_WIDTH)::type_id::create("m_logic_vector_arr_sq");
        // m_logic_vector_arr_sq = uvm_logic_vector_array::sequence_lib#(ITEM_WIDTH)::type_id::create("m_logic_vector_arr_sq");
        m_mi_sq               = uvm_speed_meter::sequence_mi#(MI_DATA_WIDTH, MI_ADDRESS_WIDTH, CLK_PERIOD)::type_id::create("m_mi_sq");
        h_seq_tx              = uvm_mfb::sequence_lib_tx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, 0)::type_id::create("h_seq_tx");

        // m_logic_vector_arr_sq.init_sequence();
        // m_logic_vector_arr_sq.min_random_count = 50;
        // m_logic_vector_arr_sq.max_random_count = 70;

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

        // init();

        fork
            run_reset();
        join_none

        #(200ns)

        fork
            run_seq_tx(phase);
        join_none

        fork
            run_mfb();
            m_mi_sq.randomize();
            m_mi_sq.start(p_sequencer.m_mi_sqr);
        join
        #(200ns);

    endtask

    virtual task run_mfb();
        m_logic_vector_arr_sq.randomize();
        m_logic_vector_arr_sq.start(p_sequencer.m_logic_vector_array_scr);
    endtask

endclass
