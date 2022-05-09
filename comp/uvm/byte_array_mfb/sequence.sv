//-- sequence.sv: Mfb sequence
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 



// This low level sequence define bus functionality
class sequence_simple_rx_base #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) extends uvm_sequence #(mfb::sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH));
    `uvm_object_param_utils(byte_array_mfb_env::sequence_simple_rx_base #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH))
    `uvm_declare_p_sequencer(mfb::sequencer#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH));

    int unsigned space_size = 0;
    int unsigned                              data_index;
    byte_array::sequence_item                 data;
    logic_vector::sequence_item #(META_WIDTH) meta;
    sequencer_rx #(META_WIDTH)                                          hl_sqr;
    mfb::sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH)  gen;
    typedef enum {state_last, state_next, state_reset} state_t;
    state_t state;

    typedef enum {state_packet_none, state_packet_new, state_packet_data, state_packet_space, state_packet_space_new} state_packet_t;
    state_packet_t state_packet;

    rand int unsigned hl_transactions;
    int unsigned hl_transactions_min = 10;
    int unsigned hl_transactions_max = 100;

    constraint c_hl_transations {
        hl_transactions inside {[hl_transactions_min:hl_transactions_max]};
    }

    function new(string name = "sequence_simple_rx_base");
        super.new(name);
    endfunction

    virtual task create_sequence_item();
    endtask

    task send_empty_frame();
        start_item(req);
        req.randomize();
        req.SRC_RDY = 0;
        finish_item(req);
    endtask

    task try_get();
        if (data == null && hl_transactions != 0) begin
            hl_sqr.m_data.try_next_item(data);
            data_index = 0;
            if (data != null) begin
                if (META_WIDTH != 0) begin
                    hl_sqr.m_meta.get_next_item(meta);
                end
                hl_transactions--;
                state_packet = state_packet_new;
            end else begin
                state_packet = state_packet_none;
            end
        end
    endtask

    task reset_handle();
        //wait until stop reset
        while (p_sequencer.reset_sync.has_been_reset()) begin
            //SETUP RESET
            if (data != null) begin
                hl_sqr.m_data.item_done();
                if (META_WIDTH != 0) begin
                    hl_sqr.m_meta.item_done();
                end
                data = null;
                meta = null;
            end

            state_packet = state_packet_space_new;
            send_empty_frame();
            get_response(rsp);
        end
    endtask

    task send_frame();
        // get next item
        if (state == state_next) begin
            create_sequence_item();
        end

        //GET response
        get_response(rsp);
        if (rsp.SRC_RDY == 1'b1 && rsp.DST_RDY == 1'b0) begin
            state = state_last;
        end else begin
            state = state_next;
        end

        if (p_sequencer.reset_sync.has_been_reset()) begin
            if (data != null) begin
                hl_sqr.m_data.item_done();
                if (META_WIDTH != 0) begin
                    hl_sqr.m_meta.item_done();
                end
                data = null;
                meta = null;
            end

            gen.randomize();
            gen.SRC_RDY = 0;
            state_packet = state_packet_space_new;
            state = state_next;
        end

        //SEND FRAME
        start_item(req);
        if (state != state_last) begin
            req.copy(gen);
        end
        finish_item(req);
    endtask

    task body;
        if(!uvm_config_db#(sequencer_rx #(META_WIDTH))::get(p_sequencer, "" , "hl_sqr", hl_sqr)) begin
            `uvm_fatal(p_sequencer.get_full_name(), "\n\tsequence sequence_simple_rx cannot get hl_sqr");
        end

        data = null;
        meta = null;
        space_size = 0;
        state_packet = state_packet_space_new;

        req = mfb::sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH)::type_id::create("req");
        gen = mfb::sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH)::type_id::create("reg");

        //send empty frame to get first response
        send_empty_frame();
        //when reset on start then wait
        req.SRC_RDY = 0;
        gen.SRC_RDY = 0;
        state = state_next;

        while (hl_transactions > 0 || data != null || state == state_last || gen.SRC_RDY == 1) begin
            send_frame();
        end
        //Get last response
        get_response(rsp);
    endtask
endclass


class sequence_simple_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) extends sequence_simple_rx_base #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH);
    `uvm_object_param_utils(byte_array_mfb_env::sequence_simple_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH))
    common::rand_length   rdy_length;
    common::rand_rdy      rdy_rdy;

    function new (string name = "req");
        super.new(name);
        rdy_length = common::rand_length_rand::new();
        rdy_rdy    = common::rand_rdy_rand::new();
    endfunction

    /////////
    // CREATE intel_mac_seg::Sequence_item
    virtual task create_sequence_item();
        int unsigned index = 0;
        gen.randomize();

        //randomization of rdy
        void'(rdy_rdy.randomize());
        if (rdy_rdy.m_value == 0) begin
            gen.SRC_RDY = 0;
            return;
        end

        gen.SRC_RDY = 0;
        gen.SOF     = '0;
        gen.EOF     = '0;

        for (int unsigned it = 0; it < REGIONS; it++) begin
            int unsigned index = 0;
            while (index < REGION_SIZE) begin
                if (state_packet == state_packet_space_new) begin
                    void'(rdy_length.randomize());
                    space_size = rdy_length.m_value;
                    state_packet = state_packet_space;
                end


                if (state_packet == state_packet_space) begin
                    if (space_size != 0) begin
                        space_size--;
                    end else begin
                        state_packet = state_packet_none;
                    end
                end

                if (state_packet == state_packet_none) begin
                    try_get();
                end

                if (state_packet == state_packet_new) begin
                    // Check SOF and EOF position if we can insert packet into this region
                    if (gen.SOF[it] == 1 || (gen.EOF[it] == 1'b1 && (REGION_SIZE*BLOCK_SIZE) > (index*BLOCK_SIZE + data.data.size()))) begin
                        break;
                    end

                    gen.SOF[it]     = 1'b1;
                    gen.SOF_POS[it] = index;
                    if (hl_sqr.meta_behav == 1 && META_WIDTH != 0) begin
                        gen.META[it] = meta.data;
                    end 
                    state_packet = state_packet_data;
                end

                if (state_packet == state_packet_data) begin
                    int unsigned loop_end   = BLOCK_SIZE < (data.data.size() - data_index) ? BLOCK_SIZE : (data.data.size() - data_index);
                    gen.SRC_RDY = 1;

                    for (int unsigned jt = index*BLOCK_SIZE; jt < (index*BLOCK_SIZE + loop_end); jt++) begin
                        gen.ITEMS[it][(jt+1)*ITEM_WIDTH-1 -: ITEM_WIDTH] = data.data[data_index];
                        data_index++;
                    end

                    // End of packet
                    if (data.data.size() <= data_index) begin
                        if (hl_sqr.meta_behav == 2 && META_WIDTH != 0) begin
                            gen.META[it] = meta.data;
                        end                        gen.EOF[it]     = 1'b1;
                        gen.EOF_POS[it] = index*BLOCK_SIZE + loop_end-1;
                        data = null;
                        hl_sqr.m_data.item_done();
                        if (META_WIDTH != 0) begin
                            hl_sqr.m_meta.item_done();
                        end
                        state_packet = state_packet_space_new;
                    end
                end

                index++;
            end
        end
    endtask
endclass

class sequence_full_speed_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) extends sequence_simple_rx_base #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH);
    `uvm_object_param_utils(byte_array_mfb_env::sequence_full_speed_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH))

    function new (string name = "req");
        super.new(name);
    endfunction

    /////////
    // CREATE intel_mac_seg::Sequence_item
    virtual task create_sequence_item();
        int unsigned index = 0;
        gen.randomize();

        gen.SRC_RDY = 0;
        gen.SOF     = '0;
        gen.EOF     = '0;
        for (int unsigned it = 0; it < REGIONS; it++) begin
            int unsigned index = 0;
            while (index < REGION_SIZE) begin
                if (state_packet == state_packet_space_new) begin
                    state_packet = state_packet_space;
                    space_size   = 0;
                end


                if (state_packet == state_packet_space) begin
                    if (space_size != 0) begin
                        space_size--;
                    end else begin
                        state_packet = state_packet_none;
                    end
                end

                if (state_packet == state_packet_none) begin
                    try_get();
                end

                if (state_packet == state_packet_new) begin
                    // Check SOF and EOF position if we can insert packet into this region
                    if (gen.SOF[it] == 1 || (gen.EOF[it] == 1'b1 && (REGION_SIZE*BLOCK_SIZE) > (index*BLOCK_SIZE + data.data.size()))) begin
                        break;
                    end

                    gen.SOF[it]     = 1'b1;
                    gen.SOF_POS[it] = index;
                    if (hl_sqr.meta_behav == 1 && META_WIDTH != 0) begin
                        gen.META[it] = meta.data;
                    end 
                    state_packet = state_packet_data;
                end

                if (state_packet == state_packet_data) begin
                    int unsigned loop_end   = BLOCK_SIZE < (data.data.size() - data_index) ? BLOCK_SIZE : (data.data.size() - data_index);
                    gen.SRC_RDY = 1;

                    for (int unsigned jt = index*BLOCK_SIZE; jt < (index*BLOCK_SIZE + loop_end); jt++) begin
                        gen.ITEMS[it][(jt+1)*ITEM_WIDTH-1 -: ITEM_WIDTH] = data.data[data_index];
                        data_index++;
                    end

                    // End of packet
                    if (data.data.size() <= data_index) begin
                        if (hl_sqr.meta_behav == 2 && META_WIDTH != 0) begin
                            gen.META[it] = meta.data;
                        end
                        gen.EOF[it]     = 1'b1;
                        gen.EOF_POS[it] = index*BLOCK_SIZE + loop_end-1;
                        data = null;
                        hl_sqr.m_data.item_done();
                        if (META_WIDTH != 0) begin
                            hl_sqr.m_meta.item_done();
                        end
                        state_packet = state_packet_space_new;
                    end
                end
                index++;
            end
        end
    endtask
endclass

class sequence_stop_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) extends sequence_simple_rx_base #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH);
    `uvm_object_param_utils(byte_array_mfb_env::sequence_stop_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH))

    function new (string name = "req");
        super.new(name);
        hl_transactions_min = 10;
        hl_transactions_max = 1000;
    endfunction

    constraint c_hl_transations_stop {
        hl_transactions dist {[hl_transactions_min:hl_transactions_min + 100] :/ 50, [hl_transactions_max-100:hl_transactions_max] :/ 50, [hl_transactions_min:hl_transactions_max] :/100};
    }

    /////////
    // CREATE intel_mac_seg::Sequence_item
    virtual task create_sequence_item();
        int unsigned index = 0;
        gen.randomize();

        gen.SRC_RDY = 0;
        gen.SOF     = '0;
        gen.EOF     = '0;

        if (hl_transactions != 0) begin
            hl_transactions--;
        end
    endtask
endclass

/////////////////////////////////////////////////////////////////////////
// SEQUENCE LIBRARY RX
class sequence_lib_rx#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) extends uvm_sequence_library#(mfb::sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH));
  `uvm_object_param_utils(byte_array_mfb_env::sequence_lib_rx#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH))
  `uvm_sequence_library_utils(byte_array_mfb_env::sequence_lib_rx#(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH))

  function new(string name = "");
    super.new(name);
    init_sequence_library();
  endfunction

    // subclass can redefine and change run sequences
    // can be useful in specific tests
    virtual function void init_sequence();
        this.add_sequence(byte_array_mfb_env::sequence_simple_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH)::get_type());
        this.add_sequence(byte_array_mfb_env::sequence_full_speed_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH)::get_type());
        this.add_sequence(byte_array_mfb_env::sequence_stop_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH)::get_type());
    endfunction
endclass

