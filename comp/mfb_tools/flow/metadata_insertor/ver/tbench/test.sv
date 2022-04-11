/*!
 * \file test.sv
 * \brief Test Cases
 * \author Daniel Kriz <xkrizd01@vutbr.cz>
 * \date 2020
 */
 /*
 * Copyright (C) 2020 CESNET z. s. p. o.
 *
 * LICENSE TERMS
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *
 */

import sv_common_pkg::*;
import sv_mfb_pkg::*;
import sv_mvb_pkg::*;
import test_pkg::*;

program TEST (
    input logic CLK,
    output logic RESET,
    iMfbRx.tb RX_MFB,
    iMfbTx.tb TX_MFB,
    iMvbRx.tb RX_MVB,
    iMfbTx.monitor MONITOR
);

    MfbTransaction #(MFB_ITEM_WIDTH,MFB_META_WIDTH) blueprint;
    MvbTransaction #(MVB_ITEM_WIDTH) mvb_blueprint;
    Generator generator;
    Generator mvb_generator;
    MfbDriver #(MFB_REGIONS,MFB_REGION_SIZE,MFB_BLOCK_SIZE,MFB_ITEM_WIDTH,0,MFB_META_WIDTH,MFB_META_ALIGNMENT) driver;
    MvbDriver #(MVB_ITEMS, MVB_ITEM_WIDTH) mvb_driver;
    MfbResponder #(MFB_REGIONS,MFB_REGION_SIZE,MFB_BLOCK_SIZE,MFB_ITEM_WIDTH,NEW_META_WIDTH,MFB_META_ALIGNMENT) responder;
    MfbMonitor #(MFB_REGIONS,MFB_REGION_SIZE,MFB_BLOCK_SIZE,MFB_ITEM_WIDTH,NEW_META_WIDTH,MFB_META_ALIGNMENT) monitor;
    Scoreboard scoreboard;

    task createGeneratorEnvironment(int packet_size_max, int packet_size_min);
        generator = new("Generator", 0);
        blueprint = new;
        blueprint.frameSizeMax = packet_size_max;
        blueprint.frameSizeMin = packet_size_min;
        generator.blueprint = blueprint;

        mvb_generator = new("MVB Generator", 0);
        mvb_blueprint = new;
        mvb_generator.blueprint = mvb_blueprint;
    endtask

    task createEnvironment();
        driver  = new("Driver", generator.transMbx, RX_MFB);
        monitor = new("MFB Monitor", MONITOR);
        responder = new("Responder", TX_MFB);

        mvb_driver = new("MVB Driver", mvb_generator.transMbx, RX_MVB);
        scoreboard = new;
        driver.setCallbacks(scoreboard.mfbDriverCbs);
        mvb_driver.setCallbacks(scoreboard.mvbDriverCbs);
        monitor.setCallbacks(scoreboard.monitorCbs);
    endtask

    task resetDesign();
        RESET=1;
        #RESET_TIME RESET = 0;
    endtask

    task enableTestEnvironment();
        scoreboard.setEnabled();
        driver.setEnabled();
        mvb_driver.setEnabled();
        monitor.setEnabled();
        responder.setEnabled();
    endtask

    task disableTestEnvironment();;   
        wait(!driver.busy);
        do begin
            wait(!monitor.busy);
            fork : StayIdleWait
                wait(monitor.busy) disable StayIdleWait;
                #(100*CLK_PERIOD) disable StayIdleWait;
            join
        end while(monitor.busy);
        scoreboard.setDisabled();
    endtask

    task test1();
        $write("\n\n############ TEST CASE 1 ############\n\n");
        enableTestEnvironment();
        generator.setEnabled(TRANSACTION_COUNT);
        mvb_generator.setEnabled(TRANSACTION_COUNT);
        wait(!generator.enabled && !mvb_generator.enabled);
        disableTestEnvironment();
        scoreboard.display();
    endtask

    initial begin
        resetDesign();
        createGeneratorEnvironment(FRAME_SIZE_MAX, FRAME_SIZE_MIN);
        createEnvironment();
        test1();
        $write("Verification finished successfully!\n");
        $stop();
    end

endprogram
