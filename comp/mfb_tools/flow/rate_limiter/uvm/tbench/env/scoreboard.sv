// scoreboard.sv: Scoreboard for verification
// Copyright (C) 2023 CESNET z. s. p. o.
// Author(s): Tomas Hak <xhakto01@vut.cz>

// SPDX-License-Identifier: BSD-3-Clause

class scoreboard#(MFB_ITEM_WIDTH, MFB_META_WIDTH, INTERVAL_COUNT, CLK_PERIOD) extends uvm_scoreboard;
    `uvm_component_param_utils(uvm_rate_limiter::scoreboard#(MFB_ITEM_WIDTH, MFB_META_WIDTH, INTERVAL_COUNT, CLK_PERIOD))

    uvm_analysis_export#(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH)) analysis_export_rx_packet;
    uvm_analysis_export#(uvm_logic_vector::sequence_item#(MFB_META_WIDTH))       analysis_export_rx_meta;
    uvm_analysis_export#(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH)) analysis_export_tx_packet;
    uvm_analysis_export#(uvm_logic_vector::sequence_item#(MFB_META_WIDTH))       analysis_export_tx_meta;

    local uvm_tlm_analysis_fifo#(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH)) dut_input;
    local uvm_tlm_analysis_fifo#(uvm_logic_vector::sequence_item#(MFB_META_WIDTH))       dut_input_meta;
    local uvm_tlm_analysis_fifo#(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH)) dut_output;
    local uvm_tlm_analysis_fifo#(uvm_logic_vector::sequence_item#(MFB_META_WIDTH))       dut_output_meta;

    regmodel#(INTERVAL_COUNT) m_regmodel;

    protected int unsigned speed_test_bytes = 0;

    protected int unsigned section_length;
    protected int unsigned interval_length;
    protected int unsigned interval_speed [INTERVAL_COUNT/2];

    function new(string name, uvm_component parent);
        super.new(name, parent);
        analysis_export_rx_packet = new("analysis_export_rx_packet", this);
        analysis_export_rx_meta   = new("analysis_export_rx_meta"  , this);
        analysis_export_tx_packet = new("analysis_export_tx_packet", this);
        analysis_export_tx_meta   = new("analysis_export_tx_meta"  , this);
        dut_input                 = new("dut_input"                , this);
        dut_input_meta            = new("dut_input_meta"           , this);
        dut_output                = new("dut_output"               , this);
        dut_output_meta           = new("dut_output_meta"          , this);
    endfunction

    function void connect_phase(uvm_phase phase);
        analysis_export_rx_packet.connect(dut_input.analysis_export);
        analysis_export_rx_meta.connect(dut_input_meta.analysis_export);
        analysis_export_tx_packet.connect(dut_output.analysis_export);
        analysis_export_tx_meta.connect(dut_output_meta.analysis_export);
    endfunction

    function void regmodel_set(regmodel#(INTERVAL_COUNT) m_regmodel);
        this.m_regmodel = m_regmodel;
    endfunction

    function void read_config_regs();
        section_length  = m_regmodel.get_reg_by_name("section").get();
        interval_length = m_regmodel.get_reg_by_name("interval").get();
        // only half of the registers get configured (to test looping from the first register)
        for (int i = 0; i < INTERVAL_COUNT/2; i++) begin
            interval_speed[i] = m_regmodel.get_reg_by_name({"speed_", i}).get();
        end
    endfunction

    function real conv_Bscn_Gbs(int unsigned Bscn, int unsigned sec_len);
        real clk_period = (CLK_PERIOD*2) / 64'd1_000_000_000_000;
        real clk_freq   = 1 / (clk_period);
        return (Bscn * 8) * (clk_freq / sec_len) / 1_000_000_000;
    endfunction

    function real conv_Gbs_Bscn(int unsigned Gbs, int unsigned sec_len);
        real clk_period = (CLK_PERIOD*2) / 64'd1_000_000_000_000;
        real clk_freq   = 1 / (clk_period);
        return (Gbs / 8.0) / (clk_freq / sec_len) * 1_000_000_000;
    endfunction

    task measuring();
        int unsigned interval_pointer  = 0;

        time speed_test_time = interval_length*section_length*CLK_PERIOD*2;
        time speed_test_start = 400ns;
        time speed_meter_duration;
        time time_act;

        real speed;
        real speed_var;
        real speed_var_limit = conv_Gbs_Bscn(5, section_length);

        forever begin
            time_act = $time();
            speed_meter_duration = time_act - speed_test_start;
            if (speed_meter_duration >= speed_test_time) begin
                speed = real'(speed_test_bytes)/interval_length;
                `uvm_info(this.get_full_name(), $sformatf("expected [%.3fGb/s] - actual [%.3fGb/s]", conv_Bscn_Gbs(interval_speed[interval_pointer], section_length), conv_Bscn_Gbs(speed, section_length)), UVM_NONE)
                speed_var = speed-interval_speed[interval_pointer];
                if (speed_var >= speed_var_limit || speed_var <= -speed_var_limit)
                    `uvm_error(this.get_full_name(), $sformatf("Variability of the output speed is too high [%.3fGb/s (limit +-%.3fGb/s)].", conv_Bscn_Gbs(speed_var, section_length), conv_Bscn_Gbs(speed_var_limit, section_length)))
                speed_test_start = time_act;
                speed_test_bytes = 0;
                interval_pointer = (interval_pointer == $size(interval_speed)-1)? 0 : interval_pointer+1;
            end
            #(CLK_PERIOD);
        end
    endtask

    task run_phase(uvm_phase phase);

        uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH) tr_dut_in;
        uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH) tr_dut_out;
        uvm_logic_vector::sequence_item#(MFB_META_WIDTH)       tr_dut_in_meta;
        uvm_logic_vector::sequence_item#(MFB_META_WIDTH)       tr_dut_out_meta;

        #(400ns)

        read_config_regs();

        fork
            measuring();
        join_none

        forever begin
            dut_output.get(tr_dut_out);
            dut_output_meta.get(tr_dut_out_meta);
            dut_input.get(tr_dut_in);
            dut_input_meta.get(tr_dut_in_meta);

            if (tr_dut_in.compare(tr_dut_out) == 0 || tr_dut_in_meta.compare(tr_dut_out_meta) == 0) begin
                string msg;
                $swrite(msg, "\n\tCheck packet failed.\n\n\tInput packet\n%s\n%s\n\n\tOutput packet\n%s\n%s", tr_dut_in_meta.convert2string(), tr_dut_in.convert2string(), tr_dut_out_meta.convert2string(), tr_dut_out.convert2string());
                `uvm_error(this.get_full_name(), msg);
            end

            speed_test_bytes += tr_dut_out.data.size();
        end
    endtask
endclass
