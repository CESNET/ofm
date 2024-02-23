//-- sequence.sv: Virtual sequencer 
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Radek Iša <isa@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

class sequence_simple extends uvm_sequence#(uvm_dma_ll_rx::sequence_item);
    `uvm_object_param_utils(uvm_dma_ll::sequence_simple)
    `uvm_declare_p_sequencer(uvm_dma_ll_rx::sequencer)

    int unsigned packet_size_min = 64;
    int unsigned packet_size_max = 2048; 


    function new(string name = "uvm_dma_ll::sequence_simple");
        super.new(name);
    endfunction


    task body();
        uvm_common::sequence_cfg state;

        uvm_dma_regs::start_channel start;
        uvm_dma_regs::stop_channel  stop;

        start = uvm_dma_regs::start_channel::type_id::create("start", m_sequencer);
        start.m_regmodel = p_sequencer.m_regmodel;
        stop  = uvm_dma_regs::stop_channel ::type_id::create("stop",  m_sequencer);
        stop.m_regmodel = p_sequencer.m_regmodel;

        req = uvm_dma_ll_rx::sequence_item::type_id::create("req", m_sequencer);

        if(!uvm_config_db#(uvm_common::sequence_cfg)::get(m_sequencer, "", "state", state)) begin
            state = null;
        end

        while(state == null || !state.stopped()) begin
            int unsigned wait_fork;
            int unsigned it;
            int unsigned transaction_count;
            int unsigned stop_time;

            std::randomize(transaction_count) with {transaction_count dist {[1:100] :/ 10, [100:1000] :/ 20, [1000:5000] :/ 60, [5000:50000] :/ 10}; };
            std::randomize(stop_time) with {stop_time dist {[1: 10] :/ 10, [10:100] :/ 40, [1000:5000] :/ 5}; };

            //SLEEP TIME
            wait_fork = 1;
            fork
                begin
                    #(stop_time*100ns);
                    wait_fork = 0;
                end
                begin
                    if ($urandom_range(10) == 0) begin
                        int unsigned packets_max = $urandom_range(5000, 100);
                        int unsigned packets     = 0;

                        while(wait_fork == 1 && packets < packets_max) begin
                            start_item(req);
                            assert(req.randomize() with {req.packet.size() inside {[packet_size_min:packet_size_max-1]};}) else `uvm_fatal(m_sequencer.get_full_name(), "\n\tCannot randomize packet");
                            finish_item(req);
                        end
                    end
                end
            join

            start.start(null);

            //RUN DATA
            it = 0;
            while(it < transaction_count && (state == null || state.next())) begin
                start_item(req);
                assert(req.randomize() with {req.packet.size() inside {[packet_size_min:packet_size_max-1]};}) else `uvm_fatal(m_sequencer.get_full_name(), "\n\tCannot randomize packet");
                finish_item(req);

                it++;
            end

            stop.start(null);
        end
    endtask

endclass

