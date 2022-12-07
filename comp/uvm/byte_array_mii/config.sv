/*
 * file       : config.sv
 * Copyright (C) 2022 CESNET z. s. p. o.
 * description: General Byte array - MII UVM config
 * date       : 2022
 * author     : Oliver Gurka <xgurka00@stud.fit.vutbr.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/

`ifndef BYTE_ARRAY_MII_CONFIG_SV
`define BYTE_ARRAY_MII_CONFIG_SV

class config_item extends uvm_object;

    // ------------------------------------------------------------------------
    // Configuration variables
    uvm_active_passive_enum active;
    string interface_name;

    // ------------------------------------------------------------------------
    // Constructor
    function new (string name = "");
        super.new(name);
    endfunction

endclass

`endif