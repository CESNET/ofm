/*
 * file       : sequence.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: RESET sequnece 
 * date       : 2021
 * author     : Radek Iša <isa@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/


/* first seuqnce generate restart on start and then generate no reset */
class sequence_reset extends uvm_sequence#(reset::sequence_item);
    `uvm_object_utils(reset::sequence_reset)

    int unsigned length_min = 2;
    int unsigned length_max = 20;
    rand int unsigned length;

    constraint c_reset {length inside {[length_min:length_max]};};

    function new (string name = "sequence_reset");
        super.new(name);
    endfunction

    task body;
        req = sequence_item::type_id::create("req");


        repeat(length) begin
            start_item(req);
            req.reset = 1'b1;
            finish_item(req);
        end
    endtask
endclass


class sequence_run extends uvm_sequence#(reset::sequence_item);
    `uvm_object_utils(reset::sequence_run)

    int unsigned length_min =  10000;
    int unsigned length_max = 400000;
    rand int unsigned length;

    constraint c_reset {length inside {[length_min:length_max]};};

    function new (string name = "sequence_reset");
        super.new(name);
    endfunction

    task body;
        req = sequence_item::type_id::create("req");


        repeat(length) begin
            start_item(req);
            req.reset = 1'b0;
            finish_item(req);
        end
    endtask
endclass

class sequence_simple extends uvm_sequence#(reset::sequence_item);
    `uvm_object_utils(reset::sequence_simple)
    `uvm_declare_p_sequencer(reset::sequencer);

    sequence_reset reset;
    sequence_run   run;

    function new (string name = "sequence_reset");
        super.new(name);

        reset = sequence_reset::type_id::create({name, "_RESET"});
        run   = sequence_run::type_id::create({name, "_RUN"});
    endfunction

    task body;
        forever begin
            reset.randomize();
            reset.start(p_sequencer);
            run.randomize();
            run.start(p_sequencer);
        end
    endtask
endclass

class sequence_start extends uvm_sequence#(reset::sequence_item);
    `uvm_object_utils(reset::sequence_start)
    `uvm_declare_p_sequencer(reset::sequencer);

    sequence_reset reset;
    sequence_run   run;

    function new (string name = "sequence_reset");
        super.new(name);

        reset = sequence_reset::type_id::create({name, "_RESET"});
        run   = sequence_run::type_id::create({name, "_RUN"});
    endfunction

    task body;
        reset.randomize();
        reset.start(p_sequencer);
        forever begin
            run.randomize();
            run.start(p_sequencer);
        end
    endtask
endclass



/* second sequence generate no reset */
 /* first seuqnce generate restart on start and then generate no reset */
class sequence_rand extends uvm_sequence#(reset::sequence_item);
    `uvm_object_utils(reset::sequence_rand)

    int unsigned reset_dist = 1;
    int unsigned run_dist   = 200000;

    function new (string name = "sequence_rand");
        super.new(name);
    endfunction

    task body;
        forever begin
           `uvm_do_with(req, {reset dist {1'b1 :/ reset_dist, 1'b0 :/ run_dist };});
            if (req.reset == 1'b1) begin
               `uvm_do_with(req, {reset == 1'b1;});
            end
        end
    endtask
endclass

