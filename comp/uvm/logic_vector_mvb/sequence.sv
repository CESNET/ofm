//-- sequence.sv: Mvb sequence
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 


class sequence_simple_rx_base #(ITEMS, ITEM_WIDTH) extends uvm_sequence #(uvm_mvb::sequence_item #(ITEMS, ITEM_WIDTH));
    `uvm_object_param_utils(uvm_logic_vector_mvb::sequence_simple_rx_base #(ITEMS, ITEM_WIDTH))
    `uvm_declare_p_sequencer(uvm_mvb::sequencer #(ITEMS, ITEM_WIDTH))

    uvm_logic_vector::sequencer #(ITEM_WIDTH) hi_sqr;
    uvm_logic_vector::sequence_item #(ITEM_WIDTH)    frame;
    uvm_mvb::sequence_item #(ITEMS, ITEM_WIDTH)      gen;
    string name;

    typedef enum {state_last, state_next} state_t;
    local state_t state;

    //////////////////////////////////
    // RANDOMIZATION
    rand int unsigned hl_transactions;
    int unsigned hl_transactions_min =  20;
    int unsigned hl_transactions_max = 300;

    constraint c_hl_transactions{
        hl_transactions inside {[hl_transactions_min:hl_transactions_max]};
    };

    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new(name);
        this.name = name;
    endfunction


    // Generates transactions
    task body;
        // Create a request for sequence item
        if(!uvm_config_db #(uvm_logic_vector::sequencer #(ITEM_WIDTH))::get(p_sequencer, "", "hi_sqr", hi_sqr)) begin
            `uvm_fatal(get_type_name(), "Unable to get configuration object")
        end
        `uvm_info(get_full_name(), $sformatf("%s is running", name), UVM_DEBUG)
        frame = null;
        req = uvm_mvb::sequence_item #(ITEMS, ITEM_WIDTH)::type_id::create("req");
        gen = uvm_mvb::sequence_item #(ITEMS, ITEM_WIDTH)::type_id::create("gen");
        send_empty();
        req.src_rdy = 0;
        gen.src_rdy = 0;
        state = state_next;
        while (hl_transactions > 0 || frame != null || state == state_last) begin
            send(frame);
        end
        //Get last response
        get_response(rsp);
        while (rsp.src_rdy && !rsp.dst_rdy) begin
            start_item(req);
            finish_item(req);
            get_response(rsp);
        end
    endtask

    // Method which define how the transaction will look.
    task send(uvm_logic_vector::sequence_item#(ITEM_WIDTH) frame);

        if (p_sequencer.reset_sync.has_been_reset()) begin
            //SETUP RESET
            gen.randomize() with {src_rdy == 0;};
            state = state_next;
            get_response(rsp);
        end else begin
            if (state == state_next) begin
                create_sequence_item();
            end

            //GET response
            get_response(rsp);

            if (req.src_rdy == 1'b1 && rsp.dst_rdy == 1'b0) begin
                state = state_last;
            end else begin
                state = state_next;
            end
        end

        start_item(req);
        if (state != state_last) begin
            req.copy(gen);
        end
        finish_item(req);
    endtask

    virtual task send_empty();
        start_item(req);
        void'(req.randomize() with {src_rdy == '0;});
        finish_item(req);
    endtask

    // Method which define how the transaction will look.
    virtual task create_sequence_item();
    endtask

endclass

class sequence_simple_rx #(ITEMS, ITEM_WIDTH) extends sequence_simple_rx_base #(ITEMS, ITEM_WIDTH);

    `uvm_object_param_utils(uvm_logic_vector_mvb::sequence_simple_rx #(ITEMS, ITEM_WIDTH))

    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new("sequence_simple_rx");
    endfunction

    virtual task create_sequence_item();
        if (!gen.randomize()) `uvm_fatal(this.get_full_name(), "failed to radnomize");

        //return if src_rdy is zero
        if (gen.src_rdy == 1'b0) begin
            return;
        end

        // generate valid data if src_rdy is set to 1
        for (int i = 0; i < ITEMS; i++) begin
            if (gen.vld[i] == 1'b1 && hl_transactions != 0) begin
                hi_sqr.try_next_item(frame);
                if (frame != null) begin
                    gen.data[i] = frame.data;
                    hi_sqr.item_done();
                    frame = null;
                    hl_transactions--;
                end else begin
                    gen.vld[i] = 1'b0;
                end
            end else begin
                gen.vld[i] = 1'b0;
            end
        end

        if (gen.vld == '0) begin
            gen.src_rdy = 1'b0;
        end
    endtask
endclass


class sequence_rand_rx #(ITEMS, ITEM_WIDTH) extends sequence_simple_rx_base #(ITEMS, ITEM_WIDTH);
    `uvm_object_param_utils(uvm_logic_vector_mvb::sequence_rand_rx #(ITEMS, ITEM_WIDTH))
    uvm_common::rand_rdy rdy;

    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new("sequence_full_speed_rx");
        rdy = uvm_common::rand_rdy_rand::new();
    endfunction

    virtual task create_sequence_item();
        if (!gen.randomize()) `uvm_fatal(this.get_full_name(), "failed to radnomize");

        gen.vld     = 0;
        gen.src_rdy = 1'b0;

        for (int i = 0; i < ITEMS; i++) begin
            rdy.randomize();
            if (hl_transactions != 0 && rdy.m_value == 1'b1) begin
                hi_sqr.try_next_item(frame);
                if (frame != null) begin
                    gen.src_rdy = 1'b1;
                    gen.vld[i]  = 1'b1;
                    gen.data[i] = frame.data;
                    hi_sqr.item_done();
                    frame = null;
                    hl_transactions--;
                end
            end
        end
    endtask
endclass


class sequence_full_speed_rx #(ITEMS, ITEM_WIDTH) extends sequence_simple_rx_base #(ITEMS, ITEM_WIDTH);

    `uvm_object_param_utils(uvm_logic_vector_mvb::sequence_full_speed_rx #(ITEMS, ITEM_WIDTH))

    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new("sequence_full_speed_rx");
    endfunction

    virtual task create_sequence_item();
        if (!gen.randomize()) `uvm_fatal(this.get_full_name(), "failed to radnomize");
        gen.vld     = 0;
        gen.src_rdy = 1'b0;

        for (int i = 0; i < ITEMS; i++) begin
            if (hl_transactions != 0) begin
                hi_sqr.try_next_item(frame);
                if (frame != null) begin
                    gen.src_rdy = 1'b1;
                    gen.vld[i]  = 1'b1;
                    gen.data[i] = frame.data;
                    hi_sqr.item_done();
                    frame = null;
                    hl_transactions--;
                end
            end
        end
    endtask
endclass



class sequence_stop_rx #(ITEMS, ITEM_WIDTH) extends sequence_simple_rx_base #(ITEMS, ITEM_WIDTH);

    `uvm_object_param_utils(uvm_logic_vector_mvb::sequence_stop_rx #(ITEMS, ITEM_WIDTH))

    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new("sequence_stop_rx");
    endfunction

    virtual task create_sequence_item();
        if (!gen.randomize() with {src_rdy == 0;}) `uvm_fatal(this.get_full_name(), "failed to radnomize");
        hl_transactions--;
    endtask
endclass


//////////////////////////////////////
// TX LIBRARY
class sequence_lib_rx#(ITEMS, ITEM_WIDTH) extends uvm_sequence_library#(uvm_mvb::sequence_item#(ITEMS, ITEM_WIDTH));
  `uvm_object_param_utils(uvm_logic_vector_mvb::sequence_lib_rx#(ITEMS, ITEM_WIDTH))
  `uvm_sequence_library_utils(uvm_logic_vector_mvb::sequence_lib_rx#(ITEMS, ITEM_WIDTH))

    function new(string name = "");
        super.new(name);
        init_sequence_library();
    endfunction

    // subclass can redefine and change run sequences
    // can be useful in specific tests
    virtual function void init_sequence();
        this.add_sequence(sequence_rand_rx #(ITEMS, ITEM_WIDTH)::get_type());
        this.add_sequence(sequence_simple_rx#(ITEMS, ITEM_WIDTH)::get_type());
        this.add_sequence(sequence_full_speed_rx#(ITEMS, ITEM_WIDTH)::get_type());
        this.add_sequence(sequence_stop_rx#(ITEMS, ITEM_WIDTH)::get_type());
    endfunction
endclass
