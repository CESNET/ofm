// pkg.sv: Package for sequence library
// Copyright (C) 2024 CESNET z. s. p. o.
// Author(s): Yaroslav Marushchenko <xmarus09@stud.fit.vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause

`ifndef UVM_PACKET_GENERATOR_SEQUENCE_LIBRARY_PKG
`define UVM_PACKET_GENERATOR_SEQUENCE_LIBRARY_PKG

package uvm_packet_generator_sequence_library;

    `include "uvm_macros.svh"
    import uvm_pkg::*;

    `include "sequence_library.sv"

endpackage

`endif
