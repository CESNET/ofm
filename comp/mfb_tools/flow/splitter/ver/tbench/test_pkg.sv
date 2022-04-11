/*!
 * \file test_pkg.sv
 * \brief Test Package
 * \author Jakub Cabal <cabal@cesnet.cz>
 * \date 2018
 */
 /*
 * Copyright (C) 2018 CESNET z. s. p. o.
 *
 * LICENSE TERMS
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *
 */

package test_pkg;
   
   import math_pkg::*;
   import sv_common_pkg::*; // SystemVerilog Boolean

   parameter MFB_REGIONS     = 2;
   parameter MFB_REGION_SIZE = 2;
   parameter MFB_BLOCK_SIZE  = 4;
   parameter MFB_ITEM_WIDTH  = 8;

   parameter HDR_SIZE = 4;
   parameter HDR_WIDTH = HDR_SIZE*MFB_ITEM_WIDTH;

   // Generator parameters
   parameter FRAME_SIZE_MAX = 50; // size is in MFB items
   parameter FRAME_SIZE_MIN = 1; // size is in MFB items
   parameter TRANSACTION_COUNT = 100000;

   // Test parameters
   parameter FULL_PRINT = FALSE;

   // Others parameters
   parameter MVB_ITEMS = 2;
   parameter MVB_ITEM_WIDTH = HDR_WIDTH+2;

   // Clock and reset parameters
   parameter CLK_PERIOD = 5ns;
   parameter RESET_TIME = 10*CLK_PERIOD;

   // MVB driver gaps settings
   parameter MVB_GAP_CHANCE   = 20; // [%]
   parameter MVB_GAP_MAX_SIZE = 20;

   // MFB driver gaps settings
   parameter MFB_GAP_CHANCE   = 20; // [%]
   parameter MFB_GAP_MAX_SIZE = 20;

   // MVB responder gaps settings
   parameter MVB0_RES_GAP_CHANCE   = 20; // [%]
   parameter MVB0_RES_GAP_MAX_SIZE = 20;
   parameter MVB1_RES_GAP_CHANCE   = 20; // [%]
   parameter MVB1_RES_GAP_MAX_SIZE = 20;

   // MFB responder gaps settings
   parameter MFB0_RES_GAP_CHANCE   = 20; // [%]
   parameter MFB0_RES_GAP_MAX_SIZE = 20;
   parameter MFB1_RES_GAP_CHANCE   = 20; // [%]
   parameter MFB1_RES_GAP_MAX_SIZE = 20;

   `include "custom_trans.sv"
   `include "scoreboard.sv"
   `include "custom_trans_gen.sv"

endpackage
