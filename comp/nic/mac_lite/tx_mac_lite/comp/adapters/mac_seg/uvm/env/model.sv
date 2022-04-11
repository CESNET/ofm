/*
 * file       : model.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: model of rx_mac_lite adapter 
 * date       : 2021
 * author     : Radek Iša <isa@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/


class model extends uvm_component;
    `uvm_component_param_utils(mac_seq_tx_ver::model)

	localparam LOGIC_WIDTH = 6;

    uvm_tlm_analysis_fifo #(byte_array::sequence_item)                 rx_packet;
    uvm_tlm_analysis_fifo #(logic_vector::sequence_item#(1))           rx_error;

    uvm_analysis_port#(byte_array::sequence_item)                 tx_packet;
    uvm_analysis_port#(logic_vector::sequence_item#(LOGIC_WIDTH)) tx_error;

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
        rx_packet = new("rx_packet", this);
        rx_error  = new("rx_error", this);
        tx_packet = new("tx_packet", this);
        tx_error  = new("tx_error", this);
    endfunction

    task run();
        byte_array::sequence_item                 rx_tr_packet;
        logic_vector::sequence_item#(1)           rx_tr_error;

        byte_array::sequence_item                 tx_tr_packet;
        logic_vector::sequence_item#(LOGIC_WIDTH) tx_tr_error;

        forever begin
            rx_packet.get(rx_tr_packet);
            rx_error.get(rx_tr_error);

            $cast(tx_tr_packet, rx_tr_packet.clone());
            tx_tr_error = logic_vector::sequence_item#(LOGIC_WIDTH)::type_id::create("model_tx_meta");
            tx_tr_error.data = 'z;
            if (rx_tr_error.data == 0) begin
                tx_tr_error.data[5] = 1'b0;
            end else begin
                tx_tr_error.data[5] = 1'b1;
            end

            tx_packet.write(tx_tr_packet);
			tx_error.write(tx_tr_error);
        end
    endtask
endclass

