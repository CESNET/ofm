// pkg.sv: Package for environment
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


`ifndef CHECKSUM_CALCULATOR_ENV_SV
`define CHECKSUM_CALCULATOR_ENV_SV

package uvm_checksum_calculator;
    
    `include "uvm_macros.svh"
    import uvm_pkg::*;

    `include "sequencer.sv"
    `include "sequence.sv"
    `include "driver.sv"
    `include "model.sv"
    `include "scoreboard_cmp.sv"
    `include "scoreboard.sv"
    `include "env.sv"

endpackage

`endif
