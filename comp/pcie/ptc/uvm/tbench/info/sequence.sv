//-- sequence.sv
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause


// Reusable high level sequence. Contains transaction, which has only data part.
class sequence_simple #(MRRS) extends uvm_sequence #(uvm_ptc_info::sequence_item);
    `uvm_object_utils(uvm_ptc_info::sequence_simple #(MRRS))

    rand int unsigned transaction_count;
    int unsigned transaction_count_min = 100;
    int unsigned transaction_count_max = 100;

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}

    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new(name);
    endfunction

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "uvm_ptc_info::sequence_simple is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            `uvm_do_with(req, {{req.length inside {[2 : MRRS]}}; });
        end
    endtask

endclass

class sequence_simple_write extends uvm_sequence #(uvm_ptc_info::sequence_item);
    `uvm_object_utils(uvm_ptc_info::sequence_simple_write)

    rand int unsigned transaction_count;
    int unsigned transaction_count_min = 100;
    int unsigned transaction_count_max = 100;

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}

    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new(name);
    endfunction

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "uvm_ptc_info::sequence_simple_write is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            `uvm_do_with(req, {(req.type_ide == sv_dma_bus_pack::DMA_REQUEST_TYPE_WRITE);});
        end
    endtask

endclass

class sequence_simple_read #(MRRS) extends uvm_sequence #(uvm_ptc_info::sequence_item);
    `uvm_object_utils(uvm_ptc_info::sequence_simple_read #(MRRS))

    rand int unsigned transaction_count;
    int unsigned transaction_count_min = 100;
    int unsigned transaction_count_max = 100;

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}

    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new(name);
    endfunction

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "uvm_ptc_info::sequence_simple_read is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            `uvm_do_with(req, {(req.type_ide == sv_dma_bus_pack::DMA_REQUEST_TYPE_READ); {req.length inside {[2 : MRRS]}}; });
        end
    endtask

endclass

class sequence_lib_info #(MRRS) extends uvm_sequence_library#(uvm_ptc_info::sequence_item);
    `uvm_object_param_utils(uvm_ptc_info::sequence_lib_info #(MRRS))
    `uvm_sequence_library_utils(uvm_ptc_info::sequence_lib_info #(MRRS))

    function new(string name = "");
      super.new(name);
      init_sequence_library();
    endfunction

    virtual function void init_sequence();
        this.add_sequence(uvm_ptc_info::sequence_simple#(MRRS)::get_type());
        this.add_sequence(uvm_ptc_info::sequence_simple_write::get_type());
        this.add_sequence(uvm_ptc_info::sequence_simple_read#(MRRS)::get_type());
    endfunction
endclass
