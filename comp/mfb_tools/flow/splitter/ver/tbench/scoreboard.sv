/* \scoreboard.sv
 * \brief Verification scoreboard
 * \author Jakub Cabal <cabal@cesnet.cz>
 * \date 2018
 */
 /*
 * Copyright (C) 2018 CESNET z. s. p. o.
 *
 * LICENSE TERMS
 *
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

import sv_common_pkg::*;
import sv_mvb_pkg::*;
import sv_mfb_pkg::*;
import test_pkg::*;

class ScoreboardGeneratorCbs;
   TransactionTable #(1) sc_table0;
   TransactionTable #(1) sc_table1;

   function new (TransactionTable #(1) st0, TransactionTable #(1) st1);
      sc_table0 = st0;
      sc_table1 = st1;
   endfunction

   virtual task post_gen(Transaction transaction);
      CustomTransaction #(HDR_SIZE,MFB_ITEM_WIDTH) custom_tr;
      $cast(custom_tr, transaction);

      if (FULL_PRINT) begin
         $write("POST GEN: TRANSACTION FOR PORT %d!\n", custom_tr.switch);
         custom_tr.display();
      end
      if (custom_tr.switch) begin
         sc_table1.add(transaction);
      end else begin
         sc_table0.add(transaction);
      end
   endtask
endclass

class ScoreboardMonitorCbs extends MonitorCbs;
   mailbox mfbMbx0;
   mailbox mvbMbx0;
   mailbox mfbMbx1;
   mailbox mvbMbx1;
    
   function new (mailbox fMbx0, mailbox vMbx0, mailbox fMbx1, mailbox vMbx1);
      mfbMbx0 = fMbx0;
      mvbMbx0 = vMbx0;
      mfbMbx1 = fMbx1;
      mvbMbx1 = vMbx1;
   endfunction
    
   virtual task post_rx(Transaction transaction, string inst);
      MvbTransaction #(HDR_WIDTH) mvb_tr;
      MfbTransaction #(MFB_ITEM_WIDTH) mfb_tr;

      if (inst == "Monitor MVB0") begin
         if (FULL_PRINT) begin
            $write("Monitor MVB0: GET TRANSACTION!\n");
         end
         $cast(mvb_tr,transaction);
         mvbMbx0.put(mvb_tr);
      end else if (inst == "Monitor MVB1") begin
         if (FULL_PRINT) begin
            $write("Monitor MVB1: GET TRANSACTION!\n");
         end
         $cast(mvb_tr,transaction);
         mvbMbx1.put(mvb_tr);
      end else if (inst == "Monitor MFB0") begin
         if (FULL_PRINT) begin
            $write("Monitor MFB0: GET TRANSACTION!\n");
         end
         $cast(mfb_tr,transaction);
         mfbMbx0.put(mfb_tr);
      end else if (inst == "Monitor MFB1") begin
         if (FULL_PRINT) begin
            $write("Monitor MFB1: GET TRANSACTION!\n");
         end
         $cast(mfb_tr,transaction);
         mfbMbx1.put(mfb_tr);
      end else begin
         $write("VERIFICATION FAILED! BUG IN MONITOR CONFIGURATION?\n");
         $stop;
      end
   endtask
endclass

class Checker;
   bit                   enabled;
   TransactionTable #(1) sc_table;
   mailbox               mfbMbx;
   mailbox               mvbMbx;
   int                   index;

   function new (TransactionTable #(1) st, mailbox fMbx, mailbox vMbx, int ind);
      sc_table = st;
      mfbMbx   = fMbx;
      mvbMbx   = vMbx;
      index    = ind; 
   endfunction

   task setEnabled();
      enabled = 1; // Model Enabling
      fork         
         run(); // Creating model subprocess
      join_none; // Don't wait for ending
   endtask

   task setDisabled();
      enabled = 0; // Disable model
   endtask

   task run();
      bit status = 0;
      int cnt = 0;
      MvbTransaction #(HDR_WIDTH) mvb_tr;
      MfbTransaction #(MFB_ITEM_WIDTH) mfb_tr;
      CustomTransaction #(HDR_SIZE,MFB_ITEM_WIDTH) custom_tr;

      while (enabled) begin // Repeat while enabled
         status = 0;

         custom_tr = new();
         mvbMbx.get(mvb_tr);

         if (mvb_tr.data[0]) begin // header with payload
            mfbMbx.get(mfb_tr);
            // copy header
            custom_tr.hdr = mvb_tr.data;
            // add payload
            custom_tr.payload = 1;
            // add switch
            custom_tr.switch = index;
            // copy payload data
            custom_tr.data = new[mfb_tr.data.size()];
            for (int i=0; i < custom_tr.data.size(); i++) begin
               custom_tr.data[i] = mfb_tr.data[i];
            end
         end else begin // header without payload
            // copy header
            custom_tr.hdr = mvb_tr.data;
            // add payload
            custom_tr.payload = 0;
            // add switch
            custom_tr.switch = index;
         end

         if (FULL_PRINT) begin
            $write("CHECKER %0d: CUSTOM TRANSACTION:", index);
            custom_tr.display();
         end

         // check
         cnt = cnt + 1;
         sc_table.remove(custom_tr, status);
         if (status==0) begin
            $write("Unknown transaction in checker %0d\n", index);
            $timeformat(-9, 3, " ns", 8);
            $write("Time: %t\n", $time);
            custom_tr.display();
            sc_table.display();
            $stop;
         end;
         if ((cnt % 5000) == 0) begin
            $write("PORT%0d: %0d transactions received.\n", index, cnt);
         end;
      end
   endtask
endclass

class Scoreboard;
   TransactionTable #(1)  scoreTable0;
   TransactionTable #(1)  scoreTable1;
   ScoreboardGeneratorCbs generatorCbs;
   ScoreboardMonitorCbs   monitorCbs;
   Checker                dutCheck0;
   Checker                dutCheck1;
   mailbox                mvbMbx0;
   mailbox                mfbMbx0;
   mailbox                mvbMbx1;
   mailbox                mfbMbx1;

   function new ();
      scoreTable0  = new;
      scoreTable1  = new;
      mvbMbx0      = new;
      mfbMbx0      = new;
      mvbMbx1      = new;
      mfbMbx1      = new;
      generatorCbs = new(scoreTable0,scoreTable1);
      monitorCbs   = new(mfbMbx0,mvbMbx0,mfbMbx1,mvbMbx1);
      dutCheck0    = new(scoreTable0,mfbMbx0,mvbMbx0,0);
      dutCheck1    = new(scoreTable1,mfbMbx1,mvbMbx1,1);
   endfunction

   task setEnabled();
      dutCheck0.setEnabled();
      dutCheck1.setEnabled();
   endtask
        
   task setDisabled();
      dutCheck0.setDisabled();
      dutCheck1.setDisabled();
   endtask

   task display();
      scoreTable0.display();
      scoreTable1.display();
   endtask
endclass
