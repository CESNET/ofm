//-- pkg.sv: Package for environment
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

`ifndef LL_DMA_REGS_SV
`define LL_DMA_REGS_SV

package uvm_dma_regs;

    `include "uvm_macros.svh"
    import uvm_pkg::*;

    `include "registers.sv"
    `include "reg_channel.sv"
    `include "regmodel.sv"
    `include "reg_sequence.sv"

endpackage

`endif
