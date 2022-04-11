/* \scoreboard.sv
 * \brief Verification scoreboard
 * \author Daniel Kriz <xkrizd01@vutbr.cz>
 * \date 2020
 */
/*
 * Copyright (C) 2020 CESNET z. s. p. o.
 *
 * LICENSE TERMS
 *
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

import sv_common_pkg::*;
import sv_mfb_pkg::*;
import sv_mvb_pkg::*;
import test_pkg::*;

class TransactionSynchronizator;
    bit                   enabled;
    TransactionTable #(0) sc_table;
    mailbox               mfb_table;
    mailbox               mvb_table;

    function new (TransactionTable #(0) st, mailbox mfb_mbx, mailbox mvb_mbx);
        this.sc_table  = st;
        this.mfb_table = mfb_mbx;
        this.mvb_table = mvb_mbx;
    endfunction

    task setEnabled();
        enabled = 1; // Model enabling
        fork
            run(); // Creating model subproccess
        join_none // Don't wait for ending
    endtask

    task setDisabled();
        enabled = 0; // Disable model
    endtask

    task run();
        Transaction mbx_mfb_tr;
        MfbTransaction #(MFB_ITEM_WIDTH, MFB_META_WIDTH) mfb_tr;
        Transaction mbx_mvb_tr;
        MvbTransaction #(MVB_ITEM_WIDTH) mvb_tr;
        MfbTransaction #(MFB_ITEM_WIDTH, NEW_META_WIDTH) ext_tr;

        while(enabled) begin // Repeat while enabled

            wait((mfb_table.num() != 0) || (!enabled))

            if(!enabled) begin
                continue;
            end

            mfb_table.get(mbx_mfb_tr);
            $cast(mfb_tr, mbx_mfb_tr);

            mvb_table.get(mbx_mvb_tr);
            $cast(mvb_tr, mbx_mvb_tr);

            if(VERBOSE >= 1) begin
                $write("MVB TRANSACTION");
                mvb_tr.display();
                $write("MFB TRANSACTION");
                mfb_tr.display();
            end;

            ext_tr = new;
            ext_tr.data = mfb_tr.data;
            ext_tr.meta = {mfb_tr.meta,mvb_tr.data};

            sc_table.add(ext_tr);
        end
    endtask

endclass

class ScoreboarMFBDriverCbs extends DriverCbs;
    mailbox RxMbx;

    function new (mailbox Mbx);
        this.RxMbx = Mbx;
    endfunction
    
    virtual task pre_tx(ref Transaction transaction, string inst);
        RxMbx.put(transaction);
    endtask
    
    virtual task post_tx(Transaction transaction, string inst);
    endtask

endclass

class ScoreboardMVBDriverCbs extends DriverCbs;
    mailbox RxMbx;

    function new (mailbox Mbx);
        this.RxMbx = Mbx;
    endfunction
    
    virtual task pre_tx(ref Transaction transaction, string inst);
        RxMbx.put(transaction);
    endtask
    
    virtual task post_tx(Transaction transaction, string inst);
    endtask
endclass

class ScoreboardMonitorMfbCbs extends MonitorCbs;
    
    TransactionTable #(0) sc_table;

    function new (TransactionTable #(0) st);
        this.sc_table = st;
    endfunction
    
    virtual task post_rx(Transaction transaction, string inst);
        bit status=0;
        MfbTransaction #(MFB_ITEM_WIDTH,NEW_META_WIDTH) mfb_tr;
        $cast(mfb_tr, transaction);
        mfb_tr.check_meta = 1;
        sc_table.remove(mfb_tr, status);
        if (status==0)begin
            $write("Unknown transaction received from monitor %s\n", inst);
            $timeformat(-9, 3, " ns", 8);
            $write("Time: %t\n", $time);
            mfb_tr.display();
            sc_table.display();
            $stop;
        end;
    endtask

endclass

class Scoreboard;

    TransactionSynchronizator model;
    TransactionTable #(0) scoreTable;
    mailbox   rx_mvbMbx;
    mailbox   rx_mfbMbx;
    ScoreboardMonitorMfbCbs monitorCbs;
    ScoreboarMFBDriverCbs mfbDriverCbs;
    ScoreboardMVBDriverCbs mvbDriverCbs;

    function new ();
        scoreTable = new;
        rx_mfbMbx = new();
        rx_mvbMbx = new();
        monitorCbs = new(scoreTable);
        mfbDriverCbs  = new(rx_mfbMbx);
        mvbDriverCbs = new(rx_mvbMbx);
        model = new(scoreTable,rx_mfbMbx, rx_mvbMbx);
    endfunction

    task setDisabled();
        wait(scoreTable.added == scoreTable.removed);
        model.setDisabled(); // Disable model
    endtask

    task setEnabled();
        model.setEnabled(); // Enable model
    endtask

    task display();
        scoreTable.display();
    endtask
  
endclass
