// dut.sv: Design under test
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


import test::*;

module DUT (
    input logic     CLK,
    input logic     RST,
    mfb_if.dut_rx   mfb_rx,
    mvb_if.dut_tx   mvb_tx
    );

    logic [MFB_REGIONS*OFFSET_WIDTH-1 : 0]   offset;
    logic [MFB_REGIONS*LENGTH_WIDTH-1 : 0]   length;
    logic [MFB_REGIONS-1 : 0]                chsum_en;
    logic [MFB_REGIONS-1 : 0]                mvb_chsum_bypass;
    logic [MFB_REGIONS*MVB_DATA_WIDTH-1 : 0] mvb_data;


    generate
        for (genvar r = 0; r < MFB_REGIONS; r++) begin
            assign mvb_tx.DATA[(r+1)*(MVB_DATA_WIDTH)+r-1 : r*(MVB_DATA_WIDTH)+r] = mvb_data[(r+1)*MVB_DATA_WIDTH-1 : r*MVB_DATA_WIDTH];
            assign mvb_tx.DATA[(r+1)*(MVB_DATA_WIDTH)+r]                          = mvb_chsum_bypass[r];

            assign offset  [(r+1)*OFFSET_WIDTH-1 : r*OFFSET_WIDTH] = mfb_rx.META[(r*META_WIDTH)+OFFSET_WIDTH-1              : r*META_WIDTH];
            assign length  [(r+1)*LENGTH_WIDTH-1 : r*LENGTH_WIDTH] = mfb_rx.META[(r*META_WIDTH)+OFFSET_WIDTH+LENGTH_WIDTH-1 : OFFSET_WIDTH+(r*META_WIDTH)];
            assign chsum_en[r]                                     = mfb_rx.META[(r*META_WIDTH)+META_WIDTH-1                : OFFSET_WIDTH+LENGTH_WIDTH+(r*META_WIDTH)];
        end
    endgenerate

    CHECKSUM_CALCULATOR #(
        .MFB_REGIONS     (MFB_REGIONS),
        .MFB_REGION_SIZE (MFB_REGION_SIZE),
        .MFB_BLOCK_SIZE  (MFB_BLOCK_SIZE),
        .MFB_ITEM_WIDTH  (MFB_ITEM_WIDTH),

        .PKT_MTU         (PKT_MTU),
        .OFFSET_WIDTH    (OFFSET_WIDTH),
        .LENGTH_WIDTH    (LENGTH_WIDTH),
        .DEVICE          (DEVICE)
    ) VHDL_DUT_U (
        .CLK                (CLK),
        .RESET              (RST),

        .RX_MFB_DATA        (mfb_rx.DATA),
        .RX_MFB_SOF_POS     (mfb_rx.SOF_POS),
        .RX_MFB_EOF_POS     (mfb_rx.EOF_POS),
        .RX_MFB_SOF         (mfb_rx.SOF),
        .RX_MFB_EOF         (mfb_rx.EOF),
        .RX_MFB_SRC_RDY     (mfb_rx.SRC_RDY),
        .RX_MFB_DST_RDY     (mfb_rx.DST_RDY),

        .RX_OFFSET          (offset),
        .RX_LENGTH          (length),
        .RX_CHSUM_EN        (chsum_en),

        .TX_MVB_DATA     (mvb_data),
        .TX_CHSUM_BYPASS (mvb_chsum_bypass),
        .TX_MVB_VLD      (mvb_tx.VLD),
        .TX_MVB_SRC_RDY  (mvb_tx.SRC_RDY),
        .TX_MVB_DST_RDY  (mvb_tx.DST_RDY)

    );

    
endmodule
