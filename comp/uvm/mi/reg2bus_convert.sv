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
    `uvm_object_param_utils(uvm_mi::reg2bus_frontdoor#(DATA_WIDTH, ADDR_WIDTH, META_WIDTH))
    `uvm_declare_p_sequencer(uvm_mi::sequencer_slave#(DATA_WIDTH, ADDR_WIDTH, META_WIDTH))

    semaphore sem;
    uvm_reg   target;

    function new(string name = "reg2bus_frontdoor");
        super.new(name);
    endfunction

    function void configure(uvm_reg_map map);
    endfunction

    task read_frame(logic [ADDR_WIDTH-1:0] addr);
        uvm_mi::sequence_item_request #(DATA_WIDTH, ADDR_WIDTH, META_WIDTH)  request;
        request = uvm_mi::sequence_item_request #(DATA_WIDTH, ADDR_WIDTH, META_WIDTH)::type_id::create("request");

        sem.get();
        do begin
            start_item(request);
            request.randomize();

            request.addr = addr;
            request.be   = '1;
            request.dwr  = 'x;
            request.wr   = 0;
            request.rd   = 1'b1;
            finish_item(request);
        end while(request.ardy != 1'b1);
        sem.put();
    endtask

    task get_responses(int unsigned repetition, output bit [`UVM_REG_DATA_WIDTH-1:0] out[]);
        logic [DATA_WIDTH-1:0] data[];
        byte unsigned data_arr[];

        data = new[repetition];
        for (int unsigned it = 0; it < repetition; it++) begin
            uvm_mi::sequence_item_response #(DATA_WIDTH) rsp;
            uvm_sequence_item                       rsp_get;

            get_response(rsp_get);
            $cast(rsp, rsp_get);
            data[it] = rsp.drd;
        end

        data_arr = {<<DATA_WIDTH{ {<<byte{data}}}};

        out = new[(data_arr.size()+`UVM_REG_DATA_WIDTH -1)/`UVM_REG_DATA_WIDTH];
        for (int unsigned it = 0; it < data_arr.size(); it++) begin
            out[it/(`UVM_REG_DATA_WIDTH/8)][(it%(`UVM_REG_DATA_WIDTH/8) + 1)*8-1 -: 8] = data_arr[it];
        end
    endtask


    task send_frame(logic [DATA_WIDTH-1:0] data, logic [ADDR_WIDTH-1:0] addr);
        uvm_mi::sequence_item_request #(DATA_WIDTH, ADDR_WIDTH, META_WIDTH)  request;
        request = uvm_mi::sequence_item_request #(DATA_WIDTH, ADDR_WIDTH, META_WIDTH)::type_id::create("request");

        sem.get();
        do begin
            start_item(request);
            request.randomize();
            request.addr = addr;
            request.be   = '1;
            request.dwr  = data;
            request.wr   = 1'b1;
            request.rd   = 1'b0;
            finish_item(request);
        end while(request.ardy != 1'b1);
        sem.put();
    endtask

    task body();
        int unsigned repetition;
        logic [ADDR_WIDTH-1:0] addr;

        ////////////
        // get semaphore
        if (uvm_config_db#(semaphore)::get(sequencer, "", "sem", sem) == 0) begin
            sem = new(1);
            uvm_config_db#(semaphore)::set(sequencer, "", "sem", sem);
        end

        ////////////
        // send request
        if (rw_info.element_kind != UVM_REG) begin
             `uvm_fatal(p_sequencer.get_full_name(), "\n\tThis sequence support only access to UVM_REG");
        end

        if (!$cast(target, rw_info.element)) begin
            `uvm_fatal(p_sequencer.get_full_name(), "\n\tCannot get register");
        end

        repetition = (target.get_n_bits()+DATA_WIDTH-1) /DATA_WIDTH;
        addr = target.get_address();
        //WRITE DATA
        if (rw_info.kind == UVM_WRITE) begin
            logic [DATA_WIDTH-1:0] data_array[];
            data_array = {<<DATA_WIDTH{rw_info.value}};
            for(int unsigned it = 0; it < repetition; it++) begin
                send_frame(data_array[it], addr + (DATA_WIDTH/8)*it);
            end
        //READ DATA
        end else if (rw_info.kind == UVM_READ) begin
            for(int unsigned it = 0; it < repetition; it++) begin
                read_frame(addr + (DATA_WIDTH/8)*it);
            end
            get_responses(repetition, rw_info.value);
        end
    endtask
endclass



class reg2bus_adapter#(DATA_WIDTH, ADDR_WIDTH, META_WIDTH = 0) extends uvm_reg_adapter;
    `uvm_object_param_utils(uvm_mi::reg2bus_adapter#(DATA_WIDTH, ADDR_WIDTH, META_WIDTH))

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
           `uvm_fatal("mi::reg2bus_adapter", "\n\tCanont convert uvm_sequence_item to uvm_mi::response");
        end
        rw = item.op;
    endfunction
endclass
