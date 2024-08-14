//-- property.sv
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

import uvm_pkg::*;
`include "uvm_macros.svh"

module DMA_LL_PROPERTY  #(USER_TX_MFB_REGIONS, USER_TX_MFB_REGION_SIZE, USER_TX_MFB_BLOCK_SIZE, USER_TX_MFB_ITEM_WIDTH, USER_META_WIDTH, PCIE_CQ_MFB_REGIONS, PCIE_CQ_MFB_REGION_SIZE, PCIE_CQ_MFB_BLOCK_SIZE, PCIE_CQ_MFB_ITEM_WIDTH)
    (
        input logic RESET,
        mfb_if   mfb_rx,
        mfb_if   mfb_tx,
        mi_if    config_mi
    );

    string module_name = "";
    logic START = 1'b1;

    ///////////////////
    // Start check properties after first clock
    initial begin
        $sformat(module_name, "%m");
        @(posedge mfb_tx.CLK)
        #(10ps)
        START = 1'b0;
    end

    ////////////////////////////////////
    // RX PROPERTY
    mfb_property #(
        .REGIONS     (PCIE_CQ_MFB_REGIONS                  ),
        .REGION_SIZE (PCIE_CQ_MFB_REGION_SIZE              ),
        .BLOCK_SIZE  (PCIE_CQ_MFB_BLOCK_SIZE               ),
        .ITEM_WIDTH  (PCIE_CQ_MFB_ITEM_WIDTH               ),
        .META_WIDTH  (sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)
    )
    MFB_RX (
        .RESET (RESET),
        .vif   (mfb_rx)
    );


    ////////////////////////////////////
    // TX PROPERTY
    mfb_property #(
        .REGIONS     (USER_TX_MFB_REGIONS    ),
        .REGION_SIZE (USER_TX_MFB_REGION_SIZE),
        .BLOCK_SIZE  (USER_TX_MFB_BLOCK_SIZE ),
        .ITEM_WIDTH  (USER_TX_MFB_ITEM_WIDTH ),
        .META_WIDTH  (USER_META_WIDTH        )
    )
    MFB_TX (
        .RESET (RESET),
        .vif   (mfb_tx)
    );

    //simplyfied rule
    property sof_eof_src_rdy;
        @(posedge mfb_tx.CLK) disable iff(RESET || START)
        //mfb_tx.SRC_RDY |-> !$isunknown(mfb_tx.EOF);
        (mfb_tx.SRC_RDY && (mfb_tx.SOF != 0)) |-> mfb_tx.SRC_RDY s_until_with (mfb_tx.EOF != 0);
    endproperty

    assert property (sof_eof_src_rdy)
        else begin
            `uvm_error(module_name, "\n\tMFB To PCIE must'n stop sending data in middle of frame");
        end


endmodule
