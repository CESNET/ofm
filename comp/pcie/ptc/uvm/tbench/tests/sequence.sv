//-- sequence.sv: Virtual sequence
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

class virt_seq #(MRRS, MPS, ONLY_READ) extends uvm_sequence;

    `uvm_object_utils(test::virt_seq #(MRRS, MPS, ONLY_READ))
    `uvm_declare_p_sequencer(uvm_dma_up::sequencer);

    function new (string name = "virt_seq");
        super.new(name);
    endfunction

    uvm_ptc_info::sequence_lib_info #(MRRS, ONLY_READ) m_info;
    //uvm_reset::sequence_reset     m_reset;
    uvm_logic_vector_array::sequence_lib#(32)  m_packet;

    virtual function void init();
        //m_reset = uvm_reset::sequence_reset::type_id::create("rst_seq");

        m_packet = uvm_logic_vector_array::sequence_lib#(32)::type_id::create("m_packet");
        m_packet.init_sequence();
        m_packet.cfg = new();
        m_packet.cfg.array_size_set(2, MPS);
        m_packet.min_random_count = 60;
        m_packet.max_random_count = 80;

        m_info   = uvm_ptc_info::sequence_lib_info #(MRRS, ONLY_READ)::type_id::create("m_info");
        m_info.init_sequence();
        m_info.min_random_count = 60;
        m_info.max_random_count = 80;
    endfunction

    //virtual task run_reset();
    //    m_reset.randomize();
    //    m_reset.start(p_sequencer.m_reset);
    //endtask

    function void pre_randomize();
        init();
        m_packet.randomize();
    endfunction

    task body();
        //fork
        //    run_reset();
        //join_none

        fork
            m_packet.start(p_sequencer.m_data);
            forever begin
                m_info.start(p_sequencer.m_info);
            end
        join_any
    endtask
endclass
