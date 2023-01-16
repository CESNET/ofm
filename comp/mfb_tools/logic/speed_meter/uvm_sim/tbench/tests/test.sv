//-- test.sv: Verification test 
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author:   Daniel Kříž <xkrizd01@vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

class mfb_rx_rand#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH) extends uvm_logic_vector_array_mfb::sequence_lib_rx#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, 0);
  `uvm_object_param_utils(test::mfb_rx_rand#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH))
  `uvm_sequence_library_utils(test::mfb_rx_rand#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH))

    function new(string name = "mfb_rx_rand");
        super.new(name);
        init_sequence_library();
    endfunction

    virtual function void init_sequence(uvm_logic_vector_array_mfb::config_sequence param_cfg = null);
        if (param_cfg == null) begin
            this.cfg = new();
        end else begin
            this.cfg = param_cfg;
        end
        this.add_sequence(uvm_logic_vector_array_mfb::sequence_simple_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, 0)::get_type());
    endfunction
endclass

class ex_test extends uvm_test;
    `uvm_component_utils(test::ex_test);

    bit timeout;
    uvm_speed_meter::env #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, MI_DATA_WIDTH, MI_ADDRESS_WIDTH, SPACE_SIZE_MIN_RX, SPACE_SIZE_MAX_RX, SPACE_SIZE_MIN_TX, SPACE_SIZE_MAX_TX) m_env;

    // ------------------------------------------------------------------------
    // Functions
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        uvm_logic_vector_array_mfb::sequence_lib_rx#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, 0)::type_id::set_inst_override(mfb_rx_rand#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH)::get_type(),
        {this.get_full_name(), ".m_env.rx_env.*"});
        m_env = uvm_speed_meter::env #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, MI_DATA_WIDTH, MI_ADDRESS_WIDTH, SPACE_SIZE_MIN_RX, SPACE_SIZE_MAX_RX, SPACE_SIZE_MIN_TX, SPACE_SIZE_MAX_TX)::type_id::create("m_env", this);
    endfunction

    task test_wait_timeout(int unsigned time_length);
        #(time_length*1us);
    endtask

    // ------------------------------------------------------------------------
    // Create environment and Run sequences o their sequencers
    task run_seq_rx(uvm_phase phase);
        virt_sequence#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, MI_DATA_WIDTH, MI_ADDRESS_WIDTH, CLK_PERIOD) m_vseq;

        phase.raise_objection(this, "Start of rx sequence");

        m_vseq = virt_sequence#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, MI_DATA_WIDTH, MI_ADDRESS_WIDTH, CLK_PERIOD)::type_id::create("m_vseq");
        m_vseq.init(phase);
        assert(m_vseq.randomize());
        m_vseq.start(m_env.vscr);

        phase.drop_objection(this, "End of rx sequence");
    endtask

    virtual task run_phase(uvm_phase phase);

        run_seq_rx(phase);

    endtask

endclass
