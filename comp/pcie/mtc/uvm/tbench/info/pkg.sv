//-- pkg.sv
//-- Copyright (C) 2023 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause


`ifndef PCIE_HDR_PKG
`define PCIE_HDR_PKG

package uvm_pcie_hdr;

    `include "uvm_macros.svh"
    import uvm_pkg::*;

    `include "sync_tag.sv"
    `include "config.sv"
    `include "sequence_item.sv"
    `include "sequencer.sv"
    `include "sequence.sv"
    `include "monitor.sv"
    `include "agent.sv"

    function logic[3-1 : 0] encode_type(logic [8-1 : 0] req_type, logic intel);
        logic[3-1 : 0] ret;
        if (intel) begin
            case (req_type)
                // READ
                8'b00000000 : ret = 3'b000;
                8'b00100000 : ret = 3'b000;
                // Read locked
                // 8'b00000001 : ret = 3'b000;
                // 8'b00100001 : ret = 3'b000;
                // // IORead
                // 8'b00000010 : ret = 3'b000;
                // // Cfg Read
                // 8'b00000100 : ret = 3'b000;
                // 8'b00000101 : ret = 3'b000;
                // // CPL Read
                // 8'b00001010 : ret = 3'b000;
                // 8'b00001011 : ret = 3'b000;

                // WRITE;
                8'b01100000 : ret = 3'b001;
                8'b01000000 : ret = 3'b001;
                // IOWrite
                // 8'b01000010 : ret = 3'b001;
                // // Cfg Write
                // 8'b01000100 : ret = 3'b001;
                // 8'b01000101 : ret = 3'b001;
                // // Cpl Write
                // 8'b01001010 : ret = 3'b001;
                // 8'b01001011 : ret = 3'b001;
                // // FetchAdd (Write)
                // // 3DW addr
                // 8'b01001100 : ret = 3'b001;
                // // 4DW addr
                // 8'b01101100 : ret = 3'b001;
                // // Swap (Write)
                // // 3DW addr
                // 8'b01001101 : ret = 3'b001;
                // // 4DW addr
                // 8'b01101101 : ret = 3'b001;
                // // CAS (Write)
                // // 3DW addr
                // 8'b01001110 : ret = 3'b001;
                // // 4DW addr
                // 8'b01101110 : ret = 3'b001;

                // MSG
                8'b00110000 : ret = 3'b010;
                8'b00110001 : ret = 3'b010;
                8'b00110010 : ret = 3'b010;
                8'b00110011 : ret = 3'b010;
                8'b00110100 : ret = 3'b010;
                8'b00110101 : ret = 3'b010;
                // MSGd
                8'b01110000 : ret = 3'b011;
                8'b01110001 : ret = 3'b011;
                8'b01110010 : ret = 3'b011;
                8'b01110011 : ret = 3'b011;
                8'b01110100 : ret = 3'b011;
                8'b01110101 : ret = 3'b011;
                // ERROR
                default     : ret = 3'b100;
            endcase
        end else begin
            case (req_type[4-1 : 0])
                // READ
                4'b0000 : ret = 3'b000;
                // WRITE;
                4'b0001 : ret = 3'b001;
                // ERROR
                default : ret = 3'b100;
            endcase
        end
        return ret;
    endfunction

endpackage

`endif
