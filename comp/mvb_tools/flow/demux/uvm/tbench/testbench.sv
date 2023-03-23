//-- tbench.sv: Testbench
//-- Copyright (C) 2023 CESNET z. s. p. o.
//-- Author:   Oliver Gurka <xgurka00@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

import uvm_pkg::*;
`include "uvm_macros.svh"
import test::*;

module testbench;

    // -------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Signals
    logic CLK = 0;
    logic RST = 0;

    // -------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Interfaces
    reset_if  reset(CLK);
    mvb_if #(ITEMS, ITEM_WIDTH) mvb_rd [RX_MVB_CNT - 1 : 0] (CLK);
    mvb_if #(ITEMS, ITEM_WIDTH + $clog2(RX_MVB_CNT)) mvb_wr(CLK);

    // -------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Define clock period
    always #(CLK_PERIOD) CLK = ~CLK;

    // -------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Start of tests
    initial begin
        uvm_root m_root;

        automatic virtual mvb_if #(ITEMS, ITEM_WIDTH) v_mvb_rd[RX_MVB_CNT - 1 : 0] = mvb_rd;

        // Configuration of database
        for (int i = 0; i < RX_MVB_CNT; i++) begin
            uvm_config_db #(virtual mvb_if #(ITEMS, ITEM_WIDTH))::set(null, "", $sformatf("tx_vif_%0d", i), v_mvb_rd[i]);
        end

        uvm_config_db #(virtual reset_if)::set(null, "", "vif_reset", reset);
        uvm_config_db #(virtual mvb_if #(ITEMS, ITEM_WIDTH + $clog2(RX_MVB_CNT)))::set(null, "", "rx_vif", mvb_wr);

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
        .CLK     (CLK),
        .RST     (reset.RESET),
        .mvb_wr  (mvb_wr),
        .mvb_rd  (mvb_rd)
    );

    // -------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Properties
    for (genvar i = 0; i < RX_MVB_CNT; i++) begin
        mvb_property #(
            .ITEMS       (ITEMS),
            .ITEM_WIDTH  (ITEM_WIDTH)
        )
        property_rd(
            .RESET (reset.RESET),
            .vif   (mvb_rd[i])
        );
    end


    mvb_property  #(
        .ITEMS      (ITEMS),
        .ITEM_WIDTH (ITEM_WIDTH)
    )
    property_wr (
        .RESET (reset.RESET),
        .vif   (mvb_wr)
    );

endmodule
