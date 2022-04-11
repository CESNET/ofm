/*!
 * \file testbench.sv
 * \brief Testbench
 * \author Lukas Kekely <kekely@cesnet.cz>
 * \author Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>
 * \date 2016
 */
 /*
 * SPDX-License-Identifier: BSD-3-Clause
 */

import test_pkg::*;


module testbench;

    logic CLK = 0;
    logic RESET;
    iMvbRx #(ITEMS,ITEM_WIDTH) RX(CLK, RESET);
    iMvbTx #(ITEMS,ITEM_WIDTH) TX(CLK, RESET);

    inFifox #(ITEM_WIDTH)   IN_FIFOX(CLK, RESET);
    outFifox #(ITEM_WIDTH)  OUT_FIFOX(CLK, RESET);

    always #(CLK_PERIOD/2) CLK = ~CLK;

    DUT DUT_U (
        .CLK        (CLK),
        .RESET      (RESET),
        .RX         (RX),
        .TX         (TX),
        .IN_FIFOX   (IN_FIFOX),
        .OUT_FIFOX  (OUT_FIFOX)
    );

    TEST TEST_U (
        .CLK        (CLK),
        .RESET      (RESET),
        .RX         (RX),
        .TX         (TX),
        .IN_FIFOX   (IN_FIFOX),
        .OUT_FIFOX  (OUT_FIFOX)
    );

endmodule
