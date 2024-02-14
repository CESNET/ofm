//-- pkg.sv: Package for environment
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

`ifndef LL_DMA_ENV_SV
`define LL_DMA_ENV_SV

package uvm_dma_ll;

    `include "uvm_macros.svh"
    import uvm_pkg::*;

    `include "sequence.sv"
    `include "sequencer.sv"
    `include "model.sv"
    `include "scoreboard.sv"
    `include "env.sv"

endpackage

`endif
