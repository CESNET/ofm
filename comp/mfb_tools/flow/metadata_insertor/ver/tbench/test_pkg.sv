/*!
 * \file test_pkg.sv
 * \brief Test Package
 * \author Daniel Kriz <xkrizd01@vutbr.cz>
 * \date 2020
 */
 /*
 * Copyright (C) 2020 CESNET z. s. p. o.
 *
 * LICENSE TERMS
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *
 */

package test_pkg;
   
    import math_pkg::*;

    parameter MVB_ITEMS       = 2;
    parameter MVB_ITEM_WIDTH  = 8;
    parameter MVB_FIFO_SIZE   = 4;

    parameter MFB_REGIONS     = 32;
    parameter MFB_REGION_SIZE = 1;
    parameter MFB_BLOCK_SIZE  = 8;
    parameter MFB_ITEM_WIDTH  = 8;

    parameter MFB_META_WIDTH = 8;
    parameter MFB_META_ALIGNMENT = 1;
    parameter NEW_META_WIDTH = MVB_ITEM_WIDTH+MFB_META_WIDTH;

    parameter INSERT_MODE = 1;

    parameter VERBOSE = 0;

    parameter FRAME_SIZE_MAX = 512;
    parameter FRAME_SIZE_MIN = 32;

    parameter TRANSACTION_COUNT = 2000;

    parameter CLK_PERIOD = 10ns;
    parameter RESET_TIME = 10*CLK_PERIOD;

    `include "scoreboard.sv"
endpackage
