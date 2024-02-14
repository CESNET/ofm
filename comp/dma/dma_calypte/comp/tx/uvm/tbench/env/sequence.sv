//-- sequence.sv: Virtual sequencer 
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Radek Iša <isa@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

class sequence_simple#(ITEM_WIDTH, META_WIDTH) extends uvm_sequence#(uvm_dma_ll_rx::sequence_item#(ITEM_WIDTH, META_WIDTH));
    `uvm_object_param_utils(uvm_dma_ll::sequence_simple#(ITEM_WIDTH, META_WIDTH))
    `uvm_declare_p_sequencer(uvm_dma_ll_rx::sequencer#(ITEM_WIDTH, META_WIDTH))


    function new(string name = "uvm_dma_ll::sequence_simple");
        super.new(name);
    endfunction


    task body();
        //uvm_common::sequence_cfg state;
        uvm_dma_regs::start_channel start;
        uvm_dma_regs::stop_channel  stop;

        start = uvm_dma_regs::start_channel::type_id::create("start", m_sequencer);
        start.m_regmodel = p_sequencer.m_regmodel;
        stop  = uvm_dma_regs::stop_channel ::type_id::create("stop",  m_sequencer);
        stop.m_regmodel = p_sequencer.m_regmodel;

        req = uvm_dma_ll_rx::sequence_item#(ITEM_WIDTH, META_WIDTH)::type_id::create("req", m_sequencer);

        //if(!uvm_config_db#(uvm_common::sequence_cfg)::get(m_sequencer, "", "state", state)) begin
        //    state = null;
        //end


        //forever begin
            start.start(null); 


            //RUN DATA
            for (int unsigned it = 0; it < 5000; it++) begin
                start_item(req);
                assert(req.randomize() with {req.packet.size() inside {[64:2048]};}) else `uvm_fatal(m_sequencer.get_full_name(), "\n\tCannot randomize packet");
                finish_item(req);
            end

            stop.start(null); 
        //end
    endtask

endclass

