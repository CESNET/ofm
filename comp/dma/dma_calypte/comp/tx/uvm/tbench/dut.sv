//-- dut.sv: Design under test
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

import test::*;

module DUT(
        input logic     CLK,
        input logic     RST,
        mfb_if.dut_rx   mfb_rx,
        mfb_if.dut_tx   mfb_tx,
        mi_if.dut_slave config_mi
    );

    localparam USR_SOF_POS_WIDTH = (($clog2(USER_TX_MFB_REGION_SIZE)*USER_TX_MFB_REGIONS) == 0) ? (USER_TX_MFB_REGIONS) : (USER_TX_MFB_REGIONS*$clog2(USER_TX_MFB_REGION_SIZE));
    localparam USR_EOF_POS_WIDTH = USER_TX_MFB_REGIONS*$clog2(USER_TX_MFB_REGION_SIZE*USER_TX_MFB_BLOCK_SIZE);

    logic [$clog2(PKT_SIZE_MAX+1)-1:0] packet_size;
    logic [$clog2(CHANNELS)-1:0]       channel;
    logic [24-1:0]                     meta;

    logic [((PCIE_CQ_MFB_REGION_SIZE != 1) ? $clog2(PCIE_CQ_MFB_REGION_SIZE) : 1)-1 : 0] sof_pos;
    generate
        if (PCIE_CQ_MFB_REGION_SIZE != 1) begin
            assign sof_pos = mfb_rx.SOF_POS;
        end else
            assign sof_pos = '0;
    endgenerate

    generate
        //{packet_size, channel, meta} 24 + $clog2(PKT_SIZE_MAX+1) + $clog2(CHANNELS)[CHANNELS]
        assign mfb_tx.META[24 + $clog2(PKT_SIZE_MAX+1) + $clog2(CHANNELS)-1 -: $clog2(PKT_SIZE_MAX+1)] = packet_size[$clog2(PKT_SIZE_MAX+1)-1 -: $clog2(PKT_SIZE_MAX+1)];
        assign mfb_tx.META[24 + $clog2(CHANNELS)-1                          -: $clog2(CHANNELS)]       = channel[$clog2(CHANNELS)-1 -: $clog2(CHANNELS)]                ;
        assign mfb_tx.META[24 - 1                                           -: 24]                     = meta[24-1 -: 24]                                               ;
    endgenerate

    TX_DMA_CALYPTE #(
        .DEVICE                  (DEVICE),

        .MI_WIDTH                (MI_WIDTH),

        .USR_TX_MFB_REGIONS     (USER_TX_MFB_REGIONS),
        .USR_TX_MFB_REGION_SIZE (USER_TX_MFB_REGION_SIZE),
        .USR_TX_MFB_BLOCK_SIZE  (USER_TX_MFB_BLOCK_SIZE),
        .USR_TX_MFB_ITEM_WIDTH  (USER_TX_MFB_ITEM_WIDTH),

        .PCIE_CQ_MFB_REGIONS     (PCIE_CQ_MFB_REGIONS),
        .PCIE_CQ_MFB_REGION_SIZE (PCIE_CQ_MFB_REGION_SIZE),
        .PCIE_CQ_MFB_BLOCK_SIZE  (PCIE_CQ_MFB_BLOCK_SIZE),
        .PCIE_CQ_MFB_ITEM_WIDTH  (PCIE_CQ_MFB_ITEM_WIDTH),

        .PCIE_CC_MFB_REGIONS     (PCIE_CC_MFB_REGIONS),
        .PCIE_CC_MFB_REGION_SIZE (PCIE_CC_MFB_REGION_SIZE),
        .PCIE_CC_MFB_BLOCK_SIZE  (PCIE_CC_MFB_BLOCK_SIZE),
        .PCIE_CC_MFB_ITEM_WIDTH  (PCIE_CC_MFB_ITEM_WIDTH),

        .DMA_HDR_POINTER_WIDTH   (DMA_HDR_POINTER_WIDTH),
        .DATA_POINTER_WIDTH      (DATA_POINTER_WIDTH),
        .CHANNELS                (CHANNELS),
        .CNTRS_WIDTH             (CNTRS_WIDTH),
        .HDR_META_WIDTH          (HDR_META_WIDTH),
        .PKT_SIZE_MAX            (PKT_SIZE_MAX)
    ) VHDL_DUT_U (
        .CLK                       (CLK),
        .RESET                     (RST),

        .MI_ADDR                   (config_mi.ADDR),
        .MI_DWR                    (config_mi.DWR),
        .MI_BE                     (config_mi.BE),
        .MI_RD                     (config_mi.RD),
        .MI_WR                     (config_mi.WR),
        .MI_DRD                    (config_mi.DRD),
        .MI_ARDY                   (config_mi.ARDY),
        .MI_DRDY                   (config_mi.DRDY),

        .USR_TX_MFB_META_PKT_SIZE (packet_size),
        .USR_TX_MFB_META_CHAN     (channel),
        .USR_TX_MFB_META_HDR_META (meta),

        .USR_TX_MFB_DATA          (mfb_tx.DATA),
        .USR_TX_MFB_SOF           (mfb_tx.SOF),
        .USR_TX_MFB_EOF           (mfb_tx.EOF),
        .USR_TX_MFB_SOF_POS       (mfb_tx.SOF_POS),
        .USR_TX_MFB_EOF_POS       (mfb_tx.EOF_POS),
        .USR_TX_MFB_SRC_RDY       (mfb_tx.SRC_RDY),
        .USR_TX_MFB_DST_RDY       (mfb_tx.DST_RDY),

        .PCIE_CQ_MFB_DATA          (mfb_rx.DATA),
        .PCIE_CQ_MFB_META          (mfb_rx.META),
        .PCIE_CQ_MFB_SOF_POS       (sof_pos),
        .PCIE_CQ_MFB_EOF_POS       (mfb_rx.EOF_POS),
        .PCIE_CQ_MFB_SOF           (mfb_rx.SOF),
        .PCIE_CQ_MFB_EOF           (mfb_rx.EOF),
        .PCIE_CQ_MFB_SRC_RDY       (mfb_rx.SRC_RDY),
        .PCIE_CQ_MFB_DST_RDY       (mfb_rx.DST_RDY),

        .PCIE_CC_MFB_DATA          (/* mfb_tx.DATA */),
        .PCIE_CC_MFB_META          (/* mfb_tx.META */),
        .PCIE_CC_MFB_SOF_POS       (/* sof_pos */),
        .PCIE_CC_MFB_EOF_POS       (/* mfb_tx.EOF_POS[$clog2(PCIE_CC_REGION_SIZE * PCIE_CC_BLOCK_SIZE * PCIE_CC_ITEM_WIDTH/8)-1:$clog2(PCIE_CC_ITEM_WIDTH/8)] */),
        .PCIE_CC_MFB_SOF           (/* mfb_tx.SOF */),
        .PCIE_CC_MFB_EOF           (/* mfb_tx.EOF */),
        .PCIE_CC_MFB_SRC_RDY       (/* mfb_tx.SRC_RDY */),
        .PCIE_CC_MFB_DST_RDY       (/* mfb_tx.DST_RDY */)
    );


endmodule
