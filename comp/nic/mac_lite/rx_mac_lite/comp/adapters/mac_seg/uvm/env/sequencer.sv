/*
 * file       : sequencer.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: seqeuncer test
 * date       : 2021
 * author     : Radek Iša <isa@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/


////////////////////////////////////////////////////////////////////////////////
// vurtual sequencer.
class sequencer extends uvm_sequencer;
    `uvm_component_utils(mac_seq_rx_ver::sequencer);

    localparam LOGIC_WIDTH = 6;

    // variables
    reset::sequencer                      reset;
    byte_array::sequencer                 rx_packet;
    logic_vector::sequencer#(LOGIC_WIDTH) rx_error;

    //functions
    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass


