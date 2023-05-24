// dut.sv: Design under test
// Copyright (C) 2023 CESNET z. s. p. o.
// Author(s): Daniel Kříž <danielkriz@cesnet.cz>

// SPDX-License-Identifier: BSD-3-Clause


import test::*;

module DUT (
    input logic     CLK,
    input logic     RST,
    mfb_if.dut_rx   mfb_rx,
    mfb_if.dut_tx   mfb_tx
    );

    logic [MFB_REGIONS*TIMESTAMP_WIDTH-1 : 0] timestamp;
    logic [MFB_REGIONS*MFB_META_WIDTH-1 : 0]  meta;

    for (genvar regions = 0; regions < MFB_REGIONS; regions++) begin
        assign timestamp [(regions+1)*TIMESTAMP_WIDTH-1 -: TIMESTAMP_WIDTH] = mfb_rx.META[regions*RX_MFB_META_WIDTH + TIMESTAMP_WIDTH                 -1 -: TIMESTAMP_WIDTH];
        assign meta      [(regions+1)*MFB_META_WIDTH -1 -: MFB_META_WIDTH]  = mfb_rx.META[regions*RX_MFB_META_WIDTH + TIMESTAMP_WIDTH + MFB_META_WIDTH-1 -: MFB_META_WIDTH];
    end

    MFB_TIMESTAMP_LIMITER #(
        .MFB_REGIONS       (MFB_REGIONS)      ,
        .MFB_REGION_SIZE   (MFB_REGION_SIZE)  ,
        .MFB_BLOCK_SIZE    (MFB_BLOCK_SIZE)   ,
        .MFB_ITEM_WIDTH    (MFB_ITEM_WIDTH)   ,
        .MFB_META_WIDTH    (MFB_META_WIDTH)   ,
        .CLK_FREQUENCY     (CLK_FREQUENCY)    ,
        .TIMESTAMP_WIDTH   (TIMESTAMP_WIDTH)  ,
        .TIMESTAMP_FORMAT  (TIMESTAMP_FORMAT) ,
        .AUTORESET_TIMEOUT (AUTORESET_TIMEOUT),
        .BUFFER_SIZE       (BUFFER_SIZE)      ,
        .QUEUES            (QUEUES)           ,
        .PKT_MTU           (PKT_MTU)          ,
        .DEVICE            (DEVICE)
    ) VHDL_DUT_U (
        .CLK                (CLK)           ,
        .RESET              (RST)           ,

        .RX_MFB_DATA        (mfb_rx.DATA)   ,
        .RX_MFB_TIMESTAMP   (timestamp)     ,
        .RX_MFB_META        (meta)          ,
        .RX_MFB_SOF_POS     (mfb_rx.SOF_POS),
        .RX_MFB_EOF_POS     (mfb_rx.EOF_POS),
        .RX_MFB_SOF         (mfb_rx.SOF)    ,
        .RX_MFB_EOF         (mfb_rx.EOF)    ,
        .RX_MFB_SRC_RDY     (mfb_rx.SRC_RDY),
        .RX_MFB_DST_RDY     (mfb_rx.DST_RDY),

        .TX_MFB_DATA        (mfb_tx.DATA)   ,
        .TX_MFB_META        (mfb_tx.META)   ,
        .TX_MFB_SOF_POS     (mfb_tx.SOF_POS),
        .TX_MFB_EOF_POS     (mfb_tx.EOF_POS),
        .TX_MFB_SOF         (mfb_tx.SOF)    ,
        .TX_MFB_EOF         (mfb_tx.EOF)    ,
        .TX_MFB_SRC_RDY     (mfb_tx.SRC_RDY),
        .TX_MFB_DST_RDY     (mfb_tx.DST_RDY)

    );

    
endmodule
