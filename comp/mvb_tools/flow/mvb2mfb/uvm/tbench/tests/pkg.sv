// pkg.sv: Test package
// Copyright (C) 2023 CESNET z. s. p. o.
// Author(s): Jakub Cabal <cabal@cesnet.cz>

// SPDX-License-Identifier: BSD-3-Clause


`ifndef MVB2MFB_TEST_SV
`define MVB2MFB_TEST_SV

package test;

    `include "uvm_macros.svh"
    import uvm_pkg::*;

    parameter MFB_REGIONS        = 1;
    parameter MFB_REGION_SIZE    = 8;
    parameter MFB_BLOCK_SIZE     = 8;
    parameter MFB_ITEM_WIDTH     = 8;
    parameter MFB_META_WIDTH     = 12;

    parameter MVB_ITEMS          = 1;
    parameter MVB_ITEM_WIDTH_RAW = 48;
    parameter MVB_ITEM_WIDTH     = MVB_ITEM_WIDTH_RAW+MFB_META_WIDTH;

    parameter MFB_ALIGNMENT      = MFB_REGION_SIZE*MFB_BLOCK_SIZE;
    parameter DEVICE             = "ULTRASCALE";

    parameter CLK_PERIOD         = 4ns;
    parameter RESET_CLKS         = 10;

    `include "sequence.sv"
    `include "test.sv"
    `include "speed.sv"
endpackage
`endif
