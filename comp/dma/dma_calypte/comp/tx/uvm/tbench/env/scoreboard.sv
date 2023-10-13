//-- scoreboard.sv: Scoreboard for verification
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

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

class compare #(ITEM_WIDTH, USER_META_WIDTH, DEBUG, CHANNELS) extends uvm_component;
    `uvm_component_utils(uvm_dma_ll::compare #(ITEM_WIDTH, USER_META_WIDTH, DEBUG, CHANNELS))

    uvm_tlm_analysis_fifo #(uvm_common::model_item #(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH))) model_mfb;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item#(USER_META_WIDTH))                            model_meta;
    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH))                           dut_mfb;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item#(USER_META_WIDTH))                            dut_meta;

    int unsigned errors;
    int unsigned compared;
    stats        m_delay;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        model_mfb  = new("model_mfb", this);
        model_meta = new("model_meta", this);
        dut_mfb    = new("dut_mfb", this);
        dut_meta   = new("dut_meta", this);
        errors     = 0;
        compared   = 0;
    endfunction

    task write_meta(uvm_logic_vector::sequence_item#(USER_META_WIDTH)  tr_model_meta,
                    uvm_logic_vector::sequence_item#(USER_META_WIDTH)  tr_dut_meta);

        string msg;

        $swrite(msg, "%s\n\nMETA COMPARISON CHANNEL %d", msg, tr_model_meta.data[$clog2(CHANNELS)+24-1 : 24]);
        $swrite(msg, "%s\n===============================================\n", msg);
        $swrite(msg, "%s\n Comparison failed at meta number %d! \n\tModel meta:\n%s\n\tDUT meta:\n%s\n", msg, compared, tr_model_meta.convert2string(), tr_dut_meta.convert2string());
        $swrite(msg, "%s\n DMA MODEL META %h", msg, tr_model_meta.data[23 : 0]);
        $swrite(msg, "%s\n DMA MODEL CHANNEL %d", msg, tr_model_meta.data[$clog2(CHANNELS)+24-1 : 24]);
        $swrite(msg, "%s\n DMA MODEL SIZE %d\n", msg, tr_model_meta.data[USER_META_WIDTH-1 : $clog2(CHANNELS)+24]);
        $swrite(msg, "%s\n DMA DUT META %h", msg, tr_dut_meta.data[23 : 0]);
        $swrite(msg, "%s\n DMA DUT CHANNEL %d", msg, tr_dut_meta.data[$clog2(CHANNELS)+24-1 : 24]);
        $swrite(msg, "%s\n DMA DUT SIZE %d\n", msg, tr_dut_meta.data[USER_META_WIDTH-1 : $clog2(CHANNELS)+24]);
        $swrite(msg, "%s\n===============================================\n", msg);
        `uvm_error(this.get_full_name(), msg);
    endtask

    task write_data(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH) tr_dut_mfb,
                    uvm_logic_vector_array::sequence_item#(ITEM_WIDTH) tr_model_mfb,
                    uvm_logic_vector::sequence_item#(USER_META_WIDTH)  tr_model_meta);

        string msg;
        logic [ITEM_WIDTH-1 : 0] bad_tr[$];
        int unsigned             bad_tr_pos[$];
        logic [ITEM_WIDTH-1 : 0] correct_tr[$];

        if (DEBUG) begin
            foreach(tr_dut_mfb.data[it]) begin
                if (tr_dut_mfb.data[it] != tr_model_mfb.data[it]) begin
                    bad_tr.push_back(tr_dut_mfb.data[it]);
                    bad_tr_pos.push_back(it);
                    correct_tr.push_back(tr_model_mfb.data[it]);
                end
            end

            $displayh("WRONG BYTES: %p CORRECT BYTES: %p\n", bad_tr, correct_tr);
            $display("WRONG BYTES POS: %p\n", bad_tr_pos);
        end

        $swrite(msg, "%s\n\nDATA COMPARISON CHANNEL %d", msg, tr_model_meta.data[$clog2(CHANNELS)+24-1 : 24]);
        $swrite(msg, "%s\n=============================================================================================================================\n", msg);
        $swrite(msg, "%s\n\t Comparison failed at data number %d! \n\tModel data:\n%s\n\tDUT data:\n%s\n", msg, compared, tr_model_mfb.convert2string(), tr_dut_mfb.convert2string());
        $swrite(msg, "%s\n=============================================================================================================================\n", msg);
        `uvm_error(this.get_full_name(), msg);
    endtask


    task run_phase(uvm_phase phase);
        uvm_common::model_item #(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)) tr_model_mfb;
        uvm_logic_vector::sequence_item#(USER_META_WIDTH)                            tr_model_meta;
        uvm_common::model_item #(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)) tr_dut_mfb;
        uvm_logic_vector::sequence_item#(USER_META_WIDTH)                            tr_dut_meta;

        uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)                           tr_dut_mfb_comp;
        uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)                           tr_model_mfb_comp;
        uvm_logic_vector::sequence_item#(USER_META_WIDTH)                            tr_dut_meta_comp;
        uvm_logic_vector::sequence_item#(USER_META_WIDTH)                            tr_model_meta_comp;

        uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)                           tr_model_mfb_fifo[CHANNELS][$];
        uvm_logic_vector::sequence_item#(USER_META_WIDTH)                            tr_model_meta_fifo[CHANNELS][$];
        uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)                           tr_dut_mfb_fifo[CHANNELS][$];
        uvm_logic_vector::sequence_item#(USER_META_WIDTH)                            tr_dut_meta_fifo[CHANNELS][$];

        logic [ITEM_WIDTH-1 : 0]       bad_tr[$];
        int unsigned                   bad_tr_pos[$];
        logic [ITEM_WIDTH-1 : 0]       correct_tr[$];
        logic [$clog2(CHANNELS)-1 : 0] model_channel;
        logic [$clog2(CHANNELS)-1 : 0] dut_channel;
        string                       debug_msg;

        forever begin
            tr_dut_mfb = uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(ITEM_WIDTH))::type_id::create("tr_dut_mfb");
            model_mfb.get(tr_model_mfb);
            model_meta.get(tr_model_meta);
            dut_mfb.get(tr_dut_mfb.item);
            tr_dut_mfb.time_add("dut mfb out", $time());
            dut_meta.get(tr_dut_meta);

            model_channel = tr_model_meta.data[$clog2(CHANNELS)+24-1 : 24];
            dut_channel = tr_dut_meta.data[$clog2(CHANNELS)+24-1 : 24];

            tr_model_mfb_fifo[int'(model_channel)].push_back(tr_model_mfb.item);
            tr_model_meta_fifo[int'(model_channel)].push_back(tr_model_meta);
            tr_dut_mfb_fifo[int'(dut_channel)].push_back(tr_dut_mfb.item);
            tr_dut_meta_fifo[int'(dut_channel)].push_back(tr_dut_meta);

            compared++;

            for (int unsigned chan = 0; chan < CHANNELS; chan++) begin
                if (tr_model_meta_fifo[chan].size() != 0 && tr_dut_meta_fifo[chan].size() != 0) begin
                    tr_dut_meta_comp   = tr_dut_meta_fifo[chan].pop_front();
                    tr_model_meta_comp = tr_model_meta_fifo[chan].pop_front();

                    if (tr_model_meta_comp.compare(tr_dut_meta_comp) == 0) begin
                        errors++;
                        write_meta(tr_model_meta_comp, tr_dut_meta_comp);
                    end
                end

                if (tr_model_mfb_fifo[chan].size() != 0 && tr_dut_mfb_fifo[chan].size() != 0) begin
                    tr_dut_mfb_comp   = tr_dut_mfb_fifo[chan].pop_front();
                    tr_model_mfb_comp = tr_model_mfb_fifo[chan].pop_front();

                    if (tr_model_mfb_comp.compare(tr_dut_mfb_comp) == 0) begin
                        errors++;
                        write_data(tr_dut_mfb_comp, tr_model_mfb_comp, tr_model_meta_comp);
                    end
                end
            end

            debug_msg = "\n";
            $swrite(debug_msg, "%s================================================================================= \n", debug_msg);
            $swrite(debug_msg, "%SDUT TRANSACTION %0d COMPARED!\n", debug_msg, compared);
            $swrite(debug_msg, "%s================================================================================= \n", debug_msg);
            $swrite(debug_msg, "%sCHANNEL : %0d\n", debug_msg, dut_channel);
            $swrite(debug_msg, "%sDATA    : %s\n", debug_msg, tr_dut_mfb.item.convert2string());
            `uvm_info(this.get_full_name(),        debug_msg, UVM_MEDIUM)

            //count stats
            //Count delay if you get first data packet.
            m_delay.next_val((tr_dut_mfb.start["dut mfb out"] - tr_model_mfb.start["model mfb out"])/1ns);

        end
    endtask

endclass

class scoreboard #(CHANNELS, PKT_SIZE_MAX, DEVICE, USR_ITEM_WIDTH, USER_META_WIDTH, CQ_ITEM_WIDTH,
                   DATA_ADDR_W, DEBUG) extends uvm_scoreboard;
    `uvm_component_param_utils(uvm_dma_ll::scoreboard #(CHANNELS, PKT_SIZE_MAX, DEVICE, USR_ITEM_WIDTH,
                                                        USER_META_WIDTH, CQ_ITEM_WIDTH, DATA_ADDR_W,
                                                        DEBUG))

    //INPUT TO DUT
    uvm_analysis_export #(uvm_logic_vector_array::sequence_item#(CQ_ITEM_WIDTH))                   analysis_export_rx_packet;
    uvm_analysis_export #(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)) analysis_export_rx_meta;
    uvm_analysis_export #(uvm_logic_vector::sequence_item#(1))                                     analysis_export_dma;
    //DUT OUTPUT
    uvm_analysis_export #(uvm_logic_vector_array::sequence_item#(USR_ITEM_WIDTH)) analysis_export_tx_packet;
    uvm_analysis_export #(uvm_logic_vector::sequence_item#(USER_META_WIDTH))      analysis_export_tx_meta;
    //OUTPUT TO SCOREBOARD

    model #(CHANNELS, PKT_SIZE_MAX, DEVICE, USR_ITEM_WIDTH, USER_META_WIDTH, CQ_ITEM_WIDTH,
            DATA_ADDR_W, DEBUG) m_model;

    local uvm_dma_regs::regmodel#(CHANNELS) m_regmodel;
    uvm_dma_ll::compare #(USR_ITEM_WIDTH, USER_META_WIDTH, DEBUG, CHANNELS) tr_compare;

    local int unsigned compared;
    local int unsigned errors;

    uvm_reg_data_t dma_cnt          [CHANNELS];
    uvm_reg_data_t byte_cnt         [CHANNELS];
    uvm_reg_data_t discard_dma_cnt  [CHANNELS];
    uvm_reg_data_t discard_byte_cnt [CHANNELS];
    uvm_status_e   status_r;

    local stats  m_input_speed;
    local stats  m_delay;
    local stats  m_output_speed;
    local uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item#(USR_ITEM_WIDTH)) tx_speed_meter;
    local uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item#(CQ_ITEM_WIDTH))  rx_speed_meter;

    // Contructor of scoreboard.
    function new(string name, uvm_component parent);
        super.new(name, parent);
        // DUT MODEL COMUNICATION 
        analysis_export_rx_packet = new("analysis_export_rx_packet", this);
        analysis_export_rx_meta   = new("analysis_export_rx_meta"  , this);
        analysis_export_tx_packet = new("analysis_export_tx_packet", this);
        tx_speed_meter            = new("tx_speed_meter"           , this);
        analysis_export_tx_meta   = new("analysis_export_tx_meta"  , this);
        analysis_export_dma       = new("analysis_export_dma"      , this);

        //LOCAL VARIABLES
        rx_speed_meter = new("rx_speed_meter", this);
        m_delay = new();
        m_output_speed = new();
        m_input_speed  = new();
        compared = 0;
        errors   = 0;
    endfunction

        function int unsigned used();
        int unsigned ret = 0;

        ret |= tr_compare.model_mfb.used()  != 0;
        ret |= tr_compare.model_meta.used() != 0;
        ret |= tr_compare.dut_mfb.used()    != 0;
        ret |= tr_compare.dut_meta.used()   != 0;

        return ret;
    endfunction

    function void regmodel_set(uvm_dma_regs::regmodel#(CHANNELS) m_regmodel);
        this.m_regmodel = m_regmodel;
        m_model.regmodel_set(m_regmodel);
    endfunction

    //build phase
    function void build_phase(uvm_phase phase);
        m_model = model #(CHANNELS, PKT_SIZE_MAX, DEVICE, USR_ITEM_WIDTH, USER_META_WIDTH, CQ_ITEM_WIDTH, DATA_ADDR_W, DEBUG)::type_id::create("m_model", this);
        tr_compare = uvm_dma_ll::compare#(USR_ITEM_WIDTH, USER_META_WIDTH, DEBUG, CHANNELS)::type_id::create("tr_compare", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        analysis_export_rx_packet.connect(m_model.analysis_imp_rx.analysis_export);
        analysis_export_rx_packet.connect(rx_speed_meter.analysis_export);
        analysis_export_rx_meta.connect(m_model.analysis_imp_rx_meta.analysis_export);

        m_model.analysis_port_tx.connect(tr_compare.model_mfb.analysis_export);
        m_model.analysis_port_meta_tx.connect(tr_compare.model_meta.analysis_export);

        analysis_export_tx_packet.connect(tr_compare.dut_mfb.analysis_export);
        analysis_export_tx_packet.connect(tx_speed_meter.analysis_export);
        analysis_export_tx_meta.connect(tr_compare.dut_meta.analysis_export);
        tr_compare.m_delay = m_delay;
        analysis_export_dma.connect(m_model.discard_comp.analysis_imp_rx_dma.analysis_export);

    endfunction

    task run_output();
        uvm_logic_vector_array::sequence_item#(USR_ITEM_WIDTH) tr_dut;
        int unsigned speed_packet_size = 0;
        time         speed_start_time  = 0ns;

        forever begin
            time time_act;
            time speed_metet_duration;

            tx_speed_meter.get(tr_dut);
            time_act = $time();

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

    task run_input();
        int unsigned speed_packet_size = 0;
        time         speed_start_time  = 0ns;

        forever begin
            uvm_logic_vector_array::sequence_item#(CQ_ITEM_WIDTH) tr;
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

    task run_phase(uvm_phase phase);

        fork
            run_output();
            run_input();
        join_none

    endtask

    function void report_phase(uvm_phase phase);
        real min;
        real max;
        real avg;
        real std_dev;
        real median;
        real modus;
        string msg = "\n";

        errors   = tr_compare.errors;
        compared = tr_compare.compared;

        if (this.get_report_verbosity_level() >= UVM_LOW) begin
            m_delay.count(min, max, avg, std_dev, median, modus);
            $swrite(msg, "%s\n\tDelay statistic (SOF to SOF) => min : %0dns, max : %0dns, average : %0dns, standard deviation : %0dns, median : %0dns, modus : %0dns", msg, min, max, avg, std_dev, median, modus);
            m_input_speed.count(min, max, avg, std_dev, median, modus);
            $swrite(msg, "%s\n\tSpeed input  statistic (PCIE RX)  => min : %0dGb/s, max : %0dGb/s, average : %0dGb/s, standard deviation : %0dG/s, median : %0dG/s", msg, min*8, max*8, avg*8, std_dev*8, median*8);
            m_output_speed.count(min, max, avg, std_dev, median, modus);
            $swrite(msg, "%s\n\tSpeed output statistic (MFB TX) => min : %0dGb/s, max : %0dGb/s, average : %0dGb/s, standard deviation : %0dG/s, median : %0dG/s", msg, min*8, max*8, avg*8, std_dev*8, median*8);
        end

        if (errors == 0 && this.used() == 0) begin


            $swrite(msg, "%s================================================================================= \n", msg);
            $swrite(msg, "%s\nEXPORT USED                        \n", msg                                             );
            $swrite(msg, "%s================================================================================= \n", msg);
            $swrite(msg, "%sMODEL_MFB.USED  %d\n", msg, tr_compare.model_mfb.used()                                   );
            $swrite(msg, "%sMODEL_META.USED %d\n", msg, tr_compare.model_meta.used()                                  );
            $swrite(msg, "%sDUT_MFB.USED    %d\n", msg, tr_compare.dut_mfb.used()                                     );
            $swrite(msg, "%sDUT_META.USED   %d\n", msg, tr_compare.dut_meta.used()                                    );
            $swrite(msg, "%s================================================================================= \n", msg);

            for (int chan = 0; chan < CHANNELS; chan++) begin

                if (byte_cnt[chan] != m_model.cnt_reg[chan].byte_cnt &&
                    dma_cnt[chan]  != m_model.cnt_reg[chan].dma_cnt) begin
                    string msg_1;
                    $swrite(msg_1, "%sMODEL BYTE COUNT %d and DUT BYTE COUNT %d\n", msg_1, byte_cnt[chan], m_model.cnt_reg[chan].byte_cnt);
                    $swrite(msg_1, "%sMODEL BYTE COUNT %d and DUT BYTE COUNT %d\n", msg_1, dma_cnt[chan], m_model.cnt_reg[chan].dma_cnt);
                    `uvm_error(this.get_full_name(), msg_1);
                end

                if (discard_byte_cnt[chan] != m_model.cnt_reg[chan].discard_byte_cnt &&
                    discard_dma_cnt[chan]  != m_model.cnt_reg[chan].discard_dma_cnt) begin
                    string msg_1;
                    $swrite(msg_1, "%sMODEL DISCARD BYTE COUNT %d and DUT DISCARD BYTE COUNT %d\n", msg_1, discard_byte_cnt[chan], m_model.cnt_reg[chan].discard_byte_cnt);
                    $swrite(msg_1, "%sMODEL DISCARD BYTE COUNT %d and DUT DISCARD BYTE COUNT %d\n", msg_1, discard_dma_cnt[chan], m_model.cnt_reg[chan].discard_dma_cnt);
                    `uvm_error(this.get_full_name(), msg_1);
                end


                $swrite(msg, "%s================================================================================= \n", msg);
                $swrite(msg, "%s\nMODEL COUNTERS STATISTICS\n", msg                                                       );
                $swrite(msg, "%s================================================================================= \n", msg);
                $swrite(msg, "%sDMA_CNT            %d\n", msg, m_model.cnt_reg[chan].dma_cnt                        );
                $swrite(msg, "%sBYTE_CNT           %d\n", msg, m_model.cnt_reg[chan].byte_cnt                       );
                $swrite(msg, "%sDISCARD_DMA_CNT    %d\n", msg, m_model.cnt_reg[chan].discard_dma_cnt                );
                $swrite(msg, "%sDISCARD_BYTE_CNT   %d\n", msg, m_model.cnt_reg[chan].discard_byte_cnt               );
                $swrite(msg, "%s================================================================================= \n", msg);
                $swrite(msg, "%s\nDUT COUNTERS STATISTICS\n", msg                                                         );
                $swrite(msg, "%s================================================================================= \n", msg);
                $swrite(msg, "%sDMA_CNT            %d\n", msg, dma_cnt[chan]                                        );
                $swrite(msg, "%sBYTE_CNT           %d\n", msg, byte_cnt[chan]                                       );
                $swrite(msg, "%sDISCARD_DMA_CNT    %d\n", msg, discard_dma_cnt[chan]                                );
                $swrite(msg, "%sDISCARD_BYTE_CNT   %d\n", msg, discard_byte_cnt[chan]                               );
                $swrite(msg, "%s================================================================================= \n", msg);

            end

            $swrite(msg, "%sCompared packets: %0d", msg, compared);
            `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION SUCCESS      ----\n\t---------------------------------------"}, UVM_NONE)
        end else begin
            string msg = "";

            $swrite(msg, "%sCompared packets: %0d errors %0d", msg, compared, errors);
            `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION FAILED       ----\n\t---------------------------------------"}, UVM_NONE)
        end

    endfunction
endclass
