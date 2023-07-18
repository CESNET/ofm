// model.sv: Model of implementation
// Copyright (C) 2023 CESNET z. s. p. o.
// Author(s): Yaroslav Marushchenko <xmarus09@stud.fit.vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


class model #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH, USE_PIPE) extends uvm_component;
    `uvm_component_param_utils(frame_masker::model #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH, USE_PIPE))

    uvm_tlm_analysis_fifo #(uvm_mfb::sequence_item #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH)) input_data;
    uvm_tlm_analysis_fifo #(uvm_mvb::sequence_item #(MFB_REGIONS, 1))                                                               input_mvb;
    uvm_analysis_port     #(uvm_mfb::sequence_item #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH)) out_data;

    function new(string name = "model", uvm_component parent = null);
        super.new(name, parent);

        input_data = new("input_data", this);
        input_mvb  = new("input_mvb",  this);
        out_data   = new("out_data",   this);

    endfunction

    function logic [MFB_REGIONS-1 : 0] get_mask(uvm_mvb::sequence_item #(MFB_REGIONS, 1) mvb_item);
        logic [MFB_REGIONS-1 : 0] vector;
        for (int i = 0; i < MFB_REGIONS; i++) begin
            vector[i] = mvb_item.data[i][0];
        end
        return vector;

    endfunction

    function int get_highest_mask_index(uvm_mvb::sequence_item #(MFB_REGIONS, 1) mvb_item);
        logic [MFB_REGIONS-1 : 0] mask = get_mask(mvb_item);
        if (|mask === 1) begin
            for (int i = MFB_REGIONS-1; i >= 0; i--) begin
                if (mask[i] === 1) begin
                    return i;
                end
            end
        end
        else begin
            return MFB_REGIONS-1;
        end

    endfunction

    function logic [MFB_REGIONS-1 : 0] get_frames_to_drop(uvm_mvb::sequence_item #(MFB_REGIONS, 1) mvb_item);
        logic [MFB_REGIONS-1 : 0] frames_to_drop = '0;
        if (MFB_REGIONS > 1) begin
            logic [MFB_REGIONS-1 : 0] mask = get_mask(mvb_item);
            for (int i = 0; i <= get_highest_mask_index(mvb_item); i++) begin
                frames_to_drop[i] = ~mask[i];
            end
        end
        return frames_to_drop;

    endfunction

    function logic [MFB_REGIONS-1 : 0] get_frames_to_hide(uvm_mvb::sequence_item #(MFB_REGIONS, 1) mvb_item);
        logic [MFB_REGIONS-1 : 0] frames_to_hide = '0;
        if (MFB_REGIONS > 1) begin
            for (int i = get_highest_mask_index(mvb_item)+1; i < MFB_REGIONS; i++) begin
                frames_to_hide[i] = 1;
            end
        end
        else begin
            frames_to_hide = ~get_mask(mvb_item);
        end
        return frames_to_hide;

    endfunction

    function logic drop_frames(ref uvm_mfb::sequence_item #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH) item, input logic [MFB_REGIONS-1 : 0] frames_to_drop);
        logic prev_mask = 0;
        for (int i = 0; i < MFB_REGIONS; i++) begin
            if (item.sof[i] === 1 && item.eof[i] === 1) begin
                int sof_pos_items = item.sof_pos[i]*MFB_BLOCK_SIZE;
                int eof_pos_items = item.eof_pos[i];
                if (sof_pos_items <= eof_pos_items) begin
                    if (frames_to_drop[i] === 1) begin
                        item.sof[i] = 0;
                        item.eof[i] = 0;
                    end
                end
                else begin
                    if (prev_mask === 1) begin
                        item.eof[i] = 0;
                        prev_mask = 0;
                    end
                    if (frames_to_drop[i] === 1) begin
                        item.sof[i] = 0;
                        prev_mask = 1;
                    end
                end
            end
            else if (item.sof[i] === 1) begin
                if (frames_to_drop[i] === 1) begin
                    item.sof[i] = 0;
                    prev_mask = 1;
                end
            end
            else if (item.eof[i] === 1) begin
                if (prev_mask === 1) begin
                    item.eof[i] = 0;
                    prev_mask = 0;
                end
            end
        end
        return prev_mask;

    endfunction

    function int get_next_eof_index(uvm_mfb::sequence_item #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH) item);
        for (int i = 0; i < MFB_REGIONS; i++) begin
            if (item.sof[i] === 1 && item.eof[i] === 1) begin
                int sof_pos_items = item.sof_pos[i]*MFB_BLOCK_SIZE;
                int eof_pos_items = item.eof_pos[i];
                if (sof_pos_items <= eof_pos_items) begin
                    return -1;
                end
                else begin
                    return i;
                end
            end
            else if (item.sof[i] === 1) begin
                return -1;
            end
            else if (item.eof[i] === 1) begin
                return i;
            end
        end
        return -1;

    endfunction

    function logic drop_single_eof(ref uvm_mfb::sequence_item #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH) item, input logic mask_next_eof);
        int next_eof_index = get_next_eof_index(item);
        if (next_eof_index !== -1 && mask_next_eof === 1) begin
            item.eof[next_eof_index] = 0;
            return 0;
        end
        else begin
            return mask_next_eof;
        end

    endfunction

    function hide_frames(ref uvm_mfb::sequence_item #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH) item, input uvm_mvb::sequence_item #(MFB_REGIONS, 1) mvb_item);
        logic [MFB_REGIONS-1 : 0] frames_to_hide = get_frames_to_hide(mvb_item);
        drop_frames(item, frames_to_hide);

    endfunction

    function logic is_done(uvm_mfb::sequence_item #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH) item, uvm_mvb::sequence_item #(MFB_REGIONS, 1) mvb_item);
        return !(|(get_frames_to_hide(mvb_item) & item.sof));

    endfunction

    task run_phase(uvm_phase phase);

        uvm_mfb::sequence_item #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH) tr_input_data;
        uvm_mvb::sequence_item #(MFB_REGIONS, 1)                                                               tr_input_mvb;
        uvm_mfb::sequence_item #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH) tr_output_data;

        localparam INPUT_PIPE_CAPACITY = 2*USE_PIPE;

        string msg = "";
        int cycle_number    = 0;
        logic mask_next_eof = 0;
        enum { IDLE, START, PROCESSING } state = IDLE;
        uvm_mfb::sequence_item #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH) data_word;
        struct {
            uvm_mfb::sequence_item #(MFB_REGIONS, MFB_REGION_SIZE, MFB_BLOCK_SIZE, MFB_ITEM_WIDTH, MFB_META_WIDTH) item;
            int push_cycle_number;
        } tr_input_data_pipe_item, tr_input_data_pipe [$];
        
        forever begin
            input_data.get(tr_input_data);
            input_mvb.get(tr_input_mvb);

            cycle_number++;
            if (tr_input_data_pipe.size() <= INPUT_PIPE_CAPACITY && tr_input_data.src_rdy === 1 && tr_input_data.dst_rdy === 1) begin
                tr_input_data_pipe.push_back('{ tr_input_data, cycle_number });
            end

            if (tr_input_mvb.dst_rdy === 1) begin

                if (state === IDLE) begin
                    if (tr_input_data_pipe.size() > 0) begin
                        tr_input_data_pipe_item = tr_input_data_pipe.pop_front();
                        if (cycle_number - tr_input_data_pipe_item.push_cycle_number >= INPUT_PIPE_CAPACITY) begin
                            state = START;
                            // Data word storing
                            $swrite(msg, "%s\nSTART OF OPERATION\n", msg);
                            $cast(data_word, tr_input_data_pipe_item.item.clone());
                            $swrite(msg, "%s\nINPUT DATA:%s\n", msg, data_word.convert2string());
                        end
                        else begin
                            tr_input_data_pipe.push_front(tr_input_data_pipe_item);
                            continue;
                        end
                    end
                    else begin
                        continue;
                    end
                end

                // Next single EOF dropping logic
                if (state === START) begin
                    mask_next_eof = drop_single_eof(data_word, mask_next_eof);
                end
                else if (state === PROCESSING) begin
                    drop_single_eof(data_word, 1);
                end

                // Frames dropping logic
                if (MFB_REGIONS > 1) begin
                    mask_next_eof |= drop_frames(data_word, get_frames_to_drop(tr_input_mvb));
                end
                else begin
                    mask_next_eof = 0;
                end

                // Next state logic
                if (is_done(data_word, tr_input_mvb) === 1) begin
                    $swrite(msg, "%s\nEND OF OPERATION\n", msg);
                    state = IDLE;
                end
                else begin
                    state = PROCESSING;
                end

                // Output masking
                $cast(tr_output_data, data_word.clone());
                hide_frames(tr_output_data, tr_input_mvb);

                // Output info
                $swrite(msg, "%s\nMASK:%b\t%b\t%b\t%b\n\n", msg, get_mask(tr_input_mvb), get_frames_to_drop(tr_input_mvb), get_frames_to_hide(tr_input_mvb), mask_next_eof);
                $swrite(msg, "%s\nOUTPUT DATA:%s\n\n", msg, tr_output_data.convert2string());
                `uvm_info(this.get_full_name(), msg, UVM_HIGH)
                msg = "";

                // Output data
                out_data.write(tr_output_data);
            end
        end

    endtask
endclass
