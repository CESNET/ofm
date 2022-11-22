/*
 * file       : pkg.sv
 * Copyright (C) 2022 CESNET z. s. p. o.
 * description: dpi for mi interface 
 * date       : 2022
 * author     : Radek Iša <isa@cesnet.ch>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/

`ifndef MI_DPI_PKG
`define MI_DPI_PKG

package nfb_driver;

    `include "uvm_macros.svh"
    import uvm_pkg::*;

    import "DPI-C" function chandle nfb_sv_create(string path, int unsigned msg_size_max = 2048);
    import "DPI-C" function int     nfb_sv_cmd_get(chandle id, output int unsigned cmd, output int unsigned data_size, output logic [64-1:0] offset);
    import "DPI-C" function void    nfb_sv_data_get(chandle id, inout byte unsigned data[]);
    import "DPI-C" function int     nfb_sv_cmd_send(chandle id, int unsigned cmd, byte unsigned data[]);
    import "DPI-C" function void    nfb_sv_close(chandle id, string path);

    import "DPI-C" function int      getpid();

    `include "controler.sv"
    `include "mi_sequence.sv"

endpackage

`endif
