//-- pkg.sv: Test package
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

`ifndef PCIE_TRANSACTION_CTRL_TEST_SV
`define PCIE_TRANSACTION_CTRL_TEST_SV

package test;

    `include "uvm_macros.svh"
    import uvm_pkg::*;

// Number of DMA ports per one PTC, possible values: 1, 2.
    parameter DMA_PORTS             = 2;
    parameter MVB_UP_ITEMS          = 2;
    parameter DMA_MVB_UP_ITEMS      = MVB_UP_ITEMS;
    parameter MFB_UP_REGIONS        = 2;
    parameter MFB_UP_REG_SIZE       = 1;
    parameter MFB_UP_BLOCK_SIZE     = 8;
    parameter MFB_UP_ITEM_WIDTH     = 32;
    parameter DMA_MFB_UP_REGIONS    = MFB_UP_REGIONS;
    parameter MVB_DOWN_ITEMS        = 2;
    parameter DMA_MVB_DOWN_ITEMS    = MVB_DOWN_ITEMS;
    parameter MFB_DOWN_REGIONS      = 2;
    parameter MFB_DOWN_REG_SIZE     = 1;
    parameter MFB_DOWN_BLOCK_SIZE   = 8;
    parameter MFB_DOWN_ITEM_WIDTH   = 32;
    parameter DMA_MFB_DOWN_REGIONS  = MFB_DOWN_REGIONS;
    parameter PCIE_UPHDR_WIDTH      = 128;
    parameter PCIE_DOWNHDR_WIDTH    = 3*4*8;
    parameter PCIE_PREFIX_WIDTH     = 32;
    parameter DMA_TAG_WIDTH         = sv_dma_bus_pack::DMA_REQUEST_UNITID_O - sv_dma_bus_pack::DMA_REQUEST_TAG_O + 1;
    parameter DMA_ID_WIDTH          = sv_dma_bus_pack::DMA_REQUEST_GLOBAL_O - sv_dma_bus_pack::DMA_REQUEST_UNITID_O + 1;
    parameter PCIE_TAG_WIDTH        = 8;
    // Only needed for setting MFB FIFO sizes
    parameter MPS                   = 512/4;
    // Only needed when DMA_PORTS>1 for setting MFB FIFO sizes
    parameter MRRS                  = 512/4;

    parameter UP_ASFIFO_ITEMS       = 512;
    parameter DOWN_ASFIFO_ITEMS     = 512;
    parameter DOWN_FIFO_ITEMS       = 512;
    // UltraScale+ -> 137; Virtex7 -> 60;
    parameter RQ_TUSER_WIDTH        = 137;
    // UltraScale+ -> 161; Virtex7 -> 75;
    parameter RC_TUSER_WIDTH        = 161;
    // CPL credits checking:
    // Each credit represents one available 64B or 128B word in receiving buffer.
    // The goal is to calculate, whether UP read request's response fits in available words in receiving buffer.

    // Auto-assign PCIe tags
    // true  -> Tag Manager automaticaly generates remapped tags and sends transactions up with these tags.
    // false -> Tag Manager receives tags from PCIe endpoint via the TAG_ASSIGN interface.
    //          (Can only be used on Xilinx FPGAs)
    // This option must correspond with the PCIe settings.
    parameter AUTO_ASSIGN_TAGS      = 1;
    parameter DEVICE                = "STRATIX10"; // "VIRTEX6", "7SERIES", "ULTRASCALE", "STRATIX10"
    // Connected PCIe endpoint type ("H_TILE" or "P_TILE" or "R_TILE") (only relevant on Intel FPGAs)
    parameter ENDPOINT_TYPE         = "P_TILE";
    // PCIE header is in MVB data only if ENDPOINT is P_TILE and DEVICE is STRATIX10 or DEVICE is Agilex

    // VERIFICATION PARAMETERS
    parameter CLK_PERIOD            = 2.22222222ns;
    parameter CLK_DMA_PERIOD        = 5ns;
    parameter RESET_CLKS            = 10;
    parameter META_WIDTH            = 0;

    `include "sequence.sv"
    `include "test.sv"
endpackage
`endif
