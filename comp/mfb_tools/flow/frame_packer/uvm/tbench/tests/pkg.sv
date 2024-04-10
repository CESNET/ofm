// pkg.sv: Test package
// Copyright (C) 2024 CESNET z. s. p. o.
// Author:   David Beneš <xbenes52@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause

`ifndef FRAMEPACKER_TEST_SV
`define FRAMEPACKER_TEST_SV

package test;

    `include "uvm_macros.svh"
    import uvm_pkg::*;

    //MFB interface
    parameter MFB_REGIONS             = 1;
    parameter MFB_REGION_SIZE         = 8;
    parameter MFB_BLOCK_SIZE          = 8;
    parameter MFB_ITEM_WIDTH          = 8;
    //MFB META is not supported
    parameter MFB_META_WIDTH          = 0;

    //TODO: Change the minimal value to 64
    //TODO.benesd New verification
    parameter RX_CHANNELS             = 16;
    parameter HDR_META_WIDTH          = 12;
    parameter USR_RX_PKT_SIZE_MIN     = 64;
    parameter USR_RX_PKT_SIZE_MAX     = 2**14;

    // sequence.sv
    parameter FRAME_SIZE_MIN          = USR_RX_PKT_SIZE_MIN;
    //TODO:  The -248 prevents to maximal size packet to occur ... This needs to be fixed
    parameter FRAME_SIZE_MAX          = USR_RX_PKT_SIZE_MAX-1; // 73;
    //MVB interface
    parameter MVB_ITEMS               = MFB_REGIONS;
    parameter MVB_ITEM_WIDTH          = $clog2(USR_RX_PKT_SIZE_MAX+1) + HDR_META_WIDTH + $clog2(RX_CHANNELS) + 1;

    // configure space between packet
    parameter SPACE_SIZE_MIN_RX = 0;
    parameter SPACE_SIZE_MAX_RX = 0;
    parameter SPACE_SIZE_MIN_TX = 0;
    parameter SPACE_SIZE_MAX_TX = 0;

    parameter REPEAT          = 20;
    parameter CLK_PERIOD      = 5ns;
    parameter RESET_CLKS      = 10;

    `include "sequence.sv"
    `include "test.sv"
    `include "speed.sv"
    
endpackage
`endif
