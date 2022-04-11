//-- pkg.sv: Package for environment
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

`ifndef SPLITTER_SIMPLE_GEN_ENV_SV
`define SPLITTER_SIMPLE_GEN_ENV_SV

package splitter_simple_env;
    
    `include "uvm_macros.svh"
    import uvm_pkg::*;

    //`include "sequencer.sv"
    `include "model.sv"
    `include "scoreboard.sv"
    `include "env.sv"

endpackage

`endif
