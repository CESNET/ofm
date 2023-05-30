//-- tbench.sv: Testbench
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

import uvm_pkg::*;
`include "uvm_macros.svh"
import test::*;

module testbench;

    //TESTS
    typedef test::base base;

    typedef test::speed speed;

    localparam USER_META_WIDTH = 24 + $clog2(PKT_SIZE_MAX+1) + $clog2(CHANNELS);

    // -------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Signals
    logic CLK = 0;

    // -------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Interfaces
    reset_if                                                                                                                                      reset     (CLK);
    mfb_if #(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH, USER_META_WIDTH)                       mfb_tx    (CLK);
    mfb_if #(PCIE_CQ_MFB_REGIONS, PCIE_CQ_MFB_REGION_SIZE, PCIE_CQ_MFB_BLOCK_SIZE, PCIE_CQ_MFB_ITEM_WIDTH, sv_pcie_meta_pack::PCIE_CQ_META_WIDTH) mfb_rx    (CLK);
    mvb_if #(1, 1)                                                                                                                                mvb_dma   (CLK);
    mi_if #(MI_WIDTH, MI_WIDTH)                                                                                                                   mi_config (CLK);

    // -------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Define clock period
    always #(CLK_PERIOD/2) CLK = ~CLK;

    // -------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Start of tests
    initial begin
        uvm_root m_root;

        // Configuration of database
        uvm_config_db#(virtual reset_if)::set(null, "", "vif_reset", reset);
        uvm_config_db#(virtual mfb_if #(PCIE_CQ_MFB_REGIONS, PCIE_CQ_MFB_REGION_SIZE, PCIE_CQ_MFB_BLOCK_SIZE, PCIE_CQ_MFB_ITEM_WIDTH, sv_pcie_meta_pack::PCIE_CQ_META_WIDTH))::set(null, "", "vif_rx", mfb_rx);
        uvm_config_db#(virtual mi_if #(MI_WIDTH, MI_WIDTH))::set(null, "", "vif_mi", mi_config);
        uvm_config_db#(virtual mfb_if #(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH, USER_META_WIDTH))::set(null, "", "vif_tx", mfb_tx);
        uvm_config_db#(virtual mvb_if #(1, 1))::set(null, "", "vif_dma", mvb_dma);

        m_root = uvm_root::get();
        m_root.finish_on_completion = 0;
        m_root.set_report_id_action_hier("ILLEGALNAME",UVM_NO_ACTION);

        uvm_config_db#(int)            ::set(null, "", "recording_detail", 0);
        uvm_config_db#(uvm_bitstream_t)::set(null, "", "recording_detail", 0);

        run_test();
        $stop(2);
    end

    // -------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // DUT
    DUT DUT_U (
        .CLK        (CLK),
        .RST        (reset.RESET),
        .mfb_rx     (mfb_rx),
        .mfb_tx     (mfb_tx),
        .config_mi  (mi_config)
    );

    // TODO
    // -------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Properties
    DMA_LL_PROPERTY #(
        .USER_TX_MFB_REGIONS     (USER_TX_MFB_REGIONS    ),
        .USER_TX_MFB_REGION_SIZE (USER_TX_MFB_REGION_SIZE),
        .USER_TX_MFB_BLOCK_SIZE  (USER_TX_MFB_BLOCK_SIZE ),
        .USER_TX_MFB_ITEM_WIDTH  (USER_TX_MFB_ITEM_WIDTH ),
        .USER_META_WIDTH         (USER_META_WIDTH        ),
        .PCIE_CQ_MFB_REGIONS     (PCIE_CQ_MFB_REGIONS    ),
        .PCIE_CQ_MFB_REGION_SIZE (PCIE_CQ_MFB_REGION_SIZE),
        .PCIE_CQ_MFB_BLOCK_SIZE  (PCIE_CQ_MFB_BLOCK_SIZE ),
        .PCIE_CQ_MFB_ITEM_WIDTH  (PCIE_CQ_MFB_ITEM_WIDTH )
    )
    PROPERTY_U (
        .RESET      (reset.RESET),
        .mfb_rx     (mfb_rx),
        .mfb_tx     (mfb_tx),
        .config_mi  (mi_config)
    );


    // -------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // GRAY BOX CONNECTION
    assign mvb_dma.DATA    = DUT_U.VHDL_DUT_U.tx_dma_chan_start_stop_ctrl_i.pkt_drop_en;
    assign mvb_dma.VLD     = DUT_U.VHDL_DUT_U.tx_dma_chan_start_stop_ctrl_i.PCIE_MFB_SOF;
    assign mvb_dma.SRC_RDY = DUT_U.VHDL_DUT_U.tx_dma_chan_start_stop_ctrl_i.PCIE_MFB_SRC_RDY;
    assign mvb_dma.DST_RDY = DUT_U.VHDL_DUT_U.tx_dma_chan_start_stop_ctrl_i.PCIE_MFB_DST_RDY;

endmodule
