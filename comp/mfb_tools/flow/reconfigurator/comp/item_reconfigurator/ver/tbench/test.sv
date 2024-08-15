// test.sv: Automatic test
// Copyright (C) 2020 CESNET
// Author: Tomas Hak <xhakto01@stud.fit.vutbr.cz>
// SPDX-License-Identifier: BSD-3-Clause

import sv_common_pkg::*;
import sv_mfb_pkg::*;
import test_pkg::*;
`include "scoreboard.sv"

program TEST (
    input logic CLK,
    output logic RESET,
    iMfbRx.tb RX,
    iMfbTx.tb TX,
    iMfbTx.monitor MONITOR
);

    MfbTransaction #(RX_ITEM_WIDTH,META_WIDTH) blueprint;
    Generator generator;
    MfbDriver #(REGIONS,REGION_SIZE,RX_BLOCK_SIZE,RX_ITEM_WIDTH,0,META_WIDTH,META_MODE) driver;
    MfbResponder #(REGIONS,REGION_SIZE,TX_BLOCK_SIZE,RX_ITEM_WIDTH*RX_BLOCK_SIZE/TX_BLOCK_SIZE,META_WIDTH,META_MODE) responder;
    MfbMonitor #(REGIONS,REGION_SIZE,TX_BLOCK_SIZE,RX_ITEM_WIDTH*RX_BLOCK_SIZE/TX_BLOCK_SIZE,META_WIDTH,META_MODE) monitor;
    Scoreboard scoreboard;

    task createGeneratorEnvironment(int packet_size_max, int packet_size_min);
        generator = new("Generator", 0);
        blueprint = new;
        blueprint.frameSizeMax = packet_size_max;
        blueprint.frameSizeMin = packet_size_min;
        generator.blueprint = blueprint;
    endtask

    task createEnvironment();
        driver  = new("Driver", generator.transMbx, RX);
        monitor = new("Monitor", MONITOR);
        driver.ifgHigh  = REGIONS*REGION_SIZE*5;
        responder = new("Responder", TX);
        scoreboard = new;
        driver.setCallbacks(scoreboard.driverCbs);
        monitor.setCallbacks(scoreboard.monitorCbs);
    endtask

    task resetDesign();
        RESET=1;
        #RESET_TIME RESET = 0;
    endtask

    task enableTestEnvironment();
        driver.setEnabled();
        monitor.setEnabled();
        responder.setEnabled();
    endtask

    task disableTestEnvironment();
        wait(!driver.busy);
        do begin
            wait(!monitor.busy);
            fork : StayIdleWait
                wait(monitor.busy) disable StayIdleWait;
                #(100*CLK_PERIOD) disable StayIdleWait;
            join
        end while(monitor.busy);
        driver.setDisabled();
        monitor.setDisabled();
        responder.setDisabled();
    endtask

    task test1();
        $write("\n\n############ TEST CASE 1 ############\n\n");
        enableTestEnvironment();
        generator.setEnabled(TRANSACTION_COUNT);
        wait(!generator.enabled);
        disableTestEnvironment();
        scoreboard.display();
    endtask

    initial begin
        resetDesign();
        createGeneratorEnvironment(FRAME_SIZE_MAX, FRAME_SIZE_MIN);
        createEnvironment();
        test1();
        if (scoreboard.scoreTable.added==scoreboard.scoreTable.removed)begin
            $write("Verification finished successfully!\n");
        end
        $stop();
    end

endprogram

