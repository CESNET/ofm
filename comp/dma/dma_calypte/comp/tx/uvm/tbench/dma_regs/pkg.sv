//-- pkg.sv: Package for environment
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

`ifndef TX_DMA_CALYPTE_REGS_SV
`define TX_DMA_CALYPTE_REGS_SV

package uvm_tx_dma_calypte_regs;

    `include "uvm_macros.svh"
    import uvm_pkg::*;

    `include "registers.sv"
    `include "reg_channel.sv"
    `include "regmodel.sv"
    `include "reg_sequence.sv"

endpackage

`endif
