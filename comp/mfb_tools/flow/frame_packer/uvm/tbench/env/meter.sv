// meter.sv: Speed-meter for verification
// Copyright (C) 2024 CESNET z. s. p. o.
// Author:   David Beneš <xbenes52@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause
class stats;

    local real min;
    local real max;
    local real sum;
    local real sum2;
    local real values_q[$];

    int unsigned values;

    function new();
        values = 0;
        sum  = 0;
        sum2 = 0;
    endfunction


    function void count(output real min, real max, real avg, real std_dev, real median, real modus);
        real avg_local;
        real tmp_mod;
        int unsigned cnt_mod = 0;
        int unsigned tmp_cnt = 0;

        min = this.min;
        max = this.max;

        avg_local = sum/values;
        avg = avg_local;

        std_dev = (1.0/(values-1)*(sum2 - values*(avg_local**2)))**0.5;
        values_q.sort();
        if (values % 2 == 0) begin
            median = (values_q[values/2] + values_q[(values/2)+1])/2;
        end else if (values % 2 == 1) begin
            median = values_q[(values/2)+1];
        end
        for (int unsigned it = 0; it < values_q.size(); it++) begin
            if (tmp_mod == 0) begin
                tmp_mod = values_q[it];
            end

            if (tmp_mod == values_q[it]) begin
                cnt_mod++;
            end else begin
                tmp_mod = values_q[it];
                if (tmp_cnt == 0) begin
                    tmp_cnt = cnt_mod;
                    modus = tmp_mod;
                end else begin
                    if (cnt_mod > tmp_cnt) begin
                        tmp_cnt = cnt_mod;
                        modus = tmp_mod;
                    end
                end
                cnt_mod = 0;
            end
        end
    endfunction

    function void next_val(real val);
        values_q.push_back(val);
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

class meter #(MVB_ITEM_WIDTH, MFB_ITEM_WIDTH, RX_CHANNELS, USR_RX_PKT_SIZE_MAX) extends uvm_component;
    `uvm_component_param_utils(uvm_framepacker::meter#(MVB_ITEM_WIDTH, MFB_ITEM_WIDTH, RX_CHANNELS, USR_RX_PKT_SIZE_MAX))

    uvm_tlm_analysis_fifo #(uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)))  rx_data_in;
    uvm_tlm_analysis_fifo #(uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)))  tx_data_in;

    uvm_tlm_analysis_fifo #(uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)))  mfb_control_data;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(MVB_ITEM_WIDTH))        meta_in;

    local stats  m_input_speed;
    local stats  m_output_speed;

    local stats m_input_length;
    local stats m_output_length;

   function new(string name = "meter", uvm_component parent = null);
        super.new(name, parent);
        rx_data_in          = new("rx_data_in", this);
        tx_data_in          = new("tx_data_in", this);

        mfb_control_data    = new("mfb_control_data", this);
        meta_in             = new("meta_in", this);

        //Local variable
        m_input_speed  = new();
        m_output_speed = new();

        m_input_length  = new();
        m_output_length = new();
    endfunction

    task run_phase(uvm_phase phase);
        fork
            run_input();
            run_output();
            test_mvb();
        join_none
    endtask



    task run_input();
        string msg = "";
        int unsigned speed_packet_size = 0;
        time         speed_start_time  = 0ns;


        uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)) tr_rx_mfb_in;
        forever begin
            time speed_meter_duration;
            time time_act;

            rx_data_in.get(tr_rx_mfb_in);
            time_act = $time();

            // Length statistics
            m_input_length.next_val(tr_rx_mfb_in.item.data.size());

            speed_packet_size += tr_rx_mfb_in.item.data.size();
            speed_meter_duration = time_act - speed_start_time;
            if (speed_meter_duration >= 10us) begin
                real speed;
                speed =  real'(speed_packet_size) / (speed_meter_duration/1ns); //result is in GB/s
                m_input_speed.next_val(speed);
                `uvm_info(this.get_full_name(), $sformatf("\n\tCurrent input speed is %0.3fGb/s in time [%0d:%0d]us", speed*8, speed_start_time/1us, time_act/1us), UVM_LOW);
                `uvm_info(this.get_full_name(), $sformatf("\n\tInput parameters: %0d Bytes in %0d us", speed_packet_size, speed_meter_duration/1us), UVM_LOW);
                speed_start_time  = time_act;
                speed_packet_size = 0;
            end

        end
    endtask

    task run_output();
        string msg = "";
        int unsigned speed_packet_size = 0;
        time         speed_start_time  = 0ns;

        uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)) tr_tx_mfb_in;
        forever begin
            time time_act;
            time speed_meter_duration;

            tx_data_in.get(tr_tx_mfb_in);
            time_act = $time();

            // Length statistics
            m_output_length.next_val(tr_tx_mfb_in.item.data.size());

            //debug
            $swrite(msg, "\nOUTPUT_TIME:     %0d
                          \nOUTPUT_PACKET:   %0s

                          \n",time_act/1us ,tr_tx_mfb_in.convert2string());
            //`uvm_info(this.get_full_name(), msg, UVM_NONE);

            speed_packet_size += tr_tx_mfb_in.item.data.size();
            speed_meter_duration = time_act - speed_start_time;
            if (speed_meter_duration >= 2us) begin
                real speed;
                speed =  real'(speed_packet_size) / (speed_meter_duration/1ns); //result is in GB/s
                m_output_speed.next_val(speed);
                `uvm_info(this.get_full_name(), $sformatf("\n\tCurrent output speed is %0.3fGb/s in time [%0d:%0d]us", speed*8, speed_start_time/1us, time_act/1us), UVM_LOW);
                `uvm_info(this.get_full_name(), $sformatf("\n\tInput parameters: %0d Bytes in %0d us", speed_packet_size, speed_meter_duration/1us), UVM_LOW);
                speed_start_time  = time_act;
                speed_packet_size = 0;
            end
        end

    endtask

    task test_mvb();
        string msg = "";
        logic[MVB_ITEM_WIDTH - 1 : 0] mvb_data;

        logic[3:0]      discard;
        logic[$clog2(RX_CHANNELS)-1 : 0] channel;
        logic[$clog2(USR_RX_PKT_SIZE_MAX) + 1 - 1: 0]  pkt_len;


        uvm_logic_vector::sequence_item #(MVB_ITEM_WIDTH) tr_mvb_in;
        uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)) tr_tx_mfb_in;

        forever begin
            mfb_control_data.get(tr_tx_mfb_in);
            meta_in.get(tr_mvb_in);


            mvb_data = tr_mvb_in.data;

            channel = tr_mvb_in.data[$clog2(RX_CHANNELS):1];    // 4 downto 1
            pkt_len = tr_mvb_in.data[MVB_ITEM_WIDTH - 1 : 12 + $clog2(RX_CHANNELS) + 1];

            // MVB_ITEM_WIDTH = $clog2(USR_RX_PKT_SIZE_MAX+1) + HDR_META_WIDTH + $clog2(RX_CHANNELS) + 1;

            // MVB_ITEM_WIDTH = 15 + 12 + 4 + 1 = 32

            if (tr_tx_mfb_in.item.data.size() == pkt_len) begin
                $swrite(msg,"\nCHANNEL      %0d
                             \nPKT_LEN      %0d
                             \n", tr_mvb_in, channel, pkt_len);
                //`uvm_info(this.get_full_name(), msg, UVM_NONE);
            end else begin
                $swrite(msg,"\nWHOLE_MVB    %0b
                             \nCHANNEL      %0d
                             \nPKT_LEN      %0d
                             \nPKT_ITSELF   %0s
                             \n", tr_mvb_in.data[MVB_ITEM_WIDTH - 1 : 12 + $clog2(RX_CHANNELS) + 1], channel, pkt_len, tr_tx_mfb_in.convert2string());
                `uvm_error(this.get_full_name(), msg);
            end

        end
    endtask

    function void report_phase(uvm_phase phase);
            real min;
            real max;
            real avg;
            real std_dev;
            real median;
            real modus;
            string msg = "\n";

            // Input speed
            m_input_speed.count(min, max, avg, std_dev, median, modus);
            `uvm_info(this.get_full_name(), $sformatf("\n\tSpeed INPUT statistics => min : %0dGb/s, max : %0dGb/s, average : %0dGb/s, standard deviation : %0dG/s, median : %0dG/s", min*8, max*8, avg*8, std_dev*8, median*8), UVM_NONE);

            //Input length
            m_input_length.count(min, max, avg, std_dev, median, modus);
            `uvm_info(this.get_full_name(), $sformatf("\n\tLength INPUT statistics => min : %0d Bytes, max : %0d Bytes, average : %0d Bytes, standard deviation : %0d Bytes, median : %0d Bytes", min, max, avg, std_dev, median), UVM_NONE);

            // Output speed
            m_output_speed.count(min, max, avg, std_dev, median, modus);
            `uvm_info(this.get_full_name(), $sformatf("\n\tSpeed OUTPUT statistics => min : %0dGb/s, max : %0dGb/s, average : %0dGb/s, standard deviation : %0dG/s, median : %0dG/s", min*8, max*8, avg*8, std_dev*8, median*8), UVM_NONE);

            // Output length
            m_output_length.count(min, max, avg, std_dev, median, modus);
            `uvm_info(this.get_full_name(), $sformatf("\n\tLength OUTPUT statistics => min : %0d Bytes, max : %0d Bytes, average : %0d Bytes, standard deviation : %0d Bytes, median : %0d Bytes", min, max, avg, std_dev, median), UVM_NONE);

    endfunction



endclass
