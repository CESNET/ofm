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
class sequencer#(SEGMENTS) extends uvm_sequencer;
    `uvm_component_param_utils(mac_seq_tx_ver::sequencer#(SEGMENTS));

    // variables
    reset::sequencer                      reset_sequencer;
    byte_array_mfb_env::sequencer_rx#(1)  rx_sequencer;
    intel_mac_seg::sequencer#(SEGMENTS)   tx_sequencer;

    //functions
    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass


