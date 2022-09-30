// pkg.sv: Test package
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


`ifndef SUPERUNPACKETER_TEST_SV
`define SUPERUNPACKETER_TEST_SV

package test;

    `include "uvm_macros.svh"
    import uvm_pkg::*;

    // Number of Regions within a data word, must be power of 2.
    parameter MFB_REGIONS        = 4;
    // Region size (in Blocks).
    parameter MFB_REGION_SIZE    = 4;
    // Block size (in Items), must be 8.
    parameter MFB_BLOCK_SIZE     = 8;
    // Item width (in bits), must be 8.
    parameter MFB_ITEM_WIDTH     = 8;

	// Output metadata width (in bits), must be according to the header (16B).
    parameter OUT_META_WIDTH     = 2*8*8-1;
    // The extracted Header is output as:
    // Insert header to output metadata with SOF (MODE 0),
    // Insert header to output metadata with EOF (MODE 1),
    // Insert header on MVB (MODE 2)
    parameter OUT_META_MODE      = 2;
    // Maximum size of a packet (in Items).
    parameter PKT_MTU            = 2**15;
    parameter DATA_SIZE_MAX      = 1500;
    // FPGA device name: ULTRASCALE, STRATIX10, AGILEX, ...
    parameter DEVICE             = "STRATIX10";
    // Size of chunk header
    parameter HEADER_SIZE        = 128;
    // VERBOSITY MODE
    // 0 - None
    // 1 - Basic
    // 2 - Addvanced (SP, partial packets and headers)
    parameter VERBOSITY          = 0;
    parameter MIN_SIZE           = 60 + HEADER_SIZE/8;

    parameter CLK_PERIOD         = 4ns;

    parameter RESET_CLKS         = 10;

    `include "sequence.sv"
    `include "test.sv"
    `include "speed.sv"
endpackage
`endif
