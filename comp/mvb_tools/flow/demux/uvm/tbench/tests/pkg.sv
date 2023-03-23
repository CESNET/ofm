//-- pkg.sv: Test package
//-- Copyright (C) 2023 CESNET z. s. p. o.
//-- Author:   Oliver Gurka <xgurka00@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

`ifndef DEMUX_TEST_SV
`define DEMUX_TEST_SV

package test;

    `include "uvm_macros.svh"
    import uvm_pkg::*;

    parameter ITEM_WIDTH = 8;
    parameter ITEMS = 4;

    parameter RX_MVB_CNT = 4;
    parameter DATA_DEMUX = 1;
    parameter PIPE_IN = 1;

    parameter CLK_PERIOD = 4ns;
    parameter RESET_CLKS = 10;
    parameter RUNS = 15;

    `include "sequence.sv"
    `include "test.sv"
    
endpackage
`endif
