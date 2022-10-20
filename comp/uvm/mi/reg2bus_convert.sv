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

    localparam DATA_BYTES_WIDTH = (DATA_WIDTH+8-1)/8;

    typedef struct {
        logic [ADDR_WIDTH-1:0]   addr;
        logic [DATA_WIDTH-1:0]   data;
        logic [DATA_BYTES_WIDTH-1:0] be;
    } item_t;

    semaphore sem;

    function new(string name = "reg2bus_frontdoor");
        super.new(name);
    endfunction

    function void configure(uvm_reg_map map);
    endfunction

    task read_frame(logic [ADDR_WIDTH-1:0] addr, logic [DATA_BYTES_WIDTH-1:0] be);
        uvm_mi::sequence_item_request #(DATA_WIDTH, ADDR_WIDTH, META_WIDTH)  request;
        request = uvm_mi::sequence_item_request #(DATA_WIDTH, ADDR_WIDTH, META_WIDTH)::type_id::create("request");

        sem.get();
        do begin
            start_item(request);
            request.randomize();

            request.addr = addr;
            request.be   = be;
            request.dwr  = 'x;
            request.wr   = 0;
            request.rd   = 1'b1;
            finish_item(request);
        end while(request.ardy != 1'b1);
        sem.put();
    endtask

    task get_responses(output logic [DATA_WIDTH-1:0] out);
        uvm_mi::sequence_item_response #(DATA_WIDTH) rsp;
        uvm_sequence_item                            rsp_get;

        get_response(rsp_get);
        $cast(rsp, rsp_get);
        out = rsp.drd;
    endtask

    task send_frame(logic [DATA_WIDTH-1:0] data, logic [DATA_BYTES_WIDTH-1:0] be, logic [ADDR_WIDTH-1:0] addr);
        uvm_mi::sequence_item_request #(DATA_WIDTH, ADDR_WIDTH, META_WIDTH)  request;
        request = uvm_mi::sequence_item_request #(DATA_WIDTH, ADDR_WIDTH, META_WIDTH)::type_id::create("request");

        sem.get();
        do begin
            start_item(request);
            request.randomize();
            request.addr = addr;
            request.be   = be;
            request.dwr  = data;
            request.wr   = 1'b1;
            request.rd   = 1'b0;
            finish_item(request);
        end while(request.ardy != 1'b1);
        sem.put();
    endtask

    task body();
        item_t items[];
        int unsigned target_width;
        logic [ADDR_WIDTH-1:0] addr;

        //set status to OK
        rw_info.status = UVM_IS_OK;

        ////////////
        // get semaphore
        if (uvm_config_db#(semaphore)::get(sequencer, "", "sem", sem) == 0) begin
            sem = new(1);
            uvm_config_db#(semaphore)::set(sequencer, "", "sem", sem);
        end

        ///////////////////
        // GET ELEMENT INFO
        if (rw_info.element_kind == UVM_MEM) begin
            uvm_mem target;
            int unsigned item_num; // required words in interface

            if (!$cast(target, rw_info.element)) begin
                `uvm_fatal(p_sequencer.get_full_name(), "\n\tCannot get memmory");
            end

            target_width = target.get_n_bits();
            item_num     = (target_width*rw_info.value.size() + DATA_WIDTH -1)/DATA_WIDTH;
            addr         = target.get_address() + rw_info.offset;
            items        = new[item_num];
        end else if (rw_info.element_kind == UVM_REG) begin
            uvm_reg target;
            int unsigned item_num; // required words in interface

            if (!$cast(target, rw_info.element)) begin
                `uvm_fatal(p_sequencer.get_full_name(), "\n\tCannot get register");
            end

            target_width = target.get_n_bits();
            item_num     = (target_width + DATA_WIDTH -1)/DATA_WIDTH;
            addr         = target.get_address();
            items        = new[item_num];
        end else begin
             `uvm_fatal(p_sequencer.get_full_name(), "\n\tThis sequence support only access to UVM_REG and UVM_MEM");
        end


        /////////////////////////////
        // OPERATION
        // PICK OPERATION
        if (rw_info.kind == UVM_WRITE || rw_info.kind == UVM_BURST_WRITE ) begin
            int unsigned item_index_low;
            int unsigned item_index_high;
            logic [ADDR_WIDTH-1:0] addr_local = addr;

            item_index_low  = 0;
            item_index_high = 0;
            for (int unsigned it = 0; it < rw_info.value.size(); it++) begin
                for (int unsigned jt = 0; jt < target_width; jt += 8) begin
                    if (item_index_low == 0) begin
                        items[item_index_high].addr = addr_local;
                        addr_local                 += DATA_BYTES_WIDTH;
                    end

                    items[item_index_high].data[(item_index_low+1)*8-1 -: 8] = rw_info.value[it][(jt+8)-1 -: 8];
                    items[item_index_high].be[item_index_low]        = 1'b1;

                    item_index_low += 1;
                    if (item_index_low >= DATA_BYTES_WIDTH) begin
                        item_index_low = 0;
                        item_index_high++;
                    end
                end
            end
            //write last addres
            items[items.size()-1].addr = addr_local;

            //Send frames
            for(int unsigned it = 0; it < items.size(); it++) begin
                send_frame(items[it].data,  items[it].be, items[it].addr);
            end
        end else if (rw_info.kind == UVM_READ  || rw_info.kind == UVM_BURST_READ) begin
            logic [ADDR_WIDTH-1:0] addr_local = addr;
            int unsigned item_index_low;
            int unsigned item_index_high;
            //prepare address
            for(int unsigned it = 0; it < items.size(); it++) begin
                items[it].addr = addr_local;
                addr_local    += DATA_BYTES_WIDTH;
                items[it].be   = '1;
            end

            // send and receive frames
            fork
                for(int unsigned it = 0; it < items.size(); it++) begin
                    read_frame(items[it].addr, items[it].be);
                end
                for(int unsigned it = 0; it < items.size(); it++) begin
                    get_responses(items[it].data);
                end
            join

            // Format change
            item_index_low  = 0;
            item_index_high = 0;
            for (int unsigned it = 0; it < rw_info.value.size(); it++) begin
                for (int unsigned jt = 0; jt < target_width; jt += 8) begin
                    rw_info.value[it][(jt+8)-1 -: 8] = items[item_index_high].data[(item_index_low +1)*8-1 -: 8];

                    item_index_low += 1;
                    if (item_index_low >= DATA_BYTES_WIDTH) begin
                        item_index_low = 0;
                        item_index_high++;
                    end
                end
            end
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
         return null;
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
