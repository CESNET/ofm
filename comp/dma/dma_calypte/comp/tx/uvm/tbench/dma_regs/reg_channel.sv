//-- reg_channel.sv: Registre model for one channel 
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

class reg_channel extends uvm_reg_block;
    `uvm_object_utils(uvm_dma_regs::reg_channel)

    rand uvm_dma_regs::control_register control;
    rand uvm_dma_regs::status_register  status;
    rand uvm_dma_regs::pointer_register sw_data_pointer;
    rand uvm_dma_regs::pointer_register sw_hdr_pointer;
    rand uvm_dma_regs::pointer_register hw_data_pointer;
    rand uvm_dma_regs::pointer_register hw_hdr_pointer;
    rand uvm_dma_regs::addr_register    data_base;
    rand uvm_dma_regs::addr_register    hdr_base;
    rand uvm_dma_regs::pointer_register data_mask;
    rand uvm_dma_regs::pointer_register hdr_mask;
    rand uvm_dma_regs::cnt_register     sent_packets;
    rand uvm_dma_regs::cnt_register     discarded_packets;
    rand uvm_dma_regs::cnt_register     sent_bytes;
    rand uvm_dma_regs::cnt_register     discarded_bytes;

    function new(string name = "reg_block");
        super.new(name, build_coverage(UVM_NO_COVERAGE));
    endfunction

    function void set_frontdoor(uvm_reg_frontdoor frontdoor);
        uvm_reg_frontdoor c_frontdoor;
        $cast(c_frontdoor, frontdoor.clone());
        control.set_frontdoor(c_frontdoor);
        $cast(c_frontdoor, frontdoor.clone());
        status.set_frontdoor(c_frontdoor);
        $cast(c_frontdoor, frontdoor.clone());
        sw_data_pointer.set_frontdoor(c_frontdoor);
        $cast(c_frontdoor, frontdoor.clone());
        sw_hdr_pointer.set_frontdoor(c_frontdoor);
        $cast(c_frontdoor, frontdoor.clone());
        hw_data_pointer.set_frontdoor(c_frontdoor);
        $cast(c_frontdoor, frontdoor.clone());
        hw_hdr_pointer.set_frontdoor(c_frontdoor);
        $cast(c_frontdoor, frontdoor.clone());
        data_base.set_frontdoor(c_frontdoor);
        $cast(c_frontdoor, frontdoor.clone());
        hdr_base.set_frontdoor(c_frontdoor);
        $cast(c_frontdoor, frontdoor.clone());
        data_mask.set_frontdoor(c_frontdoor);
        $cast(c_frontdoor, frontdoor.clone());
        hdr_mask.set_frontdoor(c_frontdoor);
        $cast(c_frontdoor, frontdoor.clone());
        sent_packets.set_frontdoor(c_frontdoor);
        $cast(c_frontdoor, frontdoor.clone());
        sent_bytes.set_frontdoor(c_frontdoor);
        $cast(c_frontdoor, frontdoor.clone());
        discarded_packets.set_frontdoor(c_frontdoor);
        $cast(c_frontdoor, frontdoor.clone());
        discarded_bytes.set_frontdoor(c_frontdoor);
    endfunction

    virtual function void build(uvm_reg_addr_t base, int unsigned bus_width);
        //CREATE
        control           = control_register::type_id::create("control");
        status            = status_register::type_id::create("status");
        sw_data_pointer   = uvm_dma_regs::pointer_register::type_id::create("sw_data_pointer");
        sw_hdr_pointer    = uvm_dma_regs::pointer_register::type_id::create("sw_hdr_pointer");
        hw_data_pointer   = uvm_dma_regs::pointer_register::type_id::create("hw_data_pointer");
        hw_hdr_pointer    = uvm_dma_regs::pointer_register::type_id::create("hw_hdr_pointer");
        data_base         = uvm_dma_regs::addr_register::type_id::create("data_base");
        hdr_base          = uvm_dma_regs::addr_register::type_id::create("hdr_base");
        data_mask         = uvm_dma_regs::pointer_register::type_id::create("data_mask");
        hdr_mask          = uvm_dma_regs::pointer_register::type_id::create("hdr_mask");
        sent_packets      = uvm_dma_regs::cnt_register::type_id::create("sent_packets");
        sent_bytes        = uvm_dma_regs::cnt_register::type_id::create("sent_bytes");
        discarded_bytes   = uvm_dma_regs::cnt_register::type_id::create("discarded_bytes");
        discarded_packets = uvm_dma_regs::cnt_register::type_id::create("discarded_packets");
        //BUILD and CONFIGURE register
        control.build();
        status.build();
        sw_data_pointer.build();
        sw_hdr_pointer.build();
        hw_data_pointer.build();
        hw_hdr_pointer.build();
        data_base.build();
        hdr_base.build();
        data_mask.build();
        hdr_mask.build();
        sent_packets.build();
        discarded_packets.build();
        sent_bytes.build();
        discarded_bytes.build();

        control.configure(this);
        status.configure(this);
        sw_data_pointer.configure(this);
        sw_hdr_pointer.configure(this);
        hw_data_pointer.configure(this);
        hw_hdr_pointer.configure(this);
        data_base.configure(this);
        hdr_base.configure(this);
        data_mask.configure(this);
        hdr_mask.configure(this);
        sent_packets.configure(this);
        discarded_packets.configure(this);
        sent_bytes.configure(this);
        discarded_bytes.configure(this);

        //create map
        this.default_map = create_map("MAP", base, bus_width/8, UVM_LITTLE_ENDIAN);
        //Add registers to map
        this.default_map.add_reg(control          , 'h00, "RW");
        this.default_map.add_reg(status           , 'h04, "RO");

        this.default_map.add_reg(sw_data_pointer  , 'h10, "RW");
        this.default_map.add_reg(sw_hdr_pointer   , 'h14, "RW");
        this.default_map.add_reg(hw_data_pointer  , 'h18, "RO");
        this.default_map.add_reg(hw_hdr_pointer   , 'h1C, "RO");

        this.default_map.add_reg(data_base        , 'h40, "RW");
        this.default_map.add_reg(hdr_base         , 'h48, "RW");
        this.default_map.add_reg(data_mask        , 'h58, "RW");
        this.default_map.add_reg(hdr_mask         , 'h5C, "RW");

        this.default_map.add_reg(sent_packets     , 'h60, "RW");
        this.default_map.add_reg(sent_bytes       , 'h68, "RW");
        this.default_map.add_reg(discarded_packets, 'h70, "RW");
        this.default_map.add_reg(discarded_bytes  , 'h78, "RW");

        this.lock_model();
    endfunction
endclass
