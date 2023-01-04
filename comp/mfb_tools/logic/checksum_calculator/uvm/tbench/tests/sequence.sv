// sequence.sv: Virtual sequence
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


class virt_sequence #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, META_WIDTH, MVB_DATA_WIDTH) extends uvm_sequence;
    `uvm_object_param_utils(test::virt_sequence #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, META_WIDTH, MVB_DATA_WIDTH))
    `uvm_declare_p_sequencer(uvm_checksum_calculator::virt_sequencer #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, META_WIDTH, MVB_DATA_WIDTH))

    function new (string name = "virt_sequence");
        super.new(name);
    endfunction

    uvm_logic_vector_array::sequence_lib #(MFB_ITEM_WIDTH) m_byte_array_sq_lib;
    uvm_header_type::sequence_lib                          m_info_lib;

    virtual function void init();

        m_info_lib          = uvm_header_type::sequence_lib::type_id::create("m_info_lib");
        m_byte_array_sq_lib = uvm_logic_vector_array::sequence_lib #(MFB_ITEM_WIDTH)::type_id::create("m_byte_array_seq_lib");

        m_byte_array_sq_lib.init_sequence();
        m_byte_array_sq_lib.min_random_count = 100;
        m_byte_array_sq_lib.max_random_count = 200;

        m_info_lib.init_sequence();
        m_info_lib.min_random_count = 100;
        m_info_lib.max_random_count = 200;
        m_info_lib.randomize();

    endfunction

    virtual task run_mfb();
        //RUN RX Sequencer
        m_byte_array_sq_lib.randomize();
        m_byte_array_sq_lib.start(p_sequencer.m_byte_array_scr);
    endtask

    task body();

        init();

        fork
            run_mfb();
            forever begin
                m_info_lib.start(p_sequencer.m_info);
            end
        join_any

    endtask

endclass
