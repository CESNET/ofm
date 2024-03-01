//-- reg_sequence: register sequence 
//-- Copyright (C) 2024 CESNET z. s. p. o.
//-- Author(s): Radek Iša <isa@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 


class start_channel extends uvm_sequence;
    `uvm_object_utils(uvm_dma_regs::start_channel)

    reg_channel m_regmodel;

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
            #(300ns)
            m_regmodel.status.read(status, data, .parent(this));
        end while ((data & 32'h1) != 1);
    endtask
endclass

/*
class stop_channel extends uvm_sequence;
    `uvm_object_utils(uvm_dma_regs::stop_channel)

    reg_channel m_regmodel;

    function new (string name = "start_channel");
        super.new(name);
    endfunction

    //set base address, mask, pointers
    task body();
        uvm_status_e   status;
        uvm_reg_data_t data;

        //startup channel
        m_regmodel.control.write(status,  32'h0,  .parent(this));
        do begin
            int unsigned sw_data;
            int unsigned hw_data;
            int unsigned sw_hdr;
            int unsigned hw_hdr;
            #(300ns)
            m_regmodel.status.read(status, data, .parent(this));

            m_regmodel.sw_data_pointer.read(status, data, .parent(this));
            sw_data = data;
            m_regmodel.sw_hdr_pointer.read(status, data, .parent(this));
            sw_hdr = data;
            m_regmodel.hw_data_pointer.read(status, data, .parent(this));
            hw_data = data;
            m_regmodel.hw_hdr_pointer.read(status, data, .parent(this));
            hw_hdr = data;
            $write("STOP CHANNEL %s status %0h\n\tsw data %0d hw data %0d sw hdr %0d hw hdr %0d\n", this.get_name(), data, sw_data, hw_data, sw_hdr, hw_hdr);
        end while ((data & 32'h1) != 0);
    endtask
endclass
*/

class stop_channel extends uvm_sequence;
    `uvm_object_utils(uvm_dma_regs::stop_channel)

    reg_channel m_regmodel;

    function new (string name = "start_channel");
        super.new(name);
    endfunction

    //set base address, mask, pointers
    task body();
        uvm_status_e   status;
        uvm_reg_data_t data;

        int unsigned sw_data;
        int unsigned hw_data;
        int unsigned sw_hdr;
        int unsigned hw_hdr;

        do begin
            m_regmodel.sw_data_pointer.read(status, data, .parent(this));
            sw_data = data;
            m_regmodel.sw_hdr_pointer.read(status, data, .parent(this));
            sw_hdr = data;
            m_regmodel.hw_data_pointer.read(status, data, .parent(this));
            hw_data = data;
            m_regmodel.hw_hdr_pointer.read(status, data, .parent(this));
            hw_hdr = data;

            #(200ns);
        end while (sw_data != hw_data || sw_hdr != hw_hdr);

        //startup channel
        m_regmodel.control.write(status,  32'h0,  .parent(this));
        do begin
            #(300ns)
            m_regmodel.status.read(status, data, .parent(this));

        end while ((data & 32'h1) != 0);
    endtask
endclass


