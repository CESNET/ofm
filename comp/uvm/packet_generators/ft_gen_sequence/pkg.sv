// pkg.sv: Package for sequence_flowtest
// Copyright (C) 2024 CESNET z. s. p. o.
// Author(s): Yaroslav Marushchenko <xmarus09@stud.fit.vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause

`ifndef UVM_SEQUENCE_FLOWTEST_PKG
`define UVM_SEQUENCE_FLOWTEST_PKG

package uvm_sequence_flowtest;

    `include "uvm_macros.svh"
    import uvm_pkg::*;

    parameter GENERATOR_EXECUTE_PATH = "ft-generator";
    parameter CONFIG_GENERATOR_EXECUTE_PATH = { "`dirname ", `__FILE__, "`/tools/config_generator.py" };
    parameter PROFILE_GENERATOR_EXECUTE_PATH = { "`dirname ", `__FILE__, "`/tools/profile_generator.py" };

    `include "sequence.sv"

endpackage

`endif
