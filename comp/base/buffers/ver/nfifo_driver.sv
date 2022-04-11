/*
 * nfifo_driver.sv: nFifo Driver
 * Copyright (C) 2008 CESNET
 * Author(s): Marcela Simkova <xsimko03@stud.fit.vutbr.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * $Id$
 *
 * TODO:
 *
 */
 
  // --------------------------------------------------------------------------
  // -- nFifo Driver Class
  // --------------------------------------------------------------------------
  /* This class is responsible for generating signals to nFifo
   * interface. Transactions are received by 'transMbx'(Mailbox) property.
   * Unit must be enabled by "setEnable()" function call. Generation can be
   * stoped by "setDisable()" function call. You can send your custom
   * transaction by calling "sendTransaction" function.
   */
  class nFifoDriver #(int pDataWidth=64,int pFlows=8,int pBlSize=512,int pLutMem=0, pGlobSt=0);

    // -- Private Class Atributes --
    string    inst;                             // Driver identification
    int       ifcNo;                            // Number of connected interface
    bit       enabled;                          // Driver is enabled
    tTransMbx transMbx;                         // Transaction mailbox
    DriverCbs cbs[$];                           // Callbacks list
    virtual iNFifoRx.nfifo_write_tb #(pDataWidth,pFlows,pBlSize,pLutMem,pGlobSt) f_w;
    
    // ----
    rand bit enFwDelay;   // Enable/Disable delays between transactions
      // Enable/Disable delays between transaction (weights)
      int fwDelayEn_wt             = 1; 
      int fwDelayDisable_wt        = 3;

    rand integer fwDelay; // Delay between transactions
      // Delay between transactions limits
      int fwDelayLow          = 0;
      int fwDelayHigh         = 3;
    // ----
    
    // -- Constrains --
    constraint cDelays {
      enFwDelay dist { 1'b1 := fwDelayEn_wt,
                       1'b0 := fwDelayDisable_wt
                     };

      fwDelay inside {
                      [fwDelayLow:fwDelayHigh]
                     };
      }
    
    // -- Public Class Methods --

    // -- Constructor ---------------------------------------------------------
    // Create driver object 
    function new ( string inst,
                   int ifcNo, 
                   tTransMbx transMbx, 
                   virtual iNFifoRx.nfifo_write_tb #(pDataWidth,pFlows,pBlSize,pLutMem,pGlobSt) f_w
                         );
      this.enabled     = 0;            // Driver is disabled by default
      this.f_w         = f_w;          // Store pointer interface 
      this.transMbx    = transMbx;     // Store pointer to mailbox
      this.inst        = inst;         // Store driver identifier
      this.ifcNo       = ifcNo;       // Store number of connected interface

      this.f_w.nfifo_write_cb.DATA_IN      <= 0;
      this.f_w.nfifo_write_cb.WRITE        <= 0;
                 
    endfunction: new  
        
    // -- Set Callbacks -------------------------------------------------------
    // Put callback object into List 
    function void setCallbacks(DriverCbs cbs);
      this.cbs.push_back(cbs);
    endfunction : setCallbacks
    
    // -- Enable Driver -------------------------------------------------------
    // Enable driver and runs driver process
    task setEnabled();
      enabled = 1; // Driver Enabling
      fork         
        run();     // Creating driver subprocess
      join_none;   // Don't wait for ending
    endtask : setEnabled
        
    // -- Disable Driver ------------------------------------------------------
    // Disable generator
    task setDisabled();
      enabled = 0; // Disable driver, after sending last transaction it ends
    endtask : setDisabled
    
    // -- Send Transaction ----------------------------------------------------
    // Send transaction to Frame Link interface
    task sendTransaction( BufferTransaction transaction );
      Transaction tr;
      $cast(tr, transaction);
      
      // Call transaction preprocesing, if is available
      foreach (cbs[i]) cbs[i].pre_tx(tr, inst);
      
      // Wait before sending transaction
      if (enFwDelay) repeat (fwDelay) @(f_w.nfifo_write_cb);
      
      // Set correct number of connected interface
      transaction.num_block_addr = ifcNo;

      // Send transaction
      sendData(transaction);
      
      // Set not ready
      f_w.nfifo_write_cb.WRITE  <= 0;
      
      // Call transaction postprocesing, if is available
      foreach (cbs[i]) cbs[i].post_tx(tr, inst);
      
    endtask : sendTransaction   
      
     
    
    // -- Private Class Methods --
    
    // -- Run Driver ----------------------------------------------------------
    // Take transactions from mailbox and generate them to interface
    task run();
      BufferTransaction transaction;
      Transaction to;
      @(f_w.nfifo_write_cb);             // Wait for clock
      while (enabled) begin            // Repeat while enabled
        transMbx.get(to);              // Get transaction from mailbox
        $cast(transaction,to);
        assert(randomize());
        sendTransaction(transaction);  // Send Transaction
//        transaction.display("DRIVER");
      end
    endtask : run
    
    // -- Wait for not FULL ---------------------------------------------------
    // It waits until not FULL and READ
    task waitForNotFull();
      do begin        
          @(f_w.nfifo_write_cb);          
      end while (f_w.nfifo_write_cb.FULL);
    endtask : waitForNotFull
    
    // -- Send transaction data -----------------------------------------------
    // Send transaction data
    task sendData(BufferTransaction tr);
      logic [pDataWidth-1:0] dataToSend = 0;
      integer m=0;
      
      for (integer i=0; i<pFlows; i++) begin
        for (integer j=0; j<(tr.data.size/pFlows); j++)
          dataToSend[j]=tr.data[m++];
        f_w.nfifo_write_cb.DATA_IN <= dataToSend; 
        f_w.nfifo_write_cb.WRITE <= 1;
        waitForNotFull();
      end  
       
    endtask : sendData
     
  endclass : nFifoDriver 

