//-- reg_channel.sv: Registre model for one channel 
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

class reg_channel extends uvm_reg_block;
    `uvm_object_utils(uvm_dma_ll::reg_channel)

    rand uvm_dma_ll::control_register     control;
    rand uvm_dma_ll::status_register      status;
    rand uvm_dma_ll::fifo_status_register data_fifo_status;
    rand uvm_dma_ll::fifo_status_register hdr_fifo_status;
    rand uvm_dma_ll::fifo_status_register data_fifo_depth;
    rand uvm_dma_ll::fifo_status_register hdr_fifo_depth;
    rand uvm_dma_ll::cnt_register         sent_packets;
    rand uvm_dma_ll::cnt_register         discarded_packets;
    rand uvm_dma_ll::cnt_register         sent_bytes;
    rand uvm_dma_ll::cnt_register         discarded_bytes;

    function new(string name = "reg_block");
        super.new(name, build_coverage(UVM_NO_COVERAGE));
    endfunction

    function void set_frontdoor(uvm_reg_frontdoor frontdoor);
        control.set_frontdoor(frontdoor.clone());
        status.set_frontdoor(frontdoor.clone());
        data_fifo_status.set_frontdoor(frontdoor.clone());
        hdr_fifo_status.set_frontdoor(frontdoor.clone());
        data_fifo_depth.set_frontdoor(frontdoor.clone());
        hdr_fifo_depth.set_frontdoor(frontdoor.clone());
        sent_packets.set_frontdoor(frontdoor.clone());
        sent_bytes.set_frontdoor(frontdoor.clone());
        discarded_packets.set_frontdoor(frontdoor.clone());
        discarded_bytes.set_frontdoor(frontdoor.clone());
    endfunction

    virtual function void build(uvm_reg_addr_t base, int unsigned bus_width);
        //CREATE
        control = control_register::type_id::create("control");
        status  = status_register::type_id::create("status");
        data_fifo_status = uvm_dma_ll::fifo_status_register::type_id::create("data_fifo_status");
        hdr_fifo_status  = uvm_dma_ll::fifo_status_register::type_id::create("hdr_fifo_status");
        data_fifo_depth = uvm_dma_ll::fifo_status_register::type_id::create("data_fifo_depth");
        hdr_fifo_depth  = uvm_dma_ll::fifo_status_register::type_id::create("hdr_fifo_depth");
        sent_packets = uvm_dma_ll::cnt_register::type_id::create("sent_packets");
        sent_bytes  = uvm_dma_ll::cnt_register::type_id::create("sent_bytes");
        discarded_bytes   = uvm_dma_ll::cnt_register::type_id::create("discarded_bytes");
        discarded_packets  = uvm_dma_ll::cnt_register::type_id::create("discarded_packets");
        //BUILD and CONFIGURE register
        control.build();
        status.build();
        data_fifo_status.build();
        hdr_fifo_status.build();
        data_fifo_depth.build();
        hdr_fifo_depth.build();
        sent_packets.build();
        discarded_packets.build();
        sent_bytes.build();
        discarded_bytes.build();

        control.configure(this);
        status.configure(this);
        data_fifo_status.configure(this);
        hdr_fifo_status.configure(this);
        data_fifo_depth.configure(this);
        hdr_fifo_depth.configure(this);
        sent_packets.configure(this);
        discarded_packets.configure(this);
        sent_bytes.configure(this);
        discarded_bytes.configure(this);

        //create map
        this.default_map = create_map("MAP", base, bus_width/8, UVM_LITTLE_ENDIAN);
        //Add registers to map
        this.default_map.add_reg(control          , 'h00, "RW");
        this.default_map.add_reg(status           , 'h04, "RO");
        this.default_map.add_reg(data_fifo_status , 'h10, "RO");
        this.default_map.add_reg(hdr_fifo_status  , 'h14, "RO");
        this.default_map.add_reg(data_fifo_depth  , 'h58, "RO");
        this.default_map.add_reg(hdr_fifo_depth   , 'h5C, "RO");
        this.default_map.add_reg(sent_packets     , 'h60, "RW");
        this.default_map.add_reg(sent_bytes       , 'h68, "RW");
        this.default_map.add_reg(discarded_packets, 'h70, "RW");
        this.default_map.add_reg(discarded_bytes  , 'h78, "RW");

        this.lock_model();
    endfunction
endclass
