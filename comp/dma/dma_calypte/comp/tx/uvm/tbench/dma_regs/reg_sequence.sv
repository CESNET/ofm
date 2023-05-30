//-- reg_sequence: register sequence 
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 


class start_channel extends uvm_sequence;
    `uvm_object_utils(uvm_dma_regs::start_channel)

    reg_channel m_regmodel;

    rand logic [64-1:0] data_base_addr;
    rand logic [64-1:0] hdr_base_addr;

    function new (string name = "start_channel");
        super.new(name);
    endfunction

    //set base address, mask, pointers
    task body();
        uvm_status_e   status;
        uvm_reg_data_t data;

        //Randomize sequence of doing this
        //write sw_pointers
        m_regmodel.sw_data_pointer.write(status, 'h0, .parent(this));
        m_regmodel.sw_hdr_pointer.write(status,  'h0, .parent(this));

        //startup channel
        m_regmodel.control.write(status,  32'h1,  .parent(this));
        do begin
            `uvm_info(this.get_full_name(), "\nSTARTING CHANNEL" ,UVM_NONE)
            #(300ns)
            m_regmodel.status.read(status, data, .parent(this));
        end while ((data & 32'h1) == 0);
    endtask
endclass

// class pointer_update extends uvm_sequence;
//     `uvm_object_utils(uvm_dma_regs::pointer_update)

//     reg_channel m_regmodel;

//     function new (string name = "stop_channel");
//         super.new(name);
//     endfunction

//     task hw_ptr_read(uvm_reg register, output logic [16-1:0] ptr);
//         uvm_status_e   status;
//         uvm_reg_data_t data;
//         register.read(status, data, .parent(this));
//         ptr = data;
//     endtask

//     task hw_ptr_write(uvm_reg register, logic [16-1:0] ptr);
//         uvm_status_e   status;
//         uvm_reg_data_t data;

//         data = ptr;
//         register.write(status, data, .parent(this));
//     endtask


//     task body();
//         logic [16-1:0] hdp;
//         logic [16-1:0] hhp;
//         logic [16-1:0] sdp;
//         logic [16-1:0] shp;
//         logic [16-1:0] sdp_mask;
//         logic [16-1:0] shp_mask;
//         logic [16-1:0] sdp_move;
//         logic [16-1:0] shp_move;

//         //startup channel
//         sdp_mask = m_regmodel.data_mask.get();
//         shp_mask = m_regmodel.hdr_mask.get();
//         sdp      = m_regmodel.sw_data_pointer.get();
//         shp      = m_regmodel.sw_hdr_pointer.get();

//         //It could be helpfull back door access. To setup clousest sw pointer as posible.
//         fork
//             hw_ptr_read(m_regmodel.hw_data_pointer, hdp);
//             hw_ptr_read(m_regmodel.hw_hdr_pointer,  hhp);
//         join;

//         //randomize sw pointer.
//         sdp_move = $urandom_range((hdp - sdp) & sdp_mask);
//         shp_move = $urandom_range((hhp - shp) & shp_mask);
//         //sdp_move = (hdp - sdp) & sdp_mask;
//         //shp_move = (hhp - shp) & shp_mask;
//         //It could be helpfull back door access. To setup clousest sw pointer as posible.

//         fork
//             hw_ptr_write(m_regmodel.sw_data_pointer, (sdp + sdp_move) & sdp_mask);
//             hw_ptr_write(m_regmodel.sw_hdr_pointer,  (shp + shp_move) & shp_mask);
//         join;
//     endtask
// endclass

class stop_channel extends uvm_sequence;
    `uvm_object_utils(uvm_dma_regs::stop_channel)
    //  pointer_update seq_update;

    reg_channel m_regmodel;

    function new (string name = "stop_channel");
        super.new(name);
    endfunction

    task body();
        uvm_status_e   status;
        uvm_reg_data_t data;

        // seq_update = pointer_update::type_id::create({this.get_name(), "_pointer_update"});
        // seq_update.m_regmodel = m_regmodel;

        //startup channel
        m_regmodel.control.write(status, 32'h0, .parent(this));
        do begin
            `uvm_info(this.get_full_name(), "\nCHANNEL STOPPED" ,UVM_MEDIUM)
            #(300ns)
            // seq_update.randomize();
            // seq_update.start(null);
            m_regmodel.status.read(status, data, .parent(this));
        end while ((data & 32'h1) == 1);
    endtask
endclass


class run_channel extends uvm_sequence;
    `uvm_object_utils(uvm_dma_regs::run_channel)

    rand time run_time  = 40ns;
    time stop_time = 10ns;
    time update_time = 20ns;

    time update_time_min = 300ns;
    time update_time_max = 1us;

    time run_time_min = 30us;
    time run_time_max = 500us;

    time stop_time_min = 6us;
    time stop_time_max = 30us;

    reg_channel m_regmodel;
    enum int unsigned { STOPPED = 0, RUNNING = 1, STARTING = 2} state;

    task mask_read(uvm_reg register);
        uvm_status_e   status;
        uvm_reg_data_t data;
        register.read(status, data, .parent(this));
    endtask

    function new (string name = "run_channel");
        super.new(name);
    endfunction

    // task body();
    //     //forever begin
    //     for (int unsigned it = 0; it < rand_run_count; it++) begin
    //         seq_start.randomize();
    //         seq_start.start();

    //         seq_send_pkt.sync   = sync_obj;
    //         seq_send_pkt.randomize();
    //         seq_ptr_change.sync = sync_obj;
    //         seq_ptr_change.randomize();

    //         fork
    //             seq_send_pkt.start(m_seqcr.seqr_pkt);
    //         join;

    //         seq_stop.randomize();
    //         seq_stop.start();
    //     end
    // endtask

    task body();
        start_channel  seq_start;
        stop_channel   seq_stop;
        stop_channel   seq_send_pkt;
        // pointer_update seq_update;
        time start_time;

        seq_start  = start_channel::type_id::create({ this.get_name(), "_seq_start"});
        seq_start.m_regmodel = m_regmodel;
        seq_stop   = stop_channel::type_id::create({ this.get_name(), "seq_stop"});
        seq_stop.m_regmodel = m_regmodel;
        // seq_update = pointer_update::type_id::create({ this.get_name(), "pointer_update"});
        // seq_update.m_regmodel = m_regmodel;

        //startup channel
        forever begin
            seq_start.randomize();
            seq_start.start(null);
            start_time = $time();
            assert(std::randomize(run_time) with {run_time inside {[run_time_min:run_time_max]};});

            mask_read(m_regmodel.data_mask);
            mask_read(m_regmodel.hdr_mask);

            while ($time() < (start_time + run_time)) begin
                assert(std::randomize(update_time) with {update_time inside {[update_time_min:update_time_max]};});
                #(update_time);
                // seq_update.randomize();
                // seq_update.start(null);
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
    `uvm_object_param_utils(uvm_dma_regs::reg_sequence#(CHANNELS))

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

