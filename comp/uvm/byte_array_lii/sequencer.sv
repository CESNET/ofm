/*
 * file       : sequencer.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: LII sequencer
 * date       : 2021
 * author     : Daniel Kriz <xkrizd01@vutbr.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/

`ifndef LII_SEQUENCER_SV
`define LII_SEQUENCER_SV

class sequencer #(LOGIC_WIDTH) extends uvm_sequencer;

    byte_array::sequencer                m_packet;
    logic_vector::sequencer#(LOGIC_WIDTH) m_meta;

    `uvm_component_param_utils(byte_array_lii_env::sequencer #(LOGIC_WIDTH))

    function new(string name = "sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass
`endif