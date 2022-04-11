/*!
 * \file test.sv
 * \brief Test Cases
 * \author Jakub Cabal <cabal@cesnet.cz>
 * \date 2018
 */
 /*
 * Copyright (C) 2018 CESNET z. s. p. o.
 *
 * LICENSE TERMS
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *
 */

import sv_common_pkg::*;
import sv_mvb_pkg::*;
import sv_mfb_pkg::*;
import test_pkg::*;

program TEST (
   input  logic CLK,
   output logic RESET,
   iMvbRx.tb RX_MVB,
   iMfbRx.tb RX_MFB,
   iMvbTx.tb TX0_MVB,
   iMvbTx.tb TX1_MVB,
   iMfbTx.tb TX0_MFB,
   iMfbTx.tb TX1_MFB,
   iMvbTx.monitor MO0_MVB,
   iMvbTx.monitor MO1_MVB,
   iMfbTx.monitor MO0_MFB,
   iMfbTx.monitor MO1_MFB
);
   CustomTransaction #(HDR_SIZE,MFB_ITEM_WIDTH) blueprint;
   CustomTransGenerator                         generator;

   MvbDriver    #(MFB_REGIONS,MVB_ITEM_WIDTH)                                mvb_driver;
   MfbDriver    #(MFB_REGIONS,MFB_REGION_SIZE,MFB_BLOCK_SIZE,MFB_ITEM_WIDTH) mfb_driver;

   MfbResponder #(MFB_REGIONS,MFB_REGION_SIZE,MFB_BLOCK_SIZE,MFB_ITEM_WIDTH) mfb0_responder;
   MfbMonitor   #(MFB_REGIONS,MFB_REGION_SIZE,MFB_BLOCK_SIZE,MFB_ITEM_WIDTH) mfb0_monitor;
   MfbResponder #(MFB_REGIONS,MFB_REGION_SIZE,MFB_BLOCK_SIZE,MFB_ITEM_WIDTH) mfb1_responder;
   MfbMonitor   #(MFB_REGIONS,MFB_REGION_SIZE,MFB_BLOCK_SIZE,MFB_ITEM_WIDTH) mfb1_monitor;

   MvbResponder #(MVB_ITEMS,HDR_WIDTH) mvb0_responder;
   MvbMonitor   #(MVB_ITEMS,HDR_WIDTH) mvb0_monitor;
   MvbResponder #(MVB_ITEMS,HDR_WIDTH) mvb1_responder;
   MvbMonitor   #(MVB_ITEMS,HDR_WIDTH) mvb1_monitor;

   Scoreboard scoreboard;

   task createEnvironment(int dataSizeMax, int dataSizeMin);
      blueprint = new();
      generator = new("Custom Generator");
      scoreboard = new;

      blueprint.dataSizeMax = dataSizeMax;
      blueprint.dataSizeMin = dataSizeMin;
      generator.blueprint = blueprint;
      generator.setCallbacks(scoreboard.generatorCbs);

      mvb_driver = new("MVB Driver", generator.mvbTransMbx, RX_MVB);
      mfb_driver = new("MFB Driver", generator.mfbTransMbx, RX_MFB);

      mvb_driver.wordDelayEnable_wt  = MVB_GAP_CHANCE;
      mvb_driver.wordDelayDisable_wt = 100-MVB_GAP_CHANCE;
      mvb_driver.wordDelayHigh       = MVB_GAP_MAX_SIZE;

      mfb_driver.wordDelayEnable_wt  = MFB_GAP_CHANCE;
      mfb_driver.wordDelayDisable_wt = 100-MFB_GAP_CHANCE;
      mfb_driver.wordDelayHigh       = MFB_GAP_MAX_SIZE;

      mvb0_responder = new("Responder MVB0", TX0_MVB);
      mvb1_responder = new("Responder MVB1", TX1_MVB);
      mfb0_responder = new("Responder MFB0", TX0_MFB);
      mfb1_responder = new("Responder MFB1", TX1_MFB);

      mvb0_responder.wordDelayEnable_wt  = MVB0_RES_GAP_CHANCE;
      mvb0_responder.wordDelayDisable_wt = 100-MVB1_RES_GAP_CHANCE;
      mvb0_responder.wordDelayHigh       = MVB0_RES_GAP_MAX_SIZE;
      mvb1_responder.wordDelayEnable_wt  = MVB1_RES_GAP_CHANCE;
      mvb1_responder.wordDelayDisable_wt = 100-MVB1_RES_GAP_CHANCE;
      mvb1_responder.wordDelayHigh       = MVB1_RES_GAP_MAX_SIZE;

      mfb0_responder.wordDelayEnable_wt  = MFB0_RES_GAP_CHANCE;
      mfb0_responder.wordDelayDisable_wt = 100-MFB1_RES_GAP_CHANCE;
      mfb0_responder.wordDelayHigh       = MFB0_RES_GAP_MAX_SIZE;
      mfb1_responder.wordDelayEnable_wt  = MFB1_RES_GAP_CHANCE;
      mfb1_responder.wordDelayDisable_wt = 100-MFB1_RES_GAP_CHANCE;
      mfb1_responder.wordDelayHigh       = MFB1_RES_GAP_MAX_SIZE;

      mvb0_monitor = new("Monitor MVB0", MO0_MVB);
      mvb1_monitor = new("Monitor MVB1", MO1_MVB);
      mfb0_monitor = new("Monitor MFB0", MO0_MFB);
      mfb1_monitor = new("Monitor MFB1", MO1_MFB);

      mvb0_monitor.setCallbacks(scoreboard.monitorCbs);
      mvb1_monitor.setCallbacks(scoreboard.monitorCbs);
      mfb0_monitor.setCallbacks(scoreboard.monitorCbs);
      mfb1_monitor.setCallbacks(scoreboard.monitorCbs);
   endtask

   task resetDesign();
      RESET=1;
      #RESET_TIME RESET = 0;
   endtask

   task enableTestEnvironment();
      scoreboard.setEnabled();
      mvb_driver.setEnabled();
      mfb_driver.setEnabled();
      mfb0_monitor.setEnabled();
      mfb0_responder.setEnabled();
      mfb1_monitor.setEnabled();
      mfb1_responder.setEnabled();
      mvb0_monitor.setEnabled();
      mvb0_responder.setEnabled();
      mvb1_monitor.setEnabled();
      mvb1_responder.setEnabled();
   endtask

   task disableTestEnvironment();
      wait(!mfb_driver.busy && !mvb_driver.busy);
      do begin
         wait(!mfb0_monitor.busy);
         fork : StayIdleWait0
            wait(mfb0_monitor.busy) disable StayIdleWait0;
            #(100*CLK_PERIOD) disable StayIdleWait0;
         join
      end while(mfb0_monitor.busy);
      mvb_driver.setDisabled();
      mfb_driver.setDisabled();
      mfb0_monitor.setDisabled();
      mfb0_responder.setDisabled();
      mfb1_monitor.setDisabled();
      mfb1_responder.setDisabled();
      mvb0_monitor.setDisabled();
      mvb0_responder.setDisabled();
      mvb1_monitor.setDisabled();
      mvb1_responder.setDisabled();
      scoreboard.setDisabled();
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
      createEnvironment(FRAME_SIZE_MAX, FRAME_SIZE_MIN);
      test1();
      $write("Verification finished successfully!\n");
      $stop();
   end

endprogram
