/*!
 * \file test.sv
 * \brief Test Cases
 * \author Lukas Kekely <kekely@cesnet.cz>
 * \author Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>
 * \date 2016
*/
/*
 * SPDX-License-Identifier: BSD-3-Clause
*/

import sv_common_pkg::*;
import sv_mvb_pkg::*;
import test_pkg::*;
import sv_fifox_cov_pkg::*;

program TEST (
    input logic         CLK,
    output logic        RESET,
    iMvbRx              RX,
    iMvbTx              TX,
    inFifox.monitor     IN_FIFOX,
    outFifox.monitor    OUT_FIFOX
);


    MvbTransaction #(ITEM_WIDTH) blueprint;
    Generator generator;
    MvbDriver #(ITEMS,ITEM_WIDTH) driver;
    MvbResponder #(ITEMS,ITEM_WIDTH) responder;
    MvbMonitor #(ITEMS,ITEM_WIDTH) monitor;
    Scoreboard scoreboard;

    fifoxInCov #(ITEM_WIDTH) inCov;
    fifoxOutCov #(ITEM_WIDTH) outCov;

    task createGeneratorEnvironment();
        generator = new("Generator", 0);
        blueprint = new;
        generator.blueprint = blueprint;
    endtask

    task createEnvironment();
        driver  = new("Driver", generator.transMbx, RX.tb);
        monitor = new("Monitor", TX.monitor);
        responder = new("Responder", TX.tb);
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
        responder.wordDelayEnable_wt = 8;
        responder.wordDelayDisable_wt = 2;
        enableTestEnvironment();
        generator.setEnabled(TRANSACTION_COUNT);
        #(200*CLK_PERIOD);
	    responder.setEnabled();
        wait(!generator.enabled);
        disableTestEnvironment();
        scoreboard.display();
    endtask
   
    task test2();
        $write("\n\n############ TEST CASE 2 ############\n\n");
        responder.wordDelayEnable_wt = 2;
        responder.wordDelayDisable_wt = 8;
        enableTestEnvironment();
        generator.setEnabled(TRANSACTION_COUNT);
        #(20*CLK_PERIOD);
        responder.setEnabled();
        wait(!generator.enabled);
        disableTestEnvironment();
        scoreboard.display();

    endtask

    task test3();
        $write("\n\n############ TEST CASE 3 ############\n\n");
        responder.wordDelayEnable_wt = 1;
        responder.wordDelayDisable_wt = 4;
        responder.wordDelayLow = 20;
        responder.wordDelayHigh = 40;
        enableTestEnvironment();
        generator.setEnabled(TRANSACTION_COUNT);
        #(20*CLK_PERIOD);
        responder.setEnabled();
        wait(!generator.enabled);
        disableTestEnvironment();
        scoreboard.display();

    endtask


    initial begin
        inCov = new(IN_FIFOX);
        outCov= new(OUT_FIFOX);
        resetDesign();
        createGeneratorEnvironment();
        createEnvironment();
        // test1 and test2 are basic test with differend word delay in driver  
        test1();
        resetDesign();
        createGeneratorEnvironment();
        createEnvironment();
        test2();
        resetDesign();
        createGeneratorEnvironment();
        createEnvironment();
        // test3 is designed to fill fifox to full capacity
        test3();
        $write("Verification finished successfully!\n");
        $write("-----------------------------------\n");
        $write("Coverage %d\n",$get_coverage());        
        $write("-----------------------------------\n");
        inCov.display();
        outCov.display();
        $stop();
    end

endprogram

