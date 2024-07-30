// model.sv: Model of implementation
// Copyright (C) 2024 CESNET z. s. p. o.
// Author(s): David Beneš <xbenes52@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause

//In first phase - just one channel
class model #(MVB_ITEM_WIDTH, MFB_ITEM_WIDTH, RX_CHANNELS) extends uvm_component;
    `uvm_component_param_utils(uvm_framepacker::model#(MVB_ITEM_WIDTH, MFB_ITEM_WIDTH, RX_CHANNELS))

    //Model I/O
    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))  data_in;
    uvm_analysis_port #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))      data_out;

    //TODO: Add these signals for a channel recognition
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(MVB_ITEM_WIDTH))        meta_in;
    //Output is in model_item.tag (data_out.tag)

    //Internal signal of FrameShifter component - LAST of SUPERPACKET
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(2)) analysis_export_flow_ctrl[RX_CHANNELS];

    function new(string name = "model", uvm_component parent = null);
        super.new(name, parent);

        //Input
        data_in   = new("data_in",  this);
        data_out  = new("data_out", this);
        meta_in   = new("meta_in", this);

        //Output
        for (int unsigned chan = 0; chan < RX_CHANNELS; chan++) begin
            analysis_export_flow_ctrl[chan] = new($sformatf("analysis_export_flow_ctrl_%d", chan), this);
        end

    endfunction

    function int unsigned used();
        int unsigned ret = 0;
        ret |= (data_in.used() != 0);
        // ret |= (meta_in.used() != 0);
        return ret;
    endfunction

    task run_phase(uvm_phase phase);

        string msg = "";
        string dbg = "";

        uvm_logic_vector::sequence_item #(MVB_ITEM_WIDTH) tr_mvb_in;

        uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH) tr_mfb_in;
        uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH) tr_mfb_out;
        uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH) tr_mfb_tmp;

        // EOF of SUPERPACKET
        uvm_logic_vector::sequence_item #(2) tr_last;

        // FIFO to store SUPERPACKET
        logic [MFB_ITEM_WIDTH-1 : 0] sp_fifo[RX_CHANNELS][$];

        // SUPERPACKET counter
        int unsigned sp_num_cnt = 0;

        //Channel
        logic[$clog2(RX_CHANNELS)-1 : 0] channel;

        forever begin
            // Get input packet
            $swrite(msg, "\nWaiting for data ...");
            `uvm_info(this.get_full_name(), msg, UVM_MEDIUM);

            data_in.get(tr_mfb_in);

            $swrite(msg, "\nWaiting for Channel ...");
            `uvm_info(this.get_full_name(), msg, UVM_MEDIUM);
            // ... and its channel
            meta_in.get(tr_mvb_in);
            channel = tr_mvb_in.data[$clog2(RX_CHANNELS):1];

            $swrite(msg, "\nCHANNEL %0d\nMY_MODEL_IN:   %0s\n", channel, tr_mfb_in.convert2string());
            `uvm_info(this.get_full_name(), msg, UVM_MEDIUM);

            analysis_export_flow_ctrl[channel].get(tr_last);

            tr_mfb_out = uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)::type_id::create("tr_mfb_out");
            tr_mfb_out.tag  = $sformatf("CHANNEL %0d", channel);
            tr_mfb_tmp = uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)::type_id::create("tr_mfb_tmp");

            //Number of bytes in packet with block ceiling
            //TODO: Make it generic
            tr_mfb_tmp.data = new[$ceil(((real'(tr_mfb_in.data.size()))/real'(8)))*8];
            for (int unsigned i = 0; i < tr_mfb_in.data.size(); i++)begin
                tr_mfb_tmp.data[i] = tr_mfb_in.data[i];
            end

            $swrite(msg, "\nCHANNEL     %0d\nEOF:        %0d\nLAST:       %0d\nMODEL_IN:   %0s\n", channel, tr_last.data[0], tr_last.data[1], tr_mfb_tmp.convert2string());
            `uvm_info(this.get_full_name(), msg, UVM_MEDIUM);


            //SUPERPACKET assemble
            for (int unsigned i = 0; i < tr_mfb_tmp.data.size(); i++) begin
                sp_fifo[int'(channel)].push_back(tr_mfb_tmp.data[i]);
            end

            // // DEBUG
            // debug_fifo_state.item.data = sp_fifo[int'(channel)];
            // $write(dbg, "FIFO_STATE \n %0s \n", debug_fifo_state.convert2string());
            // `uvm_info(this.get_full_name(), dbg, UVM_MEDIUM);

            if (tr_last.data[1] == 1) begin
                sp_num_cnt++;
                tr_mfb_out.data = sp_fifo[int'(channel)];

                //DEBUG
                $swrite(msg, {"\n**************************************************************************",
                              "\nTIME:               %0t ps",
                              "\nCHANNEL             %0d",
                              "\nSUPERPACKET_NO:     %0d",
                              "\nSUPERPACKET_SIZE:   %0d bytes",
                              "\n**************************************************************************\n"}
                              , $time, channel, sp_num_cnt, sp_fifo[int'(channel)].size());
                //`uvm_info(this.get_full_name(), msg, UVM_MEDIUM);

                sp_fifo[int'(channel)].delete();
                data_out.write(tr_mfb_out);
            end
        end
    endtask
endclass
