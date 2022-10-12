//-- scoreboard.sv: Scoreboard for verification
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Radek Iša <isa@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

class stats;

    local real min;
    local real max;
    local real sum;
    local real sum2;

    int unsigned values;

    function new();
        values = 0;
        sum  = 0;
        sum2 = 0;
    endfunction


    function void count(output real min, real max, real avg, real std_dev);
        real avg_local;

        min = this.min;
        max = this.max;

        avg_local = sum/values;
        avg = avg_local;

        std_dev = (1.0/(values-1)*(sum2 - values*(avg_local**2)))**0.5;
    endfunction

    function void next_val(real val);
        if (values == 0) begin
            min = val;
            max = val;
        end else begin
            if (min > val) begin
                min = val;
            end

            if (max < val) begin
               max = val;
            end
        end

        sum   += val;
        sum2  += val**2;

        values++;
    endfunction
endclass

class scoreboard #(CHANNELS, PKT_SIZE_MAX, DEVICE) extends uvm_scoreboard;
    `uvm_component_param_utils(uvm_dma_ll::scoreboard #(CHANNELS, PKT_SIZE_MAX, DEVICE))

    localparam LOGIC_WIDTH = 24 + $clog2(PKT_SIZE_MAX+1) + $clog2(CHANNELS);

    //INPUT TO DUT
    uvm_analysis_export #(uvm_byte_array::sequence_item)                  analysis_export_rx_packet;
    uvm_analysis_export #(uvm_logic_vector::sequence_item#(LOGIC_WIDTH))  analysis_export_rx_meta;

    //DUT WATCH INTERFACE
    uvm_analysis_export #(uvm_mvb::sequence_item#(1, $clog2(CHANNELS) + 1)) analysis_export_dma;

    //DUT OUTPUT
    uvm_analysis_export #(uvm_byte_array::sequence_item)                  analysis_export_tx_packet;
    //OUTPUT TO SCOREBOARD
    local uvm_tlm_analysis_fifo #(uvm_byte_array::sequence_item)                dut_output;
    local uvm_tlm_analysis_fifo #(uvm_byte_array::sequence_item)                model_output;

    local model #(CHANNELS, PKT_SIZE_MAX, DEVICE) m_model;
    local regmodel#(CHANNELS) m_regmodel;

    local stats        m_input_speed;
    local uvm_tlm_analysis_fifo #(uvm_byte_array::sequence_item) rx_speed_meter;
    local stats        m_delay;
    local stats        m_output_speed;
    local int unsigned compared = 0;
    local int unsigned errors   = 0;
    typedef struct{
        uvm_byte_array::sequence_item item;
        time output_time;
    } output_type;
    local output_type out_data[$];

    // Contructor of scoreboard.
    function new(string name, uvm_component parent);
        super.new(name, parent);
        // DUT MODEL COMUNICATION 
        analysis_export_rx_packet = new("analysis_export_rx_packet", this);
        analysis_export_rx_meta   = new("analysis_export_rx_meta",   this);
        analysis_export_dma       = new("analysis_export_dma",       this);
        analysis_export_tx_packet = new("analysis_export_tx_packet", this);
        model_output              = new("model_output",              this);
        dut_output                = new("dut_output",                this);

        //LOCAL VARIABLES
        rx_speed_meter = new("rx_speed_meter", this);
        m_delay = new();
        m_output_speed = new();
        m_input_speed  = new();
    endfunction

    function void regmodel_set(regmodel#(CHANNELS) m_regmodel);
        this.m_regmodel = m_regmodel;
        m_model.regmodel_set(m_regmodel);
    endfunction

    //build phase
    function void build_phase(uvm_phase phase);
        m_model = model #(CHANNELS, PKT_SIZE_MAX, DEVICE)::type_id::create("m_model", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        analysis_export_rx_packet.connect(m_model.analysis_imp_rx.analysis_export);
        analysis_export_rx_packet.connect(rx_speed_meter.analysis_export);
        analysis_export_rx_meta.connect(m_model.analysis_imp_rx_meta.analysis_export);
        analysis_export_dma.connect(m_model.analysis_dma.analysis_export);
        analysis_export_tx_packet.connect(dut_output.analysis_export);

        m_model.analysis_port_tx.connect(model_output.analysis_export);
    endfunction

    function bit pcie_compare(uvm_byte_array::sequence_item tr_dut, model_packet packet_model);
        bit ret = 1;
        uvm_byte_array::sequence_item tr_model;

        if (packet_model.data_packet == 1 && packet_model.part == packet_model.part_num) begin
            if (tr_dut.data.size() != (128 + 16)) begin
                ret = 0;
            end else begin
                ret = 1;
                for (int unsigned it = 0; it < packet_model.data.size(); it++) begin
                    if (tr_dut.data[it] != packet_model.data[it]) begin
                        return 0;
                    end
                end
            end
        end else begin
            tr_model = uvm_byte_array::sequence_item::type_id::create("tr_model"); 
            tr_model.data = packet_model.data;
            ret = tr_dut.compare(tr_model); 
        end

        return ret;
    endfunction

    task run_input();
        int unsigned speed_packet_size = 0;
        time         speed_start_time  = 0ns;


        forever begin
            uvm_byte_array::sequence_item tr;
            time time_act;
            time speed_metet_duration;
            rx_speed_meter.get(tr);
            time_act = $time();

            speed_packet_size += tr.data.size();
            speed_metet_duration = time_act - speed_start_time;
            if (speed_metet_duration >= 10us) begin
                real speed;
                speed =  real'(speed_packet_size) / (speed_metet_duration/1ns); //result is in GB/s
                m_input_speed.next_val(speed);
                speed_start_time  = time_act;
                speed_packet_size = 0;
                `uvm_info(this.get_full_name(), $sformatf("\n\tCurrent input speed (MFB RX) is %0.3fGb/s in time [%0d:%0d]us", speed*8, speed_start_time/1us, time_act/1us), UVM_LOW);
            end
        end
    endtask

    task run_output();
        uvm_byte_array::sequence_item tr_dut;
        output_type data;
        int unsigned speed_packet_size = 0;
        time         speed_start_time  = 0ns;


        forever begin
            time time_act;
            time speed_metet_duration;
            dut_output.get(tr_dut);
            time_act = $time();

            data.item        = tr_dut;
            data.output_time = time_act;
            out_data.push_back(data);

            speed_packet_size += tr_dut.data.size();
            speed_metet_duration = time_act - speed_start_time;
            if (speed_metet_duration >= 10us) begin
                real speed;
                speed =  real'(speed_packet_size) / (speed_metet_duration/1ns); //result is in GB/s
                m_output_speed.next_val(speed);
                speed_start_time  = time_act;
                speed_packet_size = 0;
                `uvm_info(this.get_full_name(), $sformatf("\n\tCurrent output speed (PCIE TX) is %0.3fGb/s in time [%0d:%0d]us", speed*8, speed_start_time/1us, time_act/1us), UVM_LOW);
            end
        end
    endtask

    task run_phase(uvm_phase phase);
        string msg = "";
        model_packet              packet_model;
        uvm_byte_array::sequence_item tr_model;
        output_type tr_dut;

        fork 
            run_output();
            run_input();
        join_none

        forever begin
            msg = "";

            wait (out_data.size() != 0);
            tr_dut = out_data.pop_front();
            // Get transaction from model
            model_output.get(tr_model);

            $cast(packet_model, tr_model);

            compared++;
            $swrite(msg, "\nSegments errors/compared : %0d/%0d Packet num %0d", errors, compared, packet_model.packet_num);

            if (!((m_regmodel.channel[packet_model.channel].status.get() & 32'h1 ) | (m_regmodel.channel[packet_model.channel].control.get() & 32'h1))) begin
                $swrite(msg, "%s\nReceived packet on stopped channel Packet is:\n\t\tPart is : %s\n\t\tChannel : %0d\n\t\tPart %0d/%0d", msg, packet_model.data_packet == 1 ? "DATA" : "HEADER",  packet_model.channel, packet_model.part, packet_model.part_num);
                `uvm_error(this.get_full_name(), msg);
            end

            if (pcie_compare(tr_dut.item, packet_model) == 0) begin
                errors++;

                $swrite(msg, "%s\nExpected transaction is:\n\t\tPart is : %s\n\t\tChannel : %0d\n\t\tPart %0d/%0d\n\t\tInput time : %dns", msg, packet_model.data_packet == 1 ? "DATA" : "HEADER",  packet_model.channel, packet_model.part, packet_model.part_num, packet_model.start_time/1ns);
                `uvm_error(this.get_full_name(), $sformatf("%s\nMODEL transaction%s\nDUT Transaction%s\n\tDUT doesnt match MODEL transaction", msg, tr_model.convert2string(), tr_dut.item.convert2string()));
            end else begin
                $swrite(msg, "%s\nRecive correct transaction :\n\t\tPart is : %s\n\t\tChannel : %0d\n\t\tPart %0d/%0d\n\t\tPart is delay from SOF on input %0dns", msg, packet_model.data_packet == 1 ? "DATA" : "HEADER",  packet_model.channel, packet_model.part, packet_model.part_num, (tr_dut.output_time - packet_model.start_time)/1ns);
                `uvm_info(this.get_full_name(), $sformatf("%s\nTransaction%s", msg, tr_model.convert2string()), UVM_MEDIUM);
            end

            //count stats
            //if (packet_model.part == packet_model.part_num && packet_model.data_packet == 1) begin
            //Count delay if you get first data packet.
            if (packet_model.part == 1 && packet_model.data_packet == 1) begin

                m_delay.next_val((tr_dut.output_time - packet_model.start_time)/1ns);
            end
        end
    endtask


    function void report_phase(uvm_phase phase);
        real min;
        real max;
        real avg;
        real std_dev;
        string str = "";

        m_delay.count(min, max, avg, std_dev);
        $swrite(str, "%s\n\tDelay statistic (SOF to SOF) => min : %0dns, max : %0dns, avearge : %0dns, standard deviation : %0dns", str, min, max, avg, std_dev);
        m_input_speed.count(min, max, avg, std_dev);
        $swrite(str, "%s\n\tSpeed input  statistic (MFB RX)  => min : %0dGb/s, max : %0dGb/s, avearge : %0dG/s, standard deviation : %0dG/s", str, min*8, max*8, avg*8, std_dev*8);
        m_output_speed.count(min, max, avg, std_dev);
        $swrite(str, "%s\n\tSpeed output statistic (PCIE TX) => min : %0dGb/s, max : %0dGb/s, avearge : %0dG/s, standard deviation : %0dG/s", str, min*8, max*8, avg*8, std_dev*8);
        if (errors == 0) begin
            `uvm_info(this.get_full_name(), {str, "\n\n\t---------------------------------------\n\t----     VERIFICATION SUCCESS      ----\n\t---------------------------------------"}, UVM_NONE)
        end else begin
            `uvm_info(this.get_full_name(), {str, "\n\n\t---------------------------------------\n\t----     VERIFICATION FAIL      ----\n\t---------------------------------------"}, UVM_NONE)
        end
    endfunction
endclass
