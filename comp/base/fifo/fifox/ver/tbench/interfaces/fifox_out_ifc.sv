/*!
 * \file fifox_out_inf.sv
 * \brief Output interface for the fifox
 * \author Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>
 * \date 2016
*/
/*
 * SPDX-License-Identifier: BSD-3-Clause
*/

interface outFifox #(ITEM_WIDTH = 8) (input logic CLK, RESET);

    logic [ITEM_WIDTH-1 : 0] DO;
    logic RD;
    logic EMPTY;
    logic AEMPTY;

    clocking monitor_cb @(posedge CLK);
        input DO, RD, EMPTY, AEMPTY;
    endclocking: monitor_cb;

    modport dut (input RD, output DO, EMPTY, AEMPTY);

    modport monitor (clocking monitor_cb);

endinterface
