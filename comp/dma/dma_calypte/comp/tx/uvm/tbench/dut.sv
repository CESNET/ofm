//-- dut.sv: Design under test 
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

import test::*;

module DUT(
        input logic     CLK,
        input logic     RST,
        mfb_if.dut_rx   mfb_rx,
        mfb_if.dut_tx   mfb_tx[CHANNELS],
        mi_if.dut_slave config_mi
    );

    localparam USR_SOF_POS_WIDTH = (($clog2(USER_TX_MFB_REGION_SIZE)*USER_TX_MFB_REGIONS) == 0) ? (USER_TX_MFB_REGIONS) : (USER_TX_MFB_REGIONS*$clog2(USER_TX_MFB_REGION_SIZE));
    localparam USR_EOF_POS_WIDTH = USER_TX_MFB_REGIONS*$clog2(USER_TX_MFB_REGION_SIZE*USER_TX_MFB_BLOCK_SIZE);

    logic [$clog2(PKT_SIZE_MAX+1)-1:0] packet_size[CHANNELS-1 : 0];
    logic [$clog2(CHANNELS)-1:0]       channel[CHANNELS-1 : 0];
    logic [24-1:0]                     meta[CHANNELS-1 : 0];

    logic [USER_TX_MFB_REGIONS*USER_TX_MFB_REGION_SIZE*USER_TX_MFB_BLOCK_SIZE*USER_TX_MFB_ITEM_WIDTH-1:0] usr_mfb_data     [CHANNELS-1 : 0];
    logic [USER_TX_MFB_REGIONS-1:0]                                                                       usr_mfb_sof      [CHANNELS-1 : 0];
    logic [USER_TX_MFB_REGIONS-1:0]                                                                       usr_mfb_eof      [CHANNELS-1 : 0];
    logic [USR_SOF_POS_WIDTH -1:0]                                                                        usr_mfb_sof_pos  [CHANNELS-1 : 0];
    logic [USR_EOF_POS_WIDTH -1:0]                                                                        usr_mfb_eof_pos  [CHANNELS-1 : 0];
    logic [CHANNELS-1:0]                                                                                  usr_mfb_src_rdy;
    logic [CHANNELS-1:0]                                                                                  usr_mfb_dst_rdy;

    logic [((PCIE_CQ_MFB_REGION_SIZE != 1) ? $clog2(PCIE_CQ_MFB_REGION_SIZE) : 1)-1 : 0] sof_pos;
    generate
        if (PCIE_CQ_MFB_REGION_SIZE != 1) begin
            assign sof_pos = mfb_rx.SOF_POS;
        end else
            assign sof_pos = '0;
    endgenerate

    generate
        for (genvar i = 0; i < CHANNELS; i++) begin
            assign mfb_tx[i].DATA     = usr_mfb_data[i];
            assign mfb_tx[i].SOF      = usr_mfb_sof[i];
            assign mfb_tx[i].EOF      = usr_mfb_eof[i];
            assign mfb_tx[i].SOF_POS  = usr_mfb_sof_pos[i];
            assign mfb_tx[i].EOF_POS  = usr_mfb_eof_pos[i];
            assign mfb_tx[i].SRC_RDY  = usr_mfb_src_rdy[i];
            assign usr_mfb_dst_rdy[i] = mfb_tx[i].DST_RDY;
            //{packet_size, channel, meta} 24 + $clog2(PKT_SIZE_MAX+1) + $clog2(CHANNELS)[CHANNELS]
            assign mfb_tx[i].META[24 + $clog2(PKT_SIZE_MAX+1) + $clog2(CHANNELS)-1 -: $clog2(PKT_SIZE_MAX+1)] = packet_size[i][$clog2(PKT_SIZE_MAX+1)-1 -: $clog2(PKT_SIZE_MAX+1)];
            assign mfb_tx[i].META[24 + $clog2(CHANNELS)-1                          -: $clog2(CHANNELS)]       = channel[i][$clog2(CHANNELS)-1 -: $clog2(CHANNELS)]                ;
            assign mfb_tx[i].META[24 - 1                                           -: 24]                     = meta[i][24-1 -: 24]                                               ;
        end
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

        .FIFO_DEPTH              (FIFO_DEPTH),
        .CHANNELS                (CHANNELS),
        .CNTRS_WIDTH             (CNTRS_WIDTH),
        .HDR_META_WIDTH          (HDR_META_WIDTH),
        .PKT_SIZE_MAX            (PKT_SIZE_MAX),
        .CHANNEL_ARBITER_EN      (CHANNEL_ARBITER_EN)
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

        .USR_TX_MFB_DATA          (usr_mfb_data),
        .USR_TX_MFB_SOF           (usr_mfb_sof),
        .USR_TX_MFB_EOF           (usr_mfb_eof),
        .USR_TX_MFB_SOF_POS       (usr_mfb_sof_pos),
        .USR_TX_MFB_EOF_POS       (usr_mfb_eof_pos),
        .USR_TX_MFB_SRC_RDY       (usr_mfb_src_rdy),
        .USR_TX_MFB_DST_RDY       (usr_mfb_dst_rdy),

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
