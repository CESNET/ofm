/*!
 * \file testbench.sv
 * \brief Testbench
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

module testbench;

    logic CLK = 0;
    logic RESET;
    iMfbRx #(MFB_REGIONS,MFB_REGION_SIZE,MFB_BLOCK_SIZE,MFB_ITEM_WIDTH,MFB_META_WIDTH) RX_MFB(CLK, RESET);
    iMvbRx #(MVB_ITEMS,MVB_ITEM_WIDTH) RX_MVB(CLK, RESET);
    iMfbTx #(MFB_REGIONS,MFB_REGION_SIZE,MFB_BLOCK_SIZE,MFB_ITEM_WIDTH,NEW_META_WIDTH) TX_MFB(CLK, RESET);

    always #(CLK_PERIOD/2) CLK = ~CLK;

    DUT DUT_U (
        .CLK         (CLK),
        .RESET       (RESET),
        .RX_MFB      (RX_MFB),
        .RX_MVB      (RX_MVB),
        .TX_MFB      (TX_MFB)
    );

    TEST TEST_U (
        .CLK         (CLK),
        .RESET       (RESET),
        .RX_MFB      (RX_MFB),
        .RX_MVB      (RX_MVB),
        .TX_MFB      (TX_MFB),
        .MONITOR     (TX_MFB)
    );

endmodule
