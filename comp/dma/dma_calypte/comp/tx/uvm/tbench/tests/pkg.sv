//-- pkg.sv: package with all tests 
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

`ifndef SPLITTER_SIMPLE_TEST_SV
`define SPLITTER_SIMPLE_TEST_SV

package test;

    `include "uvm_macros.svh"
    import uvm_pkg::*;

    parameter DEVICE = "ULTRASCALE";

    parameter MI_WIDTH = 32;

    parameter USER_TX_MFB_REGIONS     = 1;
    parameter USER_TX_MFB_REGION_SIZE = 4;
    parameter USER_TX_MFB_BLOCK_SIZE  = 8;
    parameter USER_TX_MFB_ITEM_WIDTH  = 8;

    parameter PCIE_CQ_MFB_REGIONS     = 1;
    parameter PCIE_CQ_MFB_REGION_SIZE = 1;
    parameter PCIE_CQ_MFB_BLOCK_SIZE  = 8;
    parameter PCIE_CQ_MFB_ITEM_WIDTH  = 32;

    parameter PCIE_CC_MFB_REGIONS     = 1;
    parameter PCIE_CC_MFB_REGION_SIZE = 1;
    parameter PCIE_CC_MFB_BLOCK_SIZE  = 8;
    parameter PCIE_CC_MFB_ITEM_WIDTH  = 32;

    parameter FIFO_DEPTH     = 512;
    parameter CHANNELS       = 2;
    parameter CNTRS_WIDTH    = 64;
    parameter HDR_META_WIDTH = 24;
    // Max size bytes of DMA frame
    parameter PKT_SIZE_MAX       = 2**11;
    parameter CHANNEL_ARBITER_EN = 0;
    // Parameters that set min and max size of PCIE transaction
    parameter PCIE_LEN_MIN = 1;
    parameter PCIE_LEN_MAX = 256;
    parameter DEBUG        = 0;

    parameter TRANSACTION_COUNT = 100000;

    parameter CLK_PERIOD = 4ns;


    `include "sequence.sv"
    `include "base.sv"
    `include "speed.sv"

endpackage
`endif
