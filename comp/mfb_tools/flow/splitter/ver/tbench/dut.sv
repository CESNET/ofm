/*!
 * \file dut.sv
 * \brief Design Under Test
 * \author Jakub Cabal <cabal@cesnet.cz>
 * \date 2018
 */
 /*
 * Copyright (C) 2018 CESNET z. s. p. o.
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
   iMvbRx.dut RX_MVB,
   iMfbRx.dut RX_MFB,
   iMvbTx.dut TX0_MVB,
   iMvbTx.dut TX1_MVB,
   iMfbTx.dut TX0_MFB,
   iMfbTx.dut TX1_MFB
);

   DUT_WRAPPER #(
      .HDR_WIDTH       (HDR_WIDTH),
      .MFB_REGIONS     (MFB_REGIONS),
      .MFB_REGION_SIZE (MFB_REGION_SIZE),
      .MFB_BLOCK_SIZE  (MFB_BLOCK_SIZE),
      .MFB_ITEM_WIDTH  (MFB_ITEM_WIDTH),
      .MVB_ITEMS       (MVB_ITEMS),
      .MVB_ITEM_WIDTH  (MVB_ITEM_WIDTH)
   ) VHDL_DUT_U (
      .CLK            (CLK),
      .RESET          (RESET),

      .RX_MVB_DATA    (RX_MVB.DATA),
      .RX_MVB_VLD     (RX_MVB.VLD),
      .RX_MVB_SRC_RDY (RX_MVB.SRC_RDY),
      .RX_MVB_DST_RDY (RX_MVB.DST_RDY),

      .RX_MFB_DATA    (RX_MFB.DATA),
      .RX_MFB_SOF_POS (RX_MFB.SOF_POS),
      .RX_MFB_EOF_POS (RX_MFB.EOF_POS),
      .RX_MFB_SOF     (RX_MFB.SOF),
      .RX_MFB_EOF     (RX_MFB.EOF),
      .RX_MFB_SRC_RDY (RX_MFB.SRC_RDY),
      .RX_MFB_DST_RDY (RX_MFB.DST_RDY),

      .TX0_MVB_DATA    (TX0_MVB.DATA),
      .TX0_MVB_VLD     (TX0_MVB.VLD),
      .TX0_MVB_SRC_RDY (TX0_MVB.SRC_RDY),
      .TX0_MVB_DST_RDY (TX0_MVB.DST_RDY),

      .TX0_MFB_DATA    (TX0_MFB.DATA),
      .TX0_MFB_SOF_POS (TX0_MFB.SOF_POS),
      .TX0_MFB_EOF_POS (TX0_MFB.EOF_POS),
      .TX0_MFB_SOF     (TX0_MFB.SOF),
      .TX0_MFB_EOF     (TX0_MFB.EOF),
      .TX0_MFB_SRC_RDY (TX0_MFB.SRC_RDY),
      .TX0_MFB_DST_RDY (TX0_MFB.DST_RDY),

      .TX1_MVB_DATA    (TX1_MVB.DATA),
      .TX1_MVB_VLD     (TX1_MVB.VLD),
      .TX1_MVB_SRC_RDY (TX1_MVB.SRC_RDY),
      .TX1_MVB_DST_RDY (TX1_MVB.DST_RDY),

      .TX1_MFB_DATA    (TX1_MFB.DATA),
      .TX1_MFB_SOF_POS (TX1_MFB.SOF_POS),
      .TX1_MFB_EOF_POS (TX1_MFB.EOF_POS),
      .TX1_MFB_SOF     (TX1_MFB.SOF),
      .TX1_MFB_EOF     (TX1_MFB.EOF),
      .TX1_MFB_SRC_RDY (TX1_MFB.SRC_RDY),
      .TX1_MFB_DST_RDY (TX1_MFB.DST_RDY)
    );

endmodule
