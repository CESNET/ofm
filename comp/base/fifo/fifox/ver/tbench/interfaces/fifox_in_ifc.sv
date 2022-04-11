/*!
 * \file fifox_in_ifc.sv
 * \brief Input interface for fifox
 * \author Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>
 * \date 2016
*/
/*
 * SPDX-License-Identifier: BSD-3-Clause
*/

interface inFifox #(ITEM_WIDTH = 8) (input logic CLK, RESET);

    logic [ITEM_WIDTH-1 : 0] DI;
    logic WR;
    logic FULL;
    logic AFULL;

    clocking monitor_cb @(posedge CLK);
        input DI, WR, FULL, AFULL;
    endclocking: monitor_cb;

    modport dut (input DI, WR, output FULL, AFULL);

    modport monitor (clocking monitor_cb);

endinterface
