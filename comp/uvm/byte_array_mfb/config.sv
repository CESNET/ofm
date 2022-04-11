//-- config.sv: Configuration object for whole mfb env
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

class config_item extends uvm_object;

    // ------------------------------------------------------------------------ 
    // configuration variables
    uvm_active_passive_enum active;
    string interface_name;
    int unsigned meta_behav;    // Metadata behaviour -----------------------------
                                // 0 meen that metadata are not generating 
                                // 1 meen that metadata are paird with SOF pozition
                                // 2 meen that metadata are paird with EOF pozition
                                // ------------------------------------------------

    // ------------------------------------------------------------------------ 
    // functions
    function new (string name = "");
        super.new(name);
    endfunction
endclass
