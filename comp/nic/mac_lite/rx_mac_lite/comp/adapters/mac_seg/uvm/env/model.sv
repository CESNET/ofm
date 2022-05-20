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
    `uvm_component_param_utils(uvm_mac_seg_rx::model)

	localparam LOGIC_WIDTH = 6;

    uvm_tlm_analysis_fifo #(uvm_byte_array::sequence_item)                 rx_packet;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item#(LOGIC_WIDTH)) rx_error;

    uvm_analysis_port#(uvm_byte_array::sequence_item)                 tx_packet;
    uvm_analysis_port#(uvm_logic_vector::sequence_item#(1))           tx_error;

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
        rx_packet = new("rx_packet", this);
        rx_error  = new("rx_error", this);
        tx_packet = new("tx_packet", this);
        tx_error  = new("tx_error", this);
    endfunction

    task run();
        uvm_byte_array::sequence_item                 rx_tr_packet;
        uvm_logic_vector::sequence_item#(LOGIC_WIDTH) rx_tr_error;

        uvm_byte_array::sequence_item                 tx_tr_packet;
        uvm_logic_vector::sequence_item#(1)           tx_tr_error;

        forever begin
			logic [1-1:0] fcs_error;
			logic [2-1:0] error;
			logic [3-1:0] status;

            rx_packet.get(rx_tr_packet);
            rx_error.get(rx_tr_error);

            $cast(tx_tr_packet, rx_tr_packet.clone());
			tx_tr_error = uvm_logic_vector::sequence_item#(1)::type_id::create("model_result_error");
			{fcs_error, error, status} = rx_tr_error.data;
            tx_tr_error.data = fcs_error;

            if (tx_tr_packet.data.size() >= 60 ) begin
                tx_packet.write(tx_tr_packet);
			    tx_error.write(tx_tr_error);
            end else begin
                // $write(tx_tr_packet.data.size(), " - undersized packet not writte\n");
            end
        end
    endtask
endclass

