/*!
 * \file dut.sv
 * \brief Design Under Test
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

import test_pkg::*;

module DUT (
    input logic CLK,
    input logic RESET,
    iMfbRx.dut RX_MFB,
    iMvbRx.dut RX_MVB,
    iMfbTx.dut TX_MFB
);

    DUT_WRAPPER #(
        // MVB characteristics
        .MVB_ITEMS       (MVB_ITEMS),
        .MVB_ITEM_WIDTH  (MVB_ITEM_WIDTH),
        .MVB_FIFO_SIZE   (MVB_FIFO_SIZE),
        // MFB characteristics
        .MFB_REGIONS     (MFB_REGIONS),
        .MFB_REGION_SIZE (MFB_REGION_SIZE),
        .MFB_BLOCK_SIZE  (MFB_BLOCK_SIZE),
        .MFB_ITEM_WIDTH  (MFB_ITEM_WIDTH),
        .MFB_META_WIDTH  (MFB_META_WIDTH),
        .INSERT_MODE     (INSERT_MODE)
    ) VHDL_DUT_U (
        .CLK             (CLK),
        .RESET           (RESET),
        // RX MFB INTERFACE
        .RX_MFB_DATA     (RX_MFB.DATA),
        .RX_MFB_META     (RX_MFB.META),
        .RX_MFB_SOF_POS  (RX_MFB.SOF_POS),
        .RX_MFB_EOF_POS  (RX_MFB.EOF_POS),
        .RX_MFB_SOF      (RX_MFB.SOF),
        .RX_MFB_EOF      (RX_MFB.EOF),
        .RX_MFB_SRC_RDY  (RX_MFB.SRC_RDY),
        .RX_MFB_DST_RDY  (RX_MFB.DST_RDY),
        // RX MVB INTERFACE
        .RX_MVB_DATA     (RX_MVB.DATA),
        .RX_MVB_VLD      (RX_MVB.VLD),
        .RX_MVB_SRC_RDY  (RX_MVB.SRC_RDY),
        .RX_MVB_DST_RDY  (RX_MVB.DST_RDY),
        // TX MFB INTERFACE
        .TX_MFB_DATA     (TX_MFB.DATA),
        .TX_MFB_META     (TX_MFB.META),
        .TX_MFB_SOF_POS  (TX_MFB.SOF_POS),
        .TX_MFB_EOF_POS  (TX_MFB.EOF_POS),
        .TX_MFB_SOF      (TX_MFB.SOF),
        .TX_MFB_EOF      (TX_MFB.EOF),
        .TX_MFB_SRC_RDY  (TX_MFB.SRC_RDY),
        .TX_MFB_DST_RDY  (TX_MFB.DST_RDY)
    );

endmodule
