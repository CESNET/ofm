//-- tbench.sv: Testbench
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

import uvm_pkg::*;
`include "uvm_macros.svh"
import test::*;

module testbench;

    // -------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Signals
    logic RX_CLK = 0;
    logic RX_RST = 0;

    logic TX_CLK = 0;
    logic TX_RST = 0;

    // -------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Interfaces
    mvb_if #(1, ITEM_WIDTH) mvb_wr(RX_CLK);
    mvb_if #(1, ITEM_WIDTH) mvb_rd(TX_CLK);

    // -------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Define clock period
    always #(RX_CLK_PERIOD) RX_CLK = ~RX_CLK;
    always #(TX_CLK_PERIOD) TX_CLK = ~TX_CLK;

    // -------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Initial reset
    initial begin
        RX_RST = 1;
        #(RX_RESET_CLKS*RX_CLK_PERIOD)
        RX_RST = 0;
    end

    initial begin
        TX_RST = 1;
        #(TX_RESET_CLKS*TX_CLK_PERIOD)
        TX_RST = 0;
    end

    // -------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Start of tests
    initial begin
        uvm_root m_root;
        // Configuration of database
        uvm_config_db#(virtual mvb_if #(1, ITEM_WIDTH))::set(null, "", "vif_rx", mvb_wr);
        uvm_config_db#(virtual mvb_if #(1, ITEM_WIDTH))::set(null, "", "vif_tx", mvb_rd);

        m_root = uvm_root::get();
        m_root.finish_on_completion = 0;
        m_root.set_report_id_action_hier("ILLEGALNAME",UVM_NO_ACTION);

        run_test();
        $stop(2);
    end

    // -------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // DUT
    DUT DUT_U (
        .RX_CLK     (RX_CLK),
        .RX_RST     (RX_RST),
        .TX_CLK     (TX_CLK),
        .TX_RST     (TX_RST),
        .mvb_wr     (mvb_wr),
        .mvb_rd     (mvb_rd)
    );

    // -------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Properties
    mvb_property #(
        .ITEMS       (1),
        .ITEM_WIDTH  (ITEM_WIDTH)
    )
    property_rd(
        .RESET  (TX_RST),
        .vif    (mvb_rd)
    );

    mvb_property  #(
        .ITEMS       (1),
        .ITEM_WIDTH  (ITEM_WIDTH)
    )
    property_wr (
        .RESET  (RX_RST),
        .vif    (mvb_wr)
    );

endmodule
