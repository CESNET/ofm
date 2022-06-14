//-- pkg.sv: Test package
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

`ifndef FIFOX_TEST_SV
`define FIFOX_TEST_SV

package test;

    `include "uvm_macros.svh"
    import uvm_pkg::*;

    parameter ITEM_WIDTH = 8;
    parameter ITEMS = 4;

    parameter TRANSACTION_COUNT = 100000;

    parameter CLK_PERIOD = 4ns;

    parameter RESET_CLKS = 10;

    `include "test.sv"
    
endpackage
`endif
