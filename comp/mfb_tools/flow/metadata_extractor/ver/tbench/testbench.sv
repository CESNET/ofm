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
    iMfbRx #(MFB_REGIONS,MFB_REGION_SIZE,MFB_BLOCK_SIZE,MFB_ITEM_WIDTH,MFB_META_WIDTH) RX(CLK, RESET);
    iMfbTx #(MFB_REGIONS,MFB_REGION_SIZE,MFB_BLOCK_SIZE,MFB_ITEM_WIDTH,MFB_META_WIDTH) TX_MFB(CLK, RESET);
    iMvbTx #(MVB_ITEMS,MFB_META_WIDTH) TX_MVB(CLK, RESET);

    always #(CLK_PERIOD/2) CLK = ~CLK;

    DUT DUT_U (
        .CLK         (CLK),
        .RESET       (RESET),
        .RX          (RX),
        .TX_MFB      (TX_MFB),
        .TX_MVB      (TX_MVB)
    );

    TEST TEST_U (
        .CLK         (CLK),
        .RESET       (RESET),
        .RX          (RX),
        .TX_MFB      (TX_MFB),
        .TX_MVB      (TX_MVB),
        .MONITOR     (TX_MFB),
        .MVB_MONITOR (TX_MVB)
    );
    
endmodule
