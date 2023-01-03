// dut.sv: Design under test
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


import test::*;

module DUT (
    input logic     CLK,
    input logic     RST,
    mfb_if.dut_rx   mfb_rx,
    mvb_if.dut_tx   mvb_tx_l3,
    mvb_if.dut_tx   mvb_tx_l4
    );

    logic [MFB_REGIONS*7-1 : 0]              rx_l2_hdr_len;
    logic [MFB_REGIONS*9-1 : 0]              rx_l3_hdr_len;
    logic [MFB_REGIONS*4-1 : 0]              rx_flags;
    logic [MFB_REGIONS-1 : 0]                l3_chsum_bypass;
    logic [MFB_REGIONS-1 : 0]                l4_chsum_bypass;
    logic [MFB_REGIONS*MVB_DATA_WIDTH-1 : 0] l3_data;
    logic [MFB_REGIONS*MVB_DATA_WIDTH-1 : 0] l4_data;


    generate
        for (genvar r = 0; r < MFB_REGIONS; r++) begin
            assign mvb_tx_l3.DATA[(r+1)*(MVB_DATA_WIDTH)+r-1 : r*(MVB_DATA_WIDTH)+r] = l3_data[(r+1)*MVB_DATA_WIDTH-1 : r*MVB_DATA_WIDTH];
            assign mvb_tx_l3.DATA[(r+1)*(MVB_DATA_WIDTH)+r]                      = l3_chsum_bypass[r];
            assign mvb_tx_l4.DATA[(r+1)*(MVB_DATA_WIDTH)+r-1 : r*(MVB_DATA_WIDTH)+r] = l4_data[(r+1)*MVB_DATA_WIDTH-1 : r*MVB_DATA_WIDTH];
            assign mvb_tx_l4.DATA[(r+1)*(MVB_DATA_WIDTH)+r]                      = l4_chsum_bypass[r];

            assign rx_l2_hdr_len[(r+1)*7-1 : r*7] = mfb_rx.META[(r*20)+7-1  : r*20];
            assign rx_l3_hdr_len[(r+1)*9-1 : r*9] = mfb_rx.META[(r*20)+16-1 : 7+(r*20)];
            assign rx_flags     [(r+1)*4-1 : r*4] = mfb_rx.META[(r*20)+20-1 : 16+(r*20)];
        end
    endgenerate

    CHECKSUM_CALCULATOR #(
        .MFB_REGIONS     (MFB_REGIONS),
        .MFB_REGION_SIZE (MFB_REGION_SIZE),
        .MFB_BLOCK_SIZE  (MFB_BLOCK_SIZE),
        .MFB_ITEM_WIDTH  (MFB_ITEM_WIDTH),

        .PKT_MTU         (PKT_MTU),
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

        .RX_L2_HDR_LENGTH   (rx_l2_hdr_len),
        .RX_L3_HDR_LENGTH   (rx_l3_hdr_len),
        .RX_FLAGS           (rx_flags),

        .TX_L3_MVB_DATA     (l3_data),
        .TX_L3_CHSUM_BYPASS (l3_chsum_bypass),
        .TX_L3_MVB_VLD      (mvb_tx_l3.VLD),
        .TX_L3_MVB_SRC_RDY  (mvb_tx_l3.SRC_RDY),
        .TX_L3_MVB_DST_RDY  (mvb_tx_l3.DST_RDY),

        .TX_L4_MVB_DATA     (l4_data),
        .TX_L4_CHSUM_BYPASS (l4_chsum_bypass),
        .TX_L4_MVB_VLD      (mvb_tx_l4.VLD),
        .TX_L4_MVB_SRC_RDY  (mvb_tx_l4.SRC_RDY),
        .TX_L4_MVB_DST_RDY  (mvb_tx_l4.DST_RDY)
    );

    
endmodule
