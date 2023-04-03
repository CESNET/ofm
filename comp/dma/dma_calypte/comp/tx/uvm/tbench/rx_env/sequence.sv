//-- sequence.sv
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

// This low level sequence define bus functionality
class logic_vector_array_sequence#(ITEM_WIDTH, CHANNELS) extends uvm_sequence #(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH));
    `uvm_object_param_utils(uvm_dma_ll_rx::logic_vector_array_sequence#(ITEM_WIDTH, CHANNELS))

    mailbox#(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)) tr_export;
    mailbox#(uvm_logic_vector::sequence_item#(17))               tr_sdp_export;
    mailbox#(uvm_logic_vector::sequence_item#($clog2(CHANNELS))) channel_export;
    local uvm_dma_regs::regmodel#(CHANNELS)                      m_regmodel;
    uvm_logic_vector::sequence_item#(17)                         sdp_tr;
    uvm_logic_vector::sequence_item#($clog2(CHANNELS))           chan_tr;

    uvm_dma_ll_info::watchdog #(CHANNELS) m_watch_dog;

    int unsigned channel;

    function new(string name = "sequence_simple_rx_base");
        super.new(name);
    endfunction

    task ptr_read(uvm_reg register, output logic [16-1:0] ptr);
        uvm_status_e   status;
        uvm_reg_data_t data;
        register.read(status, data);
        ptr = data;
    endtask

    task ptr_get(uvm_reg register, output logic [16-1:0] ptr);
        uvm_status_e   status;
        uvm_reg_data_t data;
        data = register.get();
        ptr = data;
    endtask

    task ptr_write(uvm_reg register, logic [16-1:0] ptr);
        uvm_status_e   status;
        uvm_reg_data_t data;

        data = ptr;
        register.write(status, data);
    endtask

    task ptr_update(int unsigned sw_move, uvm_reg hw_register, uvm_reg sw_register, logic hdr);
        logic [16-1 : 0] hw_ptr;
        logic [16-1 : 0] sw_ptr;
        logic [16-1 : 0] sw_mask = 16'h3fff;
        string msg;

        ptr_read(hw_register, hw_ptr);
        ptr_get(sw_register , sw_ptr);

        sw_ptr = sw_ptr & sw_mask;

        while ((((hw_ptr - (sw_ptr + sw_move)) & sw_mask) < sw_move)) begin
            msg = "\n";
            $swrite(msg, "%sTIME%t\nHW PTR %h(%d), SW PTR %h(%d), SW MOVE %h(%d)\n", msg, $time(), hw_ptr, hw_ptr, sw_ptr, sw_ptr, sw_move, sw_move);
            `uvm_info(this.get_full_name(), msg, UVM_DEBUG)
            #(200ns);
            ptr_read(hw_register, hw_ptr);
        end

        ptr_write(sw_register, ((sw_ptr + sw_move) & sw_mask));

    endtask

    function void regmodel_set(uvm_dma_regs::regmodel#(CHANNELS) m_regmodel);
        this.m_regmodel = m_regmodel;
    endfunction

    task body;

        forever begin
            channel_export.get(chan_tr);
            tr_export.get(req);
            tr_sdp_export.get(sdp_tr);
            channel = chan_tr.data;

            start_item(req);
            finish_item(req);

            if (m_watch_dog.channel_status[channel] == 1'b1) begin
                if (sdp_tr.data[16] == 0) begin
                    ptr_update(int'(sdp_tr.data[16-1 : 0]), m_regmodel.channel[int'(channel)].hw_data_pointer, m_regmodel.channel[int'(channel)].sw_data_pointer, sdp_tr.data[16]);
                end else begin
                    ptr_update(int'(sdp_tr.data[16-1 : 0]), m_regmodel.channel[int'(channel)].hw_hdr_pointer, m_regmodel.channel[int'(channel)].sw_hdr_pointer, sdp_tr.data[16]);
                end
            end

            m_watch_dog.binder_cnt[channel]--;

            if (m_watch_dog.binder_cnt[channel] == 0) begin
                if (sdp_tr.data[16] == 1) begin
                    m_watch_dog.driver_status[channel] = 1'b1;
                end
            end else begin
                m_watch_dog.driver_status[channel] = 1'b0;
            end

        end
    endtask
endclass



class logic_vector_sequence#(META_WIDTH, CHANNELS) extends uvm_sequence #(uvm_logic_vector::sequence_item#(META_WIDTH));
    `uvm_object_param_utils(uvm_dma_ll_rx::logic_vector_sequence#(META_WIDTH, CHANNELS))

    mailbox#(uvm_logic_vector::sequence_item#(META_WIDTH)) tr_export;

    function new(string name = "sequence_simple_rx_base");
        super.new(name);
    endfunction

    task body;
        forever begin
            tr_export.get(req);
            start_item(req);
            finish_item(req);
        end
    endtask
endclass

