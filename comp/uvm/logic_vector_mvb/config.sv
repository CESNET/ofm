//-- config.sv: Configuration object for whole mvb env
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

class config_item extends uvm_object;

    // ------------------------------------------------------------------------ 
    // configuration variables
    uvm_active_passive_enum active;
    string interface_name;
    // functions
    function new (string name = "");
        super.new(name);
    endfunction
endclass
