/*!
 * \file mvb_ifc.sv
 * \brief Multi-Value Bus interface
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



// /////////////////////////////////////////////////////////////////////////////
// Multi-Value Bus RX (verification to DUT) interface
interface iMvbRx #(ITEMS = 4, ITEM_WIDTH = 8) (input logic CLK, RESET);
    initial VALID_PARAMETERS : assert(ITEMS > 0 && ITEM_WIDTH > 0);

    localparam WORD_WIDTH = ITEMS * ITEM_WIDTH;


    logic [WORD_WIDTH-1 : 0] DATA = 0;
    logic [ITEMS-1 : 0] VLD = 0;
    logic SRC_RDY = 0;
    logic DST_RDY;


    clocking cb @(posedge CLK);
        default input #1step output #500ps;
        output DATA, VLD, SRC_RDY;
        input DST_RDY;
    endclocking;

    clocking monitor_cb @(posedge CLK);
        default input #1step output #500ps;
        input DATA, VLD, SRC_RDY, DST_RDY;
    endclocking: monitor_cb;


    modport dut (input DATA, VLD, SRC_RDY, output DST_RDY);

    modport tb (clocking cb);

    modport monitor (clocking monitor_cb);

endinterface



// /////////////////////////////////////////////////////////////////////////////
// Multi-Value Bus TX (DUT to verification) interface
interface iMvbTx #(ITEMS = 4, ITEM_WIDTH = 8) (input logic CLK, RESET);
    initial VALID_PARAMETERS : assert(ITEMS > 0 && ITEM_WIDTH > 0);

    localparam WORD_WIDTH = ITEMS * ITEM_WIDTH;


    logic [WORD_WIDTH-1 : 0] DATA;
    logic [ITEMS-1 : 0] VLD;
    logic SRC_RDY;
    logic DST_RDY = 0;


    clocking cb @(posedge CLK);
        default input #1step output #500ps;
        input DATA, VLD, SRC_RDY;
        output DST_RDY;
    endclocking;

    clocking monitor_cb @(posedge CLK);
        default input #1step output #500ps;
        input DATA, VLD, SRC_RDY, DST_RDY;
    endclocking: monitor_cb;


    modport dut (output DATA, VLD, SRC_RDY, input DST_RDY);

    modport tb (clocking cb);

    modport monitor (clocking monitor_cb);

endinterface
