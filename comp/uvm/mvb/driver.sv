//-- driver.sv: Mvb driver
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

`ifndef MVB_DRIVER
`define MVB_DRIVER

// Driver of mvb rx interface
class driver_rx #(ITEMS, ITEM_WIDTH) extends uvm_driver #(sequence_item #(ITEMS, ITEM_WIDTH));

    // ------------------------------------------------------------------------
    // Register component to database
    `uvm_component_param_utils(mvb::driver_rx #(ITEMS, ITEM_WIDTH))

    // ------------------------------------------------------------------------
    // Variables
    sequence_item #(ITEMS, ITEM_WIDTH) rsp;

    // ------------------------------------------------------------------------
    // Virtual interface of rx driver
    virtual mvb_if #(ITEMS, ITEM_WIDTH).driver_rx vif;

    // ------------------------------------------------------------------------
    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // ------------------------------------------------------------------------
    // Starts driving signals to interface
    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.try_next_item(req);

            if (req != null) begin
                //vif.DATA    <= {<<ITEMS{req.DATA}};   // TODO - remove comment and for if parametrized packed operator works correctly in modelsim

                for (int i = 0 ; i < ITEMS ; i++ ) begin
                    vif.driver_rx_cb.DATA[(i+1)*ITEM_WIDTH -1 -: ITEM_WIDTH] <= req.DATA[i];
                end
                vif.driver_rx_cb.VLD     <= req.VLD;
                vif.driver_rx_cb.SRC_RDY <= req.SRC_RDY;

                $cast(rsp, req.clone());
                rsp.set_id_info(req);
                seq_item_port.item_done();
            end else begin
                vif.driver_rx_cb.DATA    <= 'X;
                vif.driver_rx_cb.VLD     <= 'X;
                vif.driver_rx_cb.SRC_RDY <= 1'b0;
            end

            @(vif.driver_rx_cb);

            if (req != null) begin
                rsp.DST_RDY = vif.driver_rx_cb.DST_RDY;
                seq_item_port.put_response(rsp);
            end

        end
    endtask

endclass

// Driver of mvb tx interface
class driver_tx #(ITEMS, ITEM_WIDTH) extends uvm_driver #(sequence_item #(ITEMS, ITEM_WIDTH));

    // ------------------------------------------------------------------------
    // Register component to database
    `uvm_component_param_utils(mvb::driver_tx #(ITEMS, ITEM_WIDTH))


    // ------------------------------------------------------------------------
    // Virtual interface of driver
    virtual mvb_if #(ITEMS, ITEM_WIDTH).driver_tx vif;
    sequence_item #(ITEMS, ITEM_WIDTH) rsp;

    // ------------------------------------------------------------------------
    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // ------------------------------------------------------------------------
    // Starts driving signals to interface
    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.try_next_item(req);

            if (req != null) begin
                vif.driver_tx_cb.DST_RDY <= req.DST_RDY;
            end else begin
                vif.driver_tx_cb.DST_RDY <= 1'b0;
            end


            @(vif.driver_tx_cb);

            if (req != null) begin
                //rsp = sequence_item#(ITEMS, ITEM_WIDTH)::type_id::create("rsp");
                $cast(rsp, req.clone());
                // TODO - can be remove the for below if parametized unpack function work correctly in modelsim
                for (int i = 0 ; i < ITEMS ; i++ ) begin
                    rsp.DATA[i] = vif.driver_tx_cb.DATA[(i+1)*ITEM_WIDTH - 1 -: ITEM_WIDTH];
                end
                rsp.VLD     <= vif.driver_tx_cb.VLD;
                rsp.SRC_RDY <= vif.driver_tx_cb.SRC_RDY;

                rsp.set_id_info(req);
                seq_item_port.item_done(rsp);
            end
        end
    endtask

endclass

`endif
