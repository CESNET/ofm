/*!
 * \file mfb_ifc.sv
 * \brief Multi-Frame Bus interface
 * \author Lukas Kekely <kekely@cesnet.cz>
 * \date 2016
 */
 /*
 * Copyright (C) 2016 CESNET z. s. p. o.
 *
 * LICENSE TERMS
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *
 */

//import math_pkg::*;



// /////////////////////////////////////////////////////////////////////////////
// Multi-Frame Bus RX (verification to DUT) interface
interface iMfbRx #(REGIONS = 4, REGION_SIZE = 8, BLOCK_SIZE = 8, ITEM_WIDTH = 8, META_WIDTH = 1) (input logic CLK, RESET);
    initial VALID_PARAMETERS : assert(REGIONS > 0 && REGION_SIZE > 0 && BLOCK_SIZE > 0 && ITEM_WIDTH > 0);

    localparam WORD_WIDTH = REGIONS * REGION_SIZE * BLOCK_SIZE * ITEM_WIDTH;
    localparam META_WORD_WIDTH = REGIONS * META_WIDTH;
    localparam SOF_POS_WIDTH = REGIONS * math_pkg::max(1,math_pkg::log2(REGION_SIZE));
    localparam EOF_POS_WIDTH = REGIONS * math_pkg::max(1,math_pkg::log2(REGION_SIZE * BLOCK_SIZE));


    logic [WORD_WIDTH-1 : 0] DATA = 0;
    logic [META_WORD_WIDTH-1 : 0] META = 0;
    logic [SOF_POS_WIDTH-1 : 0] SOF_POS = 0;
    logic [EOF_POS_WIDTH-1 : 0] EOF_POS = 0;
    logic [REGIONS-1 : 0] SOF = 0;
    logic [REGIONS-1 : 0] EOF = 0;
    logic SRC_RDY = 0;
    logic DST_RDY;


    clocking cb @(posedge CLK);
        default input #1step output #500ps;
        output DATA, META, SOF_POS, EOF_POS, SOF, EOF, SRC_RDY;
        input DST_RDY;
    endclocking;

    clocking monitor_cb @(posedge CLK);
        default input #1step output #500ps;
        input DATA, META, SOF_POS, EOF_POS, SOF, EOF, SRC_RDY, DST_RDY;
    endclocking: monitor_cb;


    modport dut (input DATA, META, SOF_POS, EOF_POS, SOF, EOF, SRC_RDY, output DST_RDY);

    modport tb (clocking cb);

    modport monitor (clocking monitor_cb);

endinterface



// /////////////////////////////////////////////////////////////////////////////
// Multi-Frame Bus TX (DUT to verification) interface
interface iMfbTx #(REGIONS = 4, REGION_SIZE = 8, BLOCK_SIZE = 8, ITEM_WIDTH = 8, META_WIDTH = 1) (input logic CLK, RESET);
    initial VALID_PARAMETERS : assert(REGIONS > 0 && REGION_SIZE > 0 && BLOCK_SIZE > 0 && ITEM_WIDTH > 0);

    localparam WORD_WIDTH = REGIONS * REGION_SIZE * BLOCK_SIZE * ITEM_WIDTH;
    localparam META_WORD_WIDTH = REGIONS * META_WIDTH;
    localparam SOF_POS_WIDTH = REGIONS * math_pkg::max(1,math_pkg::log2(REGION_SIZE));
    localparam EOF_POS_WIDTH = REGIONS * math_pkg::max(1,math_pkg::log2(REGION_SIZE * BLOCK_SIZE));


    logic [WORD_WIDTH-1 : 0] DATA;
    logic [META_WORD_WIDTH-1 : 0] META;
    logic [SOF_POS_WIDTH-1 : 0] SOF_POS;
    logic [EOF_POS_WIDTH-1 : 0] EOF_POS;
    logic [REGIONS-1 : 0] SOF;
    logic [REGIONS-1 : 0] EOF;
    logic SRC_RDY;
    logic DST_RDY = 0;


    clocking cb @(posedge CLK);
        default input #1step output #500ps;
        input DATA, META, SOF_POS, EOF_POS, SOF, EOF, SRC_RDY;
        output DST_RDY;
    endclocking;

    clocking monitor_cb @(posedge CLK);
        default input #1step output #500ps;
        input DATA, META, SOF_POS, EOF_POS, SOF, EOF, SRC_RDY, DST_RDY;
    endclocking: monitor_cb;


    modport dut (output DATA, META, SOF_POS, EOF_POS, SOF, EOF, SRC_RDY, input DST_RDY);

    modport tb (clocking cb);

    modport monitor (clocking monitor_cb);

endinterface
