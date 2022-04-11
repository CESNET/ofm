/*
 * file       : pkg.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: mag seq rx adapter 
 * date       : 2021
 * author     : Radek Iša <isa@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/

`ifndef MAC_SEQ_RX_VER
`define MAC_SEQ_RX_VER

package mac_seq_rx_ver

	`include "uvm_macros.svh";
	import uvm_pkg::*;

	`include "model.sv"
	`include "scoreboard.sv"
	`include "sequencer.sv"
	`include "sequence_tx.sv"
	`include "env.sv"

	`include "sequence.sv"
endpackage

`endif

