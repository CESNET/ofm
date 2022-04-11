/*
 * file       : draiver.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: mi driver (slave master)
 * date       : 2021
 * author     : Radek Iša <isa@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/

class driver_slave #(DATA_WIDTH, ADDR_WIDTH, META_WIDTH = 0) extends uvm_driver #(sequence_item_request #(DATA_WIDTH, ADDR_WIDTH, META_WIDTH));

    // Register component to database.
    `uvm_component_param_utils(mi::driver_slave #(DATA_WIDTH, ADDR_WIDTH, META_WIDTH))

    // Virtual interface of driver
    virtual mi_if #(DATA_WIDTH, ADDR_WIDTH, META_WIDTH).tb_slave vif;

    // Contructor of driver which contains name and parent component.
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Run - starts the processing in driver
    task run_phase(uvm_phase phase);
        forever begin
            // Pull sequence item (transaction) from the low level sequencer.
            seq_item_port.try_next_item(req);
            if (req != null) begin
                vif.cb_slave.ADDR  <= req.addr;
                vif.cb_slave.BE    <= req.be;
                vif.cb_slave.WR    <= req.wr;
                vif.cb_slave.DWR   <= req.dwr;
                vif.cb_slave.META   <= req.meta;
                vif.cb_slave.RD    <= req.rd;
                //seq_item_port.item_done();
            end else begin
                vif.cb_slave.ADDR  <= 'x;
                vif.cb_slave.BE    <= 'x;
                vif.cb_slave.WR    <= 1'b0;
                vif.cb_slave.DWR   <= 'x;
                vif.cb_slave.META   <= 'x;
                vif.cb_slave.RD    <= 1'b0;
            end

            @(vif.cb_slave);

            if (req != null) begin
                req.ardy = vif.cb_slave.ARDY;
                seq_item_port.item_done();
            end
        end
    endtask
endclass

class driver_master #(DATA_WIDTH, ADDR_WIDTH, META_WIDTH = 0) extends uvm_driver #(sequence_item_respons #(DATA_WIDTH), sequence_item_request #(DATA_WIDTH, ADDR_WIDTH, META_WIDTH));
    // Register component to database.
    `uvm_component_param_utils(mi::driver_master#(DATA_WIDTH, ADDR_WIDTH, META_WIDTH))

    // Virtual interface of driver
    virtual mi_if #(DATA_WIDTH, ADDR_WIDTH, META_WIDTH).tb_master vif;

    // Contructor of driver which contains name and parent component.
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Run - starts the processing in driver
    task run_phase(uvm_phase phase);
        rsp = sequence_item_request #(DATA_WIDTH, ADDR_WIDTH, META_WIDTH)::type_id::create("mi_master");
        forever begin
            // Pull sequence item (transaction) from the low level sequencer.
            seq_item_port.try_next_item(req);
            if (req != null) begin
                vif.cb_master.DRD  <= req.drd;
                vif.cb_master.ARDY <= req.ardy;
                vif.cb_master.DRDY <= req.drdy;
            end else begin
                vif.cb_master.DRD  <= 'x;
                vif.cb_master.ARDY <= 1'b0;
                vif.cb_master.DRDY <= 1'b0;
            end
            @(vif.cb_master);

            if (req != null) begin
                rsp.addr = vif.cb_master.ADDR;
                rsp.be   = vif.cb_master.BE;
                rsp.wr   = vif.cb_master.WR;
                rsp.dwr  = vif.cb_master.DWR;
                rsp.meta = vif.cb_master.META;
                rsp.rd   = vif.cb_master.RD;
                rsp.ardy = req.ardy;
                rsp.set_id_info(req);
                seq_item_port.item_done(rsp);
            end
        end
    endtask
endclass

