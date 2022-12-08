//-- pkg.sv: Test package
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author:   Daniel Kříž <xkrizd01@vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

`ifndef FIFOX_TEST_SV
`define FIFOX_TEST_SV

package test;

    `include "uvm_macros.svh"
    import uvm_pkg::*;

    parameter MVB_ITEMS  = 32;
    parameter LUT_DEPTH  = 128;
    parameter ADDR_WIDTH = LUT_DEPTH;
    parameter LUT_WIDTH  = 32;
    // LUT, BRAM, AUTO
    parameter LUT_ARCH   = "BRAM";
    parameter SW_WIDTH   = 32;
    parameter META_WIDTH = 32;
    parameter OUTPUT_REG = 0;
    parameter DEVICE     = "AGILEX";
    // Fix for this variant
    parameter TRUE_LUT_DEPTH = ($clog2(LUT_DEPTH) == 0) ? 1 : $clog2(LUT_DEPTH);
    parameter REG_DEPTH      = ($clog2(LUT_DEPTH) == 0) ? TRUE_LUT_DEPTH*2 : TRUE_LUT_DEPTH*2;
    // parameter REG_DEPTH      = ($clog2(LUT_DEPTH) == 0) ? 1 : LUT_DEPTH*4;

    parameter REPEAT = 20;

    parameter CLK_PERIOD = 4ns;

    parameter RESET_CLKS = 10;

    `include "sequence.sv"
    `include "test.sv"
    
endpackage
`endif
