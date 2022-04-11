// scoreboard.sv
// Copyright (C) 2020 CESNET z. s. p. o.
// Author(s): Jakub Cabal <cabal@cesnet.cz>
//
// SPDX-License-Identifier: BSD-3-Clause

import sv_common_pkg::*;
import sv_mfb_pkg::*;

class ScoreboardMonitorCbs extends MonitorCbs;
    longint cnt;
    int expPktLen;
    
    function new ();
        cnt = 0;
        expPktLen = 0;
    endfunction
    
    virtual task post_rx(Transaction transaction, string inst);
        MfbTransaction #(MFB_ITEM_WIDTH) mfbTrans;
        int pktLen;
        cnt = cnt + 1;
        $cast(mfbTrans, transaction);
        if (mfbTrans.data.size() != expPktLen) begin
            $write("Transaction with bad length! Expected length is %0d.\n", expPktLen);
            $timeformat(-9, 3, " ns", 8);
            $write("Time: %t\n", $time);
            transaction.display();
            $stop;
        end;
    endtask
endclass

class Scoreboard;
    ScoreboardMonitorCbs monitorCbs;

    function new ();
        monitorCbs = new();
    endfunction

    task display();
        $write("%0d transactions received by monitor.\n", this.monitorCbs.cnt);
    endtask

    task setPktLen(int length);
        this.monitorCbs.expPktLen = length;
        this.monitorCbs.cnt = 0;
    endtask
    
    function longint getPktCounter();
        return this.monitorCbs.cnt;
    endfunction;

endclass
