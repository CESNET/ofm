// sequence.sv: Virtual sequence
// Copyright (C) 2023-2024 CESNET z. s. p. o.
// Author(s): Oliver Gurka <xgurka00@stud.fit.vutbr.cz>
//            Vladislav Valek <valekv@cesnet.cz>

// SPDX-License-Identifier: BSD-3-Clause


class virt_sequence#(ITEM_WIDTH, TX_PORTS) extends uvm_sequence;
    `uvm_object_param_utils(test::virt_sequence#(ITEM_WIDTH, TX_PORTS))
    `uvm_declare_p_sequencer(uvm_mvb_demux::virt_sequencer#(ITEM_WIDTH, TX_PORTS))

    function new (string name = "virt_sequence");
        super.new(name);
    endfunction

    uvm_reset::sequence_start                      m_reset;
    uvm_logic_vector::sequence_simple#(ITEM_WIDTH + $clog2(TX_PORTS)) m_logic_vector_sq;

    virtual function void init();

        m_reset           = uvm_reset::sequence_start::type_id::create("m_reset");
        m_logic_vector_sq = uvm_logic_vector::sequence_simple#(ITEM_WIDTH + $clog2(TX_PORTS))::type_id::create("m_logic_vector_sq");

    endfunction

    virtual task run_reset();

        m_reset.randomize();
        m_reset.start(p_sequencer.m_reset);

    endtask

    task body();

        init();

        #(10ns)

        run_mfb();

    endtask

    virtual task run_mfb();
        m_logic_vector_sq.randomize();
        m_logic_vector_sq.start(p_sequencer.m_logic_vector_scr);
    endtask

endclass
