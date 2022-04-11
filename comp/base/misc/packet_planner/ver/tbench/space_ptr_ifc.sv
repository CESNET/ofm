//-- afull_ifc.sv: Interface for almost full interface.
//-- Copyright (C) 2020 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

// /////////////////////////////////////////////////////////////////////////////
// Interface for changing pointer

interface iPtr(input logic CLK);

    logic [SPACE_GLB_PTR-1:0] SPACE_GLB_RD_PTR=0;

    clocking cb @(posedge CLK);
        default input #1step output #500ps;
        output SPACE_GLB_RD_PTR;
    endclocking;

    modport dut(input SPACE_GLB_RD_PTR);
    
    modport tb(clocking cb);

endinterface
