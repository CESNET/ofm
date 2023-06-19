// test.sv: Verification test
// Copyright (C) 2023 CESNET z. s. p. o.
// Author(s): Tomas Hak <xhakto01@vut.cz>

// SPDX-License-Identifier: BSD-3-Clause

class ex_test extends uvm_test;
    `uvm_component_utils(test::ex_test)

    uvm_rate_limiter::env#(MI_DATA_WIDTH, MI_ADDR_WIDTH, MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH, INTERVAL_COUNT, CLK_PERIOD) m_env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        uvm_logic_vector_array_mfb::sequence_lib_rx#(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH)::type_id::set_inst_override(test::sequence_lib_rx#(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH)::get_type(), {this.get_full_name(), ".m_env.m_env_rx.*"});
        m_env = uvm_rate_limiter::env#(MI_DATA_WIDTH, MI_ADDR_WIDTH, MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH, INTERVAL_COUNT, CLK_PERIOD)::type_id::create("m_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        test::virt_seq#(SECTION_LENGTH, INTERVAL_LENGTH, INTERVAL_COUNT, OUTPUT_SPEED, MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH) m_vseq;
        m_vseq = test::virt_seq#(SECTION_LENGTH, INTERVAL_LENGTH, INTERVAL_COUNT, OUTPUT_SPEED, MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH)::type_id::create("m_vseq");
        m_vseq.regmodel_set(m_env.m_regmodel.m_regmodel);
        m_vseq.init();

        phase.raise_objection(this);

        void'(m_vseq.randomize());
        m_vseq.start(m_env.m_sequencer);

        phase.drop_objection(this);
    endtask
endclass
