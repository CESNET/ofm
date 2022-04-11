/*
 * file       : reg2bus_convert.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: this classes convert reg transaction to mi transactions 
 * date       : 2021
 * author     : Radek Iša <isa@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/

class reg2bus_frontdoor #(DATA_WIDTH, ADDR_WIDTH, META_WIDTH = 0) extends uvm_reg_frontdoor;
    `uvm_object_param_utils(mi::reg2bus_frontdoor#(DATA_WIDTH, ADDR_WIDTH, META_WIDTH))
    `uvm_declare_p_sequencer(mi::sequencer_slave#(DATA_WIDTH, ADDR_WIDTH, META_WIDTH))

    function new(string name = "reg2bus_frontdoor");
        super.new(name);
    endfunction

    function void configure(uvm_reg_map map);
    endfunction

    task body();
        mi::sequence_item_request #(DATA_WIDTH, ADDR_WIDTH, META_WIDTH)  request;
        uvm_reg      target;

        if (rw_info.element_kind != UVM_REG) begin
             `uvm_fatal(p_sequencer.get_full_name(), "\n\tThis sequence support only access to UVM_REG");
        end

        if (!$cast(target, rw_info.element)) begin
            `uvm_fatal(p_sequencer.get_full_name(), "\n\tCannot get register");
        end

        request = mi::sequence_item_request #(DATA_WIDTH, ADDR_WIDTH, META_WIDTH)::type_id::create("request");
        do begin
            start_item(request);
            request.randomize();

            request.addr = target.get_address();
            request.be   = '1;
            request.wr   = 0;
            request.rd   = 0;

            if (rw_info.kind == UVM_WRITE) begin
                request.dwr  = rw_info.value[0]; // 64 bit width
                request.wr   = 1'b1;
            end else if (rw_info.kind == UVM_READ) begin
                request.dwr  = 'x;
                request.rd   = 1'b1;
            end
            finish_item(request);
        end while(request.ardy != 1'b1);
    endtask
endclass



class reg2bus_adapter#(DATA_WIDTH, ADDR_WIDTH, META_WIDTH = 0) extends uvm_reg_adapter;
    `uvm_object_param_utils(mi::reg2bus_adapter#(DATA_WIDTH, ADDR_WIDTH, META_WIDTH))

    function new(string name = "reg2mi_adapter");
        super.new(name);
    endfunction

    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        `uvm_fatal("mi::reg2bus_adapter::reg2bus", "\n\tThis adapter use frontend sequence");
    endfunction


    virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        reg2bus_class item;
        string text;

        if(!$cast(item, bus_item)) begin
           `uvm_fatal("mi::reg2bus_adapter", "\n\tCanont convert uvm_sequence_item to mi::response");
        end
        rw = item.op;
    endfunction
endclass
