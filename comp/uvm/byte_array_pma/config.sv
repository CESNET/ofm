/*
 * file       : config.sv
 * description: Configuration file for rx environment.
 * date       : 2021
 * author     : Daniel Kriz <xkrizd01@vutbr.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (C) 2021 CESNET z. s. p. o.
*/

`ifndef RX_ENV_CONFIG_SV
`define RX_ENV_CONFIG_SV

class config_item extends uvm_object;

   // configuration variables
   uvm_active_passive_enum active;
   string interface_name;

   // functions
   function new (string name = "");
       super.new(name);
   endfunction
endclass

`endif
