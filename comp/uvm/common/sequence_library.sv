/*
 * file       :  sequence_library.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: Iproved sequence library  
 * date       : 2021
 * author     : Radek Iša <isa@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/

class sequence_library#(type CONFIG_TYPE, REQ=uvm_sequence_item, RSP=REQ) extends uvm_sequence_library#(REQ, RSP);
    `uvm_object_param_utils(uvm_common::sequence_library#(CONFIG_TYPE, REQ, RSP))
    //`uvm_sequence_library_utils(uvm_byte_array::sequence_lib)

    CONFIG_TYPE cfg;

    function new(string name = "sequence_library");
        super.new(name);
        cfg = null;
    endfunction

    // subclass can redefine and change run sequences
    // can be useful in specific tests
    virtual function void init_sequence(CONFIG_TYPE param_cfg = null);
        if (param_cfg == null) begin
            this.cfg = new();
        end else begin
            this.cfg = param_cfg;
        end
    endfunction

    task body();
        if (cfg == null) begin
            cfg = new();
        end

        super.body();
    endtask

    // execute
    // -------
    task execute(uvm_object_wrapper wrap);
        sequence_base#(CONFIG_TYPE, REQ, RSP) cast_sequence;

        uvm_object obj;
        uvm_sequence_item seq_or_item;
        uvm_sequence_base seq_base;
        REQ req_item;
        uvm_coreservice_t cs = uvm_coreservice_t::get();
        uvm_factory factory=cs.get_factory();

        obj = factory.create_object_by_type(wrap,get_full_name(), $sformatf("%s:%0d",wrap.get_type_name(), sequences_executed+1));
        //$write("TEST %s:%0d\n", wrap.get_type_name(), sequences_executed);

        if (!$cast(seq_base, obj)) begin
           // If we're executing an item (not a sequence)
           if (!$cast(req_item, obj)) begin
              // But it's not our item type (This can happen if we were parameterized with
              // a pure virtual type, because we're getting get_type() from the base class)
              `uvm_error("SEQLIB/WRONG_ITEM_TYPE", {"The item created by '", get_full_name(), "' when in 'UVM_SEQ_LIB_ITEM' mode doesn't match the REQ type which  was passed in to the uvm_sequence_library#(REQ[,RSP]), this can happen if the REQ type which was passed in was a pure-virtual type.  Either configure the factory overrides to properly generate items for this sequence library, or do not execute this sequence library in UVM_SEQ_LIB_ITEM mode."})
               return;
           end
        end

        if ($cast(cast_sequence, obj)) begin
            cast_sequence.config_set(cfg);
        end

        void'($cast(seq_or_item,obj)); // already qualified, 

        `uvm_info("SEQLIB/EXEC",{"Executing ",(seq_or_item.is_item() ? "item " : "sequence "),seq_or_item.get_name(),
                                 " (",seq_or_item.get_type_name(),")"},UVM_FULL)
        seq_or_item.print_sequence_info = 1;
        `uvm_rand_send(seq_or_item)
        seqs_distrib[seq_or_item.get_type_name()] = seqs_distrib[seq_or_item.get_type_name()]+1;

        sequences_executed++;
    endtask

endclass
