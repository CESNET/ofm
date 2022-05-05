//-- pkg.sv: Test package
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

`ifndef SPLITTER_SIMPLE_TEST_SV
`define SPLITTER_SIMPLE_TEST_SV

package test;

    `include "uvm_macros.svh"
    import uvm_pkg::*;

    parameter SPLITTER_OUTPUTS = 8;
    parameter REGIONS     = 4;
    parameter REGION_SIZE = 8;
    parameter BLOCK_SIZE  = 8;
    parameter ITEM_WIDTH  = 8;
    parameter META_WIDTH  = SPLITTER_OUTPUTS + 128;   // Note that this width must be great enought to map all splitter outputs

    parameter DEVICE = "AGILEX";
    parameter DRAIN_TIME = 20ns;
    parameter TRANSACTION_COUNT = 100000;

    parameter CLK_PERIOD = 4ns;

    parameter RESET_CLKS = 10;

    `include "sequence.sv"
    `include "test.sv"
endpackage
`endif
