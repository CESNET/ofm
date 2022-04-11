/*
 * scoreboard.sv: Frame Link Scoreboard
 * Copyright (C) 2012 CESNET
 * Author(s): Pavel Benacek <benacek@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *
 *
 *
 * TODO:
 *
 */

import sv_common_pkg::*;
import sv_flu_pkg::*;
import math_pkg::*;

  // --------------------------------------------------------------------------
  // -- Frame Link Driver Callbacks
  // --------------------------------------------------------------------------
  class ScoreboardDriverCbs extends DriverCbs;
    
      // ---------------------
    // -- Class Variables --
    // ---------------------
    TransactionTable                    sc_table;
    mailbox #(FrameLinkUTransaction)    header_table[PORTS];
    mailbox #(FrameLinkUTransaction)    data_table[PORTS];
    semaphore                           sem_table[PORTS]; // Semaphores for mutual access

    // -- Constructor ---------------------------------------------------------
    // Create a class 
    function new (TransactionTable sc_table);
      this.sc_table = sc_table;
      for(int i=0;i<PORTS;i++)begin
         this.header_table[i] = new;
         this.data_table[i] = new;
         this.sem_table[i] = new(1); // Semaphore is unlocked (by default)
      end 
    endfunction

    // ------------------------------------------------------------------------
    // Process actual sitautation, this observation has to be done in atomic manner
    // get the lock and process the transaction. Create all possible transactions
    task processHeaderAndData(
                    ref FrameLinkUTransaction newTr,
                    FrameLinkUTransaction dataTr, 
                    FrameLinkUTransaction hdrTr,
                    int index);
        // Local variables
        FrameLinkUTransaction data,header;
        int unsigned hdrNum,dataNum;

        // Get the lock and look for actual
        // situation
        this.sem_table[index].get(1);
            //Add the data to the apropriate bucket
            if(dataTr != null) this.data_table[index].put(dataTr);
            if(hdrTr != null) this.header_table[index].put(hdrTr);
            
            //If header and data are ready for the port, create a transaction
            hdrNum = this.header_table[index].num();
            dataNum = this.data_table[index].num();

            if(hdrNum != 0 && dataNum != 0)begin
                // If we have both (data and header, create a new transaction)
                this.header_table[index].get(header);
                this.data_table[index].get(data);

                //Create a transaction
                newTr = new;
                newTr.data = {header.data,data.data};
            end
        this.sem_table[index].put(1);
    endtask : processHeaderAndData

    // ------------------------------------------------------------------------
    // Function is called after is transaction received (scoreboard)
    virtual task post_tx(Transaction transaction, string inst);
        FrameLinkUTransaction dataTr; //Data transaction
        FrameLinkUTransaction newTr;  //Data transaction
        FrameLinkUTransaction hdrTr;  //Header transaction
        // Default values
        string deviceName = inst.substr(0,2);
        newTr = null;
    
        if(deviceName != "Hdr")begin
            //Transaction was generated by data generator; try to get
            //header and create new transaction format
            for(int i=0;i < PORTS;i++)begin
                $swrite(deviceName,"Driver %0d",i);
                if(inst == deviceName)begin
                    $cast(dataTr,transaction);
                
                    if(HDR_ENABLE == TRUE)begin
                        // Process the data
                        hdrTr = null;
                        processHeaderAndData(newTr,dataTr,hdrTr,i);
                    end else begin
                        // This section is called whem HDR_ENABLE == FALSE
                        newTr = new;
                        newTr.data = dataTr.data;
                    end
                end
            end
        end
        else begin
            //We are transfering the header 
            for(int i=0;i<PORTS;i++) begin
                $swrite(deviceName, "Hdr Driver %0d",i);
                if(inst == deviceName) begin
                    // Add header to the appropriate header table
                    $cast(hdrTr,transaction);
                    // Get the lock and look for actual situation
                    dataTr = null;
                    processHeaderAndData(newTr,dataTr,hdrTr,i);
                end
            end
        end
                 
        // Insert transaction into transaction table 
        if(newTr != null) this.sc_table.add(newTr);
    endtask

   endclass : ScoreboardDriverCbs


  // --------------------------------------------------------------------------
  // -- Frame Link Monitor Callbacks
  // --------------------------------------------------------------------------
  class ScoreboardMonitorCbs extends MonitorCbs;
    
    // ---------------------
    // -- Class Variables --
    // ---------------------
    TransactionTable                    sc_table;
    mailbox #(FrameLinkUTransaction)    header_table;
    mailbox #(FrameLinkUTransaction)    data_table;
    semaphore                           sem;

    // -- Constructor ---------------------------------------------------------
    // Create a class 
    function new (TransactionTable sc_table);
      this.sc_table = sc_table;
      this.header_table = new;
      this.data_table = new;
      this.sem = new(1); // Semaphore is unlocked by default
    endfunction
   
    // ------------------------------------------------------------------------
    // Process actual sitautation, this observation has to be done in atomic manner
    // get the lock and process the transaction
    task processHeaderAndData(ref FrameLinkUTransaction newTr,
                     FrameLinkUTransaction dataTr, 
                     FrameLinkUTransaction hdrTr);
        // Local variables
        FrameLinkUTransaction data,header;
        int unsigned hdrNum,dataNum;

        // Get the lock and look for actual
        // situation
        this.sem.get(1);
            //Add the data to the apropriate bucket
            if(dataTr != null) this.data_table.put(dataTr);
            if(hdrTr != null) this.header_table.put(hdrTr);
            
            //If header and data are ready for the port, create a transaction
            hdrNum = this.header_table.num();
            dataNum = this.data_table.num();

            if(hdrNum != 0 && dataNum != 0)begin
                // If we have both (data and header, create a new transaction)
                this.header_table.get(header);
                this.data_table.get(data);

                //Create a transaction
                newTr = new;
                newTr.data = {header.data,data.data};
            end
        this.sem.put(1);
    endtask : processHeaderAndData
   
    // ------------------------------------------------------------------------
    // Function is called after is transaction received (scoreboard)
    virtual task post_rx(Transaction transaction, string inst);
      bit status=1;
      FrameLinkUTransaction dataTr; //Data transaction
      FrameLinkUTransaction newTr;
      FrameLinkUTransaction hdrTr;   //Header transaction
      // Default values   
      newTr = null;

      if(inst == "Monitor0")begin
         // Transaction was received by data monitor
         // Extract data, create transaction to remove and remove it from he sc_table
         $cast(dataTr,transaction);

         if(HDR_ENABLE == TRUE  &&  HDR_INSERT == FALSE)begin
            // Process received data
            hdrTr = null;
            processHeaderAndData(newTr,dataTr,hdrTr);
         end else begin
            // This section is called when no header is transfered
            newTr = new;
            newTr.data = dataTr.data;
         end
      end else begin
         // Transaction was received by header monitor
         $cast(hdrTr,transaction);
         dataTr = null;
         processHeaderAndData(newTr,dataTr,hdrTr);
      end

      // Remove the transaction if output
      if (newTr != null) this.sc_table.remove(newTr,status);
      if (status == 0)begin
        $write("Unknown transaction received from monitor %d\n", inst);
        $timeformat(-9, 3, " ns", 8);
        $write("Time: %t\n", $time);
        transaction.display();
        $write("Unknown transaction removed\n", inst);
        this.sc_table.display(); 
        $stop;
      end;
    endtask
 
  endclass : ScoreboardMonitorCbs

  // -- Constructor ---------------------------------------------------------
  // Create a class 
  // --------------------------------------------------------------------------
  // -- Scoreboard
  // --------------------------------------------------------------------------
  class Scoreboard;

    // ---------------------
    // -- Class Variables --
    // ---------------------
    TransactionTable #(TR_TABLE_FIFO) scoreTable;
    ScoreboardMonitorCbs monitorCbs;
    ScoreboardDriverCbs  driverCbs;

    // -- Constructor ---------------------------------------------------------
    // Create a class 
    function new ();
      this.scoreTable = new;
      this.monitorCbs = new(scoreTable);
      this.driverCbs  = new(scoreTable);
    endfunction

    // -- Display -------------------------------------------------------------
    // Create a class 
    task display();
        scoreTable.display();
    endtask
  
  endclass : Scoreboard   
