//-- config.sv
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Radek Iša <isa@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

class config_item extends uvm_object;

   ////////////////
   // configuration variables
   uvm_active_passive_enum active;

   ////////////////
   // functions
   function new (string name = "");
       super.new(name);
   endfunction
endclass

