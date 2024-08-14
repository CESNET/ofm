/*
 * DUT.sv: Design under test
 * Copyright (C) 2009 CESNET
 * Author(s): Marek Santa <xsanta06@stud.fit.vutbr.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * $Id$
 *
 * TODO:
 *
 */

// ----------------------------------------------------------------------------
//                        Module declaration
// ----------------------------------------------------------------------------
import test_pkg::*; // Test constants

//V PRIPADE POTREBY SA MOZE DOPLNIT VIAC FRAMELINKOVYCH ROZHRANI DANEHO TYPU
module DUT (
   input logic RX_CLK,
   input logic RX_RESET,
   input logic TX_CLK,
   input logic TX_RESET,
   iFrameLinkRx.dut RX,
   iFrameLinkTx.dut TX
);

// -------------------- Module body -------------------------------------------
//TODO: ZMENA NAZVU TESTOVANEJ KOMPONENTY, V PRIPADE PRIDANIA ROZHRANI TREBA PRIDAT AJ PORTY
FL_ASFIFO_BRAM

   VHDL_DUT_U  (
    // Common Interface
     .RX_CLK        (RX_CLK),
     .RX_RESET      (RX_RESET),
     .TX_CLK        (TX_CLK),
     .TX_RESET      (TX_RESET),

    // Port 0
     .RX_DATA       (RX.DATA),
     .RX_REM        (RX.DREM),
     .RX_SOF_N      (RX.SOF_N),
     .RX_EOF_N      (RX.EOF_N),
     .RX_SOP_N      (RX.SOP_N),
     .RX_EOP_N      (RX.EOP_N),
     .RX_SRC_RDY_N  (RX.SRC_RDY_N),
     .RX_DST_RDY_N  (RX.DST_RDY_N),

    // Port 0
     .TX_DATA       (TX.DATA),
     .TX_REM        (TX.DREM),
     .TX_SOF_N      (TX.SOF_N),
     .TX_EOF_N      (TX.EOF_N),
     .TX_SOP_N      (TX.SOP_N),
     .TX_EOP_N      (TX.EOP_N),
     .TX_SRC_RDY_N  (TX.SRC_RDY_N),
     .TX_DST_RDY_N  (TX.DST_RDY_N)
);

endmodule : DUT