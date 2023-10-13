//-- reg_sequence: register sequence 
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 


class start_channel extends uvm_sequence;
    `uvm_object_utils(test::start_channel)

    uvm_dma_regs::reg_channel m_regmodel;

    rand logic [64-1:0] data_base_addr;
    rand logic [64-1:0] hdr_base_addr;
    logic [16-1 : 0] hdp;
    logic [16-1 : 0] hhp;
    logic [16-1 : 0] sdp;
    logic [16-1 : 0] shp;
    logic [16-1 : 0] mask;
    int unsigned channel;

    function new (string name = "start_channel");
        super.new(name);
    endfunction

    task ptr_read(uvm_reg register, output logic [16-1:0] ptr);
        uvm_status_e   status;
        uvm_reg_data_t data;
        register.read(status, data, .parent(this));
        ptr = data;
    endtask

    //set base address, mask, pointers
    task body();
        uvm_status_e   status;
        uvm_reg_data_t data;

        `uvm_info(this.get_full_name(), $sformatf("\n============= REQUEST TO START CHANNEL %0d! =============", channel) ,UVM_MEDIUM)

        //Randomize sequence of doing this
        //write sw_pointers
        m_regmodel.sw_data_pointer.write(status, 'h0, .parent(this));
        m_regmodel.sw_hdr_pointer.write(status,  'h0, .parent(this));

        ptr_read(m_regmodel.data_mask , mask);
        ptr_read(m_regmodel.hdr_mask , mask);

        //startup channel
        m_regmodel.status.read(status, data, .parent(this));
        m_regmodel.control.write(status,  32'h1,  .parent(this));

        do begin
            `uvm_info(this.get_full_name(), "\nSTARTING CHANNEL" ,UVM_DEBUG)
            #(20ns)

            m_regmodel.status.read(status, data, .parent(this));
        end while ((data & 32'h1) == 0);

        ptr_read(m_regmodel.hw_data_pointer, hdp);
        ptr_read(m_regmodel.hw_hdr_pointer , hhp);
        ptr_read(m_regmodel.sw_data_pointer, sdp);
        ptr_read(m_regmodel.sw_hdr_pointer , shp);

        `uvm_info(this.get_full_name(), $sformatf("Pointers in the end %d, HDP %h(%d), SDP %h(%d), HHP %h(%d), SHP %h(%d)\n", channel, hdp, hdp, sdp, sdp, hhp, hhp, shp, shp), UVM_DEBUG)
        `uvm_info(this.get_full_name(), $sformatf("\n============= CHANNEL %0d IS RUNNING! =============", channel) ,UVM_MEDIUM)

        if (sdp != hdp || shp != hhp) begin
            `uvm_error(this.get_full_name(), $sformatf("Pointers have not been cleared\n\tchannel: %d\n\tHDP: 0x%h(%d)\n\tSDP: 0x%h(%d)\n\tHHP: 0x%h(%d)\n\tSHP: 0x%h(%d)\n", channel, hdp, hdp, sdp, sdp, hhp, hhp, shp, shp));
        end

    endtask
endclass

class stop_channel extends uvm_sequence;
    `uvm_object_utils(test::stop_channel)

    uvm_dma_regs::reg_channel m_regmodel;

    logic [16-1 : 0] hdp;
    logic [16-1 : 0] hhp;
    logic [16-1 : 0] sdp;
    logic [16-1 : 0] shp;
    int unsigned channel;

    function new (string name = "stop_channel");
        super.new(name);
    endfunction

    task ptr_read(uvm_reg register, output logic [16-1:0] ptr);
        uvm_status_e   status;
        uvm_reg_data_t data;
        register.read(status, data, .parent(this));
        ptr = data;
    endtask

    task body();
        localparam MAX_TIME = 200000ns;
        uvm_status_e   status;
        uvm_reg_data_t data;
        time act_time;

        `uvm_info(this.get_full_name(), $sformatf("\n============= REQUEST TO STOP CHANNEL %0d! =============", channel) ,UVM_MEDIUM)

        //startup channel
        m_regmodel.control.write(status, 32'h0, .parent(this));
        m_regmodel.status.read(status, data, .parent(this));

        // Wait for pointers
        ptr_read(m_regmodel.hw_data_pointer, hdp);
        ptr_read(m_regmodel.hw_hdr_pointer , hhp);
        ptr_read(m_regmodel.sw_data_pointer, sdp);
        ptr_read(m_regmodel.sw_hdr_pointer , shp);

        act_time = $time();
        while (sdp != hdp || shp != hhp) begin
            #(200ns);
            ptr_read(m_regmodel.hw_data_pointer, hdp);
            ptr_read(m_regmodel.hw_hdr_pointer , hhp);
            ptr_read(m_regmodel.sw_data_pointer, sdp);
            ptr_read(m_regmodel.sw_hdr_pointer , shp);
            `uvm_info(this.get_full_name(), $sformatf("Waiting for pointers on channel %d, HDP %h(%d), SDP %h(%d), HHP %h(%d), SHP %h(%d)\n", channel, hdp, hdp, sdp, sdp, hhp, hhp, shp, shp), UVM_DEBUG)
            if ($time() > act_time + MAX_TIME) begin
                `uvm_error(this.get_full_name(), $sformatf("Pointers have not been met\n\tchannel: %d\n\tHDP: 0x%h(%d)\n\tSDP: 0x%h(%d)\n\tHHP: 0x%h(%d)\n\tSHP: 0x%h(%d)\n", channel, hdp, hdp, sdp, sdp, hhp, hhp, shp, shp));
            end
        end
        `uvm_info(this.get_full_name(), "Pointers are equal\n" ,UVM_DEBUG)

        do begin
            `uvm_info(this.get_full_name(), $sformatf("\n============= CHANNEL %0d IS STOPPED! =============", channel) ,UVM_MEDIUM)
            #(300ns)
            m_regmodel.status.read(status, data, .parent(this));
        end while ((data & 32'h1) == 1);
    endtask
endclass


class run_channel#(CQ_ITEM_WIDTH, PKT_SIZE_MAX, PCIE_LEN_MIN) extends uvm_sequence;
    `uvm_object_utils(test::run_channel#(CQ_ITEM_WIDTH, PKT_SIZE_MAX, PCIE_LEN_MIN))
    `uvm_declare_p_sequencer(uvm_logic_vector_array::sequencer#(CQ_ITEM_WIDTH))

    rand time run_time  = 40ns;
    time stop_time = 10ns;
    time update_time = 20ns;

    rand int unsigned rand_run_count;
    // int unsigned run_count_min = 10;
    // int unsigned run_count_max = 20;
    int unsigned run_count_min = 5;
    int unsigned run_count_max = 10;

    time update_time_min = 300ns;
    time update_time_max = 1us;

    time run_time_min = 30us;
    time run_time_max = 500us;

    time stop_time_min = 6us;
    time stop_time_max = 30us;

    int unsigned channel;
    uvm_phase phase;

    uvm_dma_regs::reg_channel m_regmodel;

    uvm_dma_ll_info::watchdog #(CHANNELS) m_watch_dog;

    enum int unsigned { STOPPED = 0, RUNNING = 1, STARTING = 2} state;

    task ptr_read(uvm_reg register, output logic [16-1:0] ptr);
        uvm_status_e   status;
        uvm_reg_data_t data;
        register.read(status, data, .parent(this));
        ptr = data;
    endtask

    function new (string name = "run_channel");
        super.new(name);
    endfunction

    task body();
        start_channel  seq_start;
        stop_channel   seq_stop;
        send_pkt_seq#(CQ_ITEM_WIDTH, PKT_SIZE_MAX, PCIE_LEN_MIN, 2, 10) seq_send_pkt;
        send_pkt_seq#(CQ_ITEM_WIDTH, PKT_SIZE_MAX, PCIE_LEN_MIN, 2, 5) seq_discd_pkt;
        string msg;

        time start_time;

        seq_start  = start_channel::type_id::create({ this.get_name(), "_seq_start"});
        seq_start.m_regmodel = m_regmodel;
        seq_stop   = stop_channel::type_id::create({ this.get_name(), "seq_stop"});
        seq_stop.m_regmodel = m_regmodel;
        seq_send_pkt   = send_pkt_seq#(CQ_ITEM_WIDTH, PKT_SIZE_MAX, PCIE_LEN_MIN, 2, 10)::type_id::create({ this.get_name(), "seq_send_pkt"});
        seq_discd_pkt   = send_pkt_seq#(CQ_ITEM_WIDTH, PKT_SIZE_MAX, PCIE_LEN_MIN, 2, 5)::type_id::create({ this.get_name(), "seq_discd_pkt"});
        seq_send_pkt.channel = channel;
        seq_discd_pkt.channel = channel;
        seq_send_pkt.init(phase);
        seq_discd_pkt.init(phase);
        seq_start.channel = channel;
        seq_stop.channel  = channel;

        assert(std::randomize(rand_run_count) with {rand_run_count inside {[run_count_min:run_count_max]};});
        `uvm_info(this.get_full_name(), $sformatf("RUN COUNT %d\n", rand_run_count), UVM_DEBUG)

        // forever begin
        for (int unsigned it = 0; it < rand_run_count; it++) begin
            `uvm_info(this.get_full_name(),"START SEQUENCE\n", UVM_DEBUG);
            seq_start.randomize();
            seq_start.start(null);
            `uvm_info(this.get_full_name(),"START SEQUENCE DONE\n", UVM_DEBUG);

            m_watch_dog.channel_status[channel] = 1'b1;

            `uvm_info(this.get_full_name(),"START PACKET\n", UVM_DEBUG);
            fork
                if(!seq_send_pkt.randomize()) `uvm_fatal(this.get_full_name(), "\n\tCannot randomize seq_send_pkt");
                seq_send_pkt.start(p_sequencer);
            join;
            `uvm_info(this.get_full_name(),"END PACKET\n", UVM_DEBUG);

            while(!m_watch_dog.driver_status[channel]) begin
                #(4ns);
            end
            m_watch_dog.channel_status[channel] = 1'b0;

            `uvm_info(this.get_full_name(),"STOP SEQUENCE\n", UVM_DEBUG);
            seq_stop.randomize();
            seq_stop.start(null);
            `uvm_info(this.get_full_name(),"STOP SEQUENCE DONE\n", UVM_DEBUG);

            // Discarding
            `uvm_info(this.get_full_name(),"START DISCARDING\n", UVM_DEBUG);
            fork
                if(!seq_discd_pkt.randomize()) `uvm_fatal(this.get_full_name(), "\n\tCannot randomize seq_discd_pkt");
                seq_discd_pkt.start(p_sequencer);
            join;
            `uvm_info(this.get_full_name(),"END DISCARDING\n", UVM_DEBUG);

            while(!m_watch_dog.driver_status[channel]) begin
                #(4ns);
            end
        end
    endtask

endclass


class reg_sequence#(CQ_ITEM_WIDTH, PKT_SIZE_MAX, PCIE_LEN_MIN) extends uvm_sequence;
    `uvm_object_param_utils(test::reg_sequence#(CQ_ITEM_WIDTH, PKT_SIZE_MAX, PCIE_LEN_MIN))
    `uvm_declare_p_sequencer(uvm_dma_ll_rx::sequencer#(CQ_ITEM_WIDTH, CHANNELS))

    uvm_dma_regs::regmodel#(CHANNELS) m_regmodel;
    uvm_dma_ll_info::watchdog #(CHANNELS) m_watch_dog;

    function new (string name = "run_channel");
        super.new(name);
    endfunction

    task body();
        run_channel#(CQ_ITEM_WIDTH, PKT_SIZE_MAX, PCIE_LEN_MIN) driver[CHANNELS];
        for(int unsigned it = 0; it < CHANNELS; it++) begin
            string it_num;
            it_num.itoa(it);
            driver[it] = run_channel#(CQ_ITEM_WIDTH, PKT_SIZE_MAX, PCIE_LEN_MIN)::type_id::create({"run_channel_", it_num});
            driver[it].m_regmodel = m_regmodel.channel[it];
            driver[it].channel = it;
            driver[it].m_watch_dog = m_watch_dog;
            assert(driver[it].randomize());
        end

        for(int unsigned it = 0; it < CHANNELS; it++) begin
            fork
                automatic int unsigned index = it;
                driver[index].start(p_sequencer.m_data[index]);
            join_none;
        end

        wait fork;
    endtask
endclass

