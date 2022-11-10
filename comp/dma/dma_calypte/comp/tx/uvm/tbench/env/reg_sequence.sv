//-- reg_sequence: register sequence 
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 


class start_channel extends uvm_sequence;
    `uvm_object_utils(uvm_dma_ll::start_channel)

    reg_channel m_regmodel;

    function new (string name = "start_channel");
        super.new(name);
    endfunction

    //set base address, mask, pointers
    task body();
        uvm_status_e   status;
        uvm_reg_data_t data;

        //startup channel
        m_regmodel.control.write(status,  32'h1,  .parent(this));
        do begin
            `uvm_info(this.get_full_name(), "\nSTARTING CHANNEL" ,UVM_MEDIUM)
            #(300ns)
            m_regmodel.status.read(status, data, .parent(this));
        end while ((data & 32'h1) == 0);
    endtask
endclass

class stop_channel extends uvm_sequence;
    `uvm_object_utils(uvm_dma_ll::stop_channel)
    //  pointer_update  seq_update;

    reg_channel m_regmodel;

    function new (string name = "stop_channel");
        super.new(name);
    endfunction

    task body();
        uvm_status_e   status;
        uvm_reg_data_t data;

        //startup channel
        m_regmodel.control.write(status, 32'h0, .parent(this));
        do begin
            `uvm_info(this.get_full_name(), "\nCHANNEL STOPPED" ,UVM_MEDIUM)
            #(300ns)
            m_regmodel.status.read(status, data, .parent(this));
        end while ((data & 32'h1) == 1);
    endtask
endclass


class run_channel extends uvm_sequence;
    `uvm_object_utils(uvm_dma_ll::run_channel)

    rand time run_time  = 40ns;
    time stop_time = 10ns;
    time update_time = 20ns;

    time update_time_min = 300ns;
    time update_time_max = 2us;

    time run_time_min = 30us;
    time run_time_max = 1ms;

    time stop_time_min = 30us;
    time stop_time_max = 1ms;

    reg_channel m_regmodel;


    function new (string name = "run_channel");
        super.new(name);
    endfunction

    task body();
        start_channel   seq_start;
        stop_channel    seq_stop;
        time start_time;

        seq_start  = start_channel::type_id::create({ this.get_name(), "_seq_start"});
        seq_start.m_regmodel = m_regmodel;
        seq_stop   = stop_channel::type_id::create({ this.get_name(), "seq_stop"});
        seq_stop.m_regmodel = m_regmodel;

        //startup channel
        forever begin
            seq_start.randomize();
            seq_start.start(null);
            start_time = $time();
            assert(std::randomize(run_time) with {run_time inside {[run_time_min:run_time_max]};});
            while ($time() < (start_time + run_time)) begin
                assert(std::randomize(update_time) with {update_time inside {[update_time_min:update_time_max]};});
                #(update_time);
            end
            //never happen because forever begin
            seq_stop.randomize();
            seq_stop.start(null);
            assert(std::randomize(stop_time) with {stop_time inside {[stop_time_min:stop_time_max]};});
            #(stop_time);
        end
    endtask
endclass



class reg_sequence#(CHANNELS) extends uvm_sequence;
    `uvm_object_param_utils(uvm_dma_ll::reg_sequence#(CHANNELS))

    regmodel#(CHANNELS) m_regmodel;

    function new (string name = "run_channel");
        super.new(name);
    endfunction

    task body();
        run_channel driver[CHANNELS];
        for(int unsigned it = 0; it < CHANNELS; it++) begin
            string it_num;
            it_num.itoa(it);
            driver[it] = run_channel::type_id::create({"run_channel_", it_num});
            driver[it].m_regmodel = m_regmodel.channel[it];
            assert(driver[it].randomize());
        end

        for(int unsigned it = 0; it < CHANNELS; it++) begin
            fork
                automatic int unsigned index = it;
                driver[index].start(null);
            join_none;
        end

        wait fork;
    endtask
endclass

