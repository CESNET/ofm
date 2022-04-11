/*!
 * \file test_pkg.sv
 * \brief Test Package
 * \author Lukas Kekely <kekely@cesnet.cz>
 * \date 2016
*/
/*
 * SPDX-License-Identifier: BSD-3-Clause
*/


package test_pkg;
   
    `include "scoreboard.sv"


    parameter ITEMS                 = 1;
    parameter FIFO_ITEMS            = 64;
    parameter ITEM_WIDTH            = 32;
    parameter RAM_TYPE              = "AUTO";
    parameter DEVICE                = "ULTRASCALE";
    parameter ALMOST_FULL_OFFSET    = 1;
    parameter ALMOST_EMPTY_OFFSET   = 1;
    parameter FAKE_FIFO             = 0;

    //parameter USE_DST_RDY = 1;

    parameter TRANSACTION_COUNT = 2500;


    parameter CLK_PERIOD = 10ns;
    parameter RESET_TIME = 10*CLK_PERIOD;

endpackage
