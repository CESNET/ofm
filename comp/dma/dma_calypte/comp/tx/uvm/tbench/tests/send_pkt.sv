//-- sequence.sv:  virtual sequence
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

class send_pkt_seq#(CQ_ITEM_WIDTH, PKT_SIZE_MAX, PCIE_LEN_MIN, MIN_CNT, MAX_CNT) extends uvm_sequence;
    `uvm_object_param_utils(test::send_pkt_seq#(CQ_ITEM_WIDTH, PKT_SIZE_MAX, PCIE_LEN_MIN, MIN_CNT, MAX_CNT))
    `uvm_declare_p_sequencer(uvm_logic_vector_array::sequencer#(CQ_ITEM_WIDTH))

    function new (string name = "send_pkt_seq");
        super.new(name);
    endfunction

    uvm_logic_vector_array::sequence_lib#(CQ_ITEM_WIDTH) m_packet_lib;

    uvm_phase phase;
    int unsigned channel;
    logic wait_trig = 1'b0;

    virtual function void init(uvm_phase phase);
        string it_num;
        it_num.itoa(channel);

        m_packet_lib = uvm_logic_vector_array::sequence_lib#(CQ_ITEM_WIDTH)::type_id::create({"m_packet_lib_%0d", channel});
        m_packet_lib.init_sequence();
        m_packet_lib.cfg = new();
        m_packet_lib.cfg.array_size_set(PCIE_LEN_MIN, PKT_SIZE_MAX/4);
        m_packet_lib.min_random_count = MIN_CNT;
        m_packet_lib.max_random_count = MAX_CNT;
        // m_packet_lib.min_random_count = 2000;
        // m_packet_lib.max_random_count = 3000;

        this.phase = phase;
    endfunction

    task body();
        if(!m_packet_lib.randomize()) `uvm_fatal(this.get_full_name(), "\n\tCannot randomize m_packet_lib");
        m_packet_lib.start(p_sequencer);
    endtask
endclass
