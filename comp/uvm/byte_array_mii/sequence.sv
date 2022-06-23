/*
 * file       : sequence.sv
 * Copyright (C) 2022 CESNET z. s. p. o.
 * description: UVM Byte array - MII Simple sequence
 * date       : 2022
 * author     : Oliver Gurka <xgurka00@stud.fit.vutbr.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/

class sequence_simple #(CHANNELS, CHANNEL_WIDTH) extends uvm_sequence #(uvm_mii::sequence_item #(CHANNELS, CHANNEL_WIDTH));
    `uvm_object_param_utils(uvm_byte_array_mii::sequence_simple #(CHANNELS, CHANNEL_WIDTH))
    `uvm_declare_p_sequencer(uvm_mii::sequencer #(CHANNELS, CHANNEL_WIDTH))

    // -----------------------
    // Parameters.
    // -----------------------
    localparam CHANNEL_BYTES = CHANNEL_WIDTH >> 3;

    // High level transaction
    uvm_byte_array::sequence_item frame;
    // High level sequencer
    uvm_byte_array_mii::sequencer hi_sqr;

    // Wrapper
    uvm_byte_array_mii::wrapper wrapper;
    // Random IPC generator and appender
    uvm_byte_array_mii::ipg_gen ipg_gen;
    // Channel alligner
    uvm_byte_array_mii::channel_align #(CHANNEL_WIDTH) channel_align;
    // Data buffer
    uvm_byte_array_mii::data_buffer #(CHANNELS, CHANNEL_WIDTH) data_buffer;

    // RANDOMIZATION
    rand int unsigned hl_transactions;
    int unsigned hl_transactions_min = 10;
    int unsigned hl_transactions_max = 200;

    constraint c_hl_transactions{
        hl_transactions inside {[hl_transactions_min : hl_transactions_max]};
    };

    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new(name);
        
        WHOLE_BYTES : assert((CHANNEL_WIDTH & 7) == 0);
        wrapper = new("simple_sequence.wrapper");
        ipg_gen = new("simple_sequence.ipg_gen", 1024, 4096);
        channel_align = new("simple_sequence.channel_align");
        data_buffer = new("simple_sequence.data_buffer");
    endfunction: new

    task try_get();
        if (frame == null && hl_transactions != 0) begin
            hi_sqr.byte_array_sequencer.try_next_item(frame);
            if (frame != null) begin
                hl_transactions--;
            end
        end
    endtask 

    // Generates transactions
    task body;

        if(!uvm_config_db #(uvm_byte_array_mii::sequencer)::get(p_sequencer, "", "hi_sqr", hi_sqr)) begin
            `uvm_fatal(get_type_name(), "Unable to get configuration object")
        end
        
        `uvm_info(get_full_name(), "sequence_simple is running", UVM_LOW)
        
        send_init();
        while (hl_transactions > 0 || frame != null) begin
            try_get();
            if (frame != null) begin
                byte unsigned data[$] = {frame.data};
                logic control[$];

                // Wraps data and generates control
                this.wrapper.wrap_data(data, control);
                // Generates IPC and appends it to end of transaction
                this.ipg_gen.generate_ipg(data, control);
                // Aligns next start of frame to first byte of next channel
                this.channel_align.align(data, control);
                // Adds data to buffer
                this.data_buffer.add(data, control);

                while (this.data_buffer.get(data, control)) begin
                    req = uvm_mii::sequence_item #(CHANNELS, CHANNEL_WIDTH)::type_id::create("req");
                    start_item(req);
                    for (int i = 0; i < CHANNELS; i++) begin
                        req.data[i] = {>>1{ { <<8{ data[i * CHANNEL_BYTES : (i + 1) * CHANNEL_BYTES - 1] } } }};
                        req.control[i] = { <<1{ control[i * CHANNEL_BYTES : (i + 1) * CHANNEL_BYTES - 1] } };
                    end
                    finish_item(req);
                    data.delete();
                    control.delete();
                end
                frame = null;
                hi_sqr.byte_array_sequencer.item_done();
            end
        end

        if (!this.data_buffer.is_empty()) begin
            byte unsigned data[$];
            logic control[$];

            this.data_buffer.flush(data, control);
            req = uvm_mii::sequence_item #(CHANNELS, CHANNEL_WIDTH)::type_id::create("req");
            start_item(req);
            for (int i = 0; i < CHANNELS; i++) begin
                req.data[i] = {>>1{ { <<8{ data[i * CHANNEL_BYTES : (i + 1) * CHANNEL_BYTES - 1] } } }};
                req.control[i] = { <<1{ control[i * CHANNEL_BYTES : (i + 1) * CHANNEL_BYTES - 1] } };
            end
            finish_item(req);
        end
    endtask

    task send_init();
        byte unsigned data[$];
        logic control[$];

        this.ipg_gen.generate_ipg(data, control);
        // Aligns next start of frame to first byte of next channel
        this.channel_align.align(data, control);
        // Adds data to buffer
        this.data_buffer.add(data, control);

        while (this.data_buffer.get(data, control)) begin
            req = uvm_mii::sequence_item #(CHANNELS, CHANNEL_WIDTH)::type_id::create("req");
            start_item(req);
            for (int i = 0; i < CHANNELS; i++) begin
                req.data[i] = {>>1{ { <<8{ data[i * CHANNEL_BYTES : (i + 1) * CHANNEL_BYTES - 1] } } }};
                req.control[i] = { <<1{ control[i * CHANNEL_BYTES : (i + 1) * CHANNEL_BYTES - 1] } };
            end
            finish_item(req);
            data.delete();
            control.delete();
        end
    endtask
endclass
