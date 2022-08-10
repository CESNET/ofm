/*
 * file       : pkg.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: Package contain common classes
 * date       : 2021
 * author     : Radek Iša <isa@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/


`ifndef RESET_PKG
`define RESET_PKG

package uvm_common;

    `include "uvm_macros.svh"
    import uvm_pkg::*;

    `include "rand_rdy.sv"
    `include "rand_length.sv"
    `include "sequence.sv"
    `include "sequence_library.sv"
    `include "model_item.sv"
endpackage


`endif
