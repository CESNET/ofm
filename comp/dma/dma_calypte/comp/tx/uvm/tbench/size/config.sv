// config.sv
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause

class config_sequence extends uvm_object;
    // this configuration is aproximation
    // there is no quratte that currently running sequence will follow this rules.

    // this configuration works for all sequences run by sequences library.
    // if two sequences will run by sequences library then 20 to 400 transactios
    // are going to be generated
    int unsigned transaction_count_min = 10;   // size have to be bigger than zero
    int unsigned transaction_count_max = 20;

    function void transaction_count_set(int unsigned min, int unsigned max);
        transaction_count_min = min;
        transaction_count_max = max;
    endfunction
endclass

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

