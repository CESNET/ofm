//-- monitor.sv: Monitor for MFB environment
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

class monitor_logic_vector_array #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) extends uvm_logic_vector_array::monitor #(ITEM_WIDTH);
    `uvm_component_param_utils(uvm_logic_vector_array_mfb::monitor_logic_vector_array #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH))

    // Analysis port
    typedef monitor_logic_vector_array #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) this_type;
    uvm_analysis_imp #(uvm_mfb::sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH), this_type) analysis_export;

    uvm_reset::sync_terminate reset_sync;
    localparam SOF_POS_WIDTH = $clog2(REGION_SIZE);
    local uvm_logic_vector_array::sequence_item #(ITEM_WIDTH) hi_tr;
    local logic [ITEM_WIDTH-1 : 0] data[$];
    int data_index = 0;

    function new (string name, uvm_component parent);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        hi_tr = null;
        reset_sync = new();
    endfunction

    function void process_eof(int unsigned index, int unsigned start_pos, uvm_mfb::sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) tr);
        if (hi_tr != null) begin
            for (int unsigned it = start_pos; it <= tr.eof_pos[index]; it++) begin
                data.push_back(tr.data[index][(it+1)*ITEM_WIDTH-1 -: ITEM_WIDTH]);
            end
            hi_tr.data = data;
            analysis_port.write(hi_tr);
        end
    endfunction

    function void process_sof(int unsigned index, int unsigned end_pos, uvm_mfb::sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) tr);
        int unsigned sof_pos = (SOF_POS_WIDTH != 0 ? BLOCK_SIZE*tr.sof_pos[index] : 0);
        hi_tr = uvm_logic_vector_array::sequence_item #(ITEM_WIDTH)::type_id::create("hi_tr");
        data.delete();
        for (int unsigned it = sof_pos; it <= end_pos; it++) begin
            data.push_back(tr.data[index][(it+1)*ITEM_WIDTH-1 -: ITEM_WIDTH]);
        end
    endfunction


    virtual function void write(uvm_mfb::sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) tr);
        if (reset_sync.has_been_reset()) begin
            hi_tr = null;
        end
        if (tr.src_rdy == 1'b1 && tr.dst_rdy == 1'b1) begin
            for (int unsigned it = 0; it < REGIONS; it++) begin
                //$write("MFB MON FIFO %h\n", tr.data[it]);
                int unsigned sof_pos = SOF_POS_WIDTH != 0 ? BLOCK_SIZE*tr.sof_pos[it] : 0;
                // Eop is before next packet start
                if (tr.sof[it] && tr.eof[it] && tr.eof_pos[it] < sof_pos) begin
                    process_eof(it, 0, tr);
                    process_sof(it, REGION_SIZE*BLOCK_SIZE-1, tr);
                end else begin
                    int unsigned pos_start = tr.sof[it] ? sof_pos : 0;
                    int unsigned pos_end   = tr.eof[it] ? tr.eof_pos[it] : (REGION_SIZE*BLOCK_SIZE-1);

                    if (tr.sof[it]) begin
                        if (hi_tr != null) begin
                            `uvm_error(this.get_full_name(), "\n\tSOF has been set before previous frame haven't correctly ended. EOF haven't been set on end of packet")
                        end
                        hi_tr = uvm_logic_vector_array::sequence_item #(ITEM_WIDTH)::type_id::create("hi_tr");
                        data.delete();
                    end

                    if (hi_tr != null) begin
                        for (int unsigned jt = pos_start; jt <= pos_end; jt++) begin
                            data.push_back(tr.data[it][(jt+1)*ITEM_WIDTH-1 -: ITEM_WIDTH]);
                            data_index++;
                        end
                    end

                    if (tr.eof[it] && hi_tr != null) begin
                        if (hi_tr == null) begin
                            `uvm_error(this.get_full_name(), "\n\tEOF has been set before frame heve been started. SOF havent been set before this EOF")
                        end else begin
                            hi_tr.data = data;
                            analysis_port.write(hi_tr);
                            hi_tr = null;
                        end
                    end
                end
            end
        end
    endfunction
endclass

class monitor_logic_vector #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) extends uvm_logic_vector::monitor#(META_WIDTH);
    `uvm_component_param_utils(uvm_logic_vector_array_mfb::monitor_logic_vector #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH))

    //localparam ITEM_WIDTH = 32;

    typedef monitor_logic_vector #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) this_type;
    // Analysis por
    uvm_analysis_imp #(uvm_mfb::sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH), this_type) analysis_export;
    uvm_reset::sync_terminate reset_sync;
    config_item::meta_type meta_behav;

    local uvm_logic_vector::sequence_item#(META_WIDTH) hi_tr;

    function new (string name, uvm_component parent);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        reset_sync = new();
    endfunction

    virtual function void write(uvm_mfb::sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) tr);
        if (tr.src_rdy && tr.dst_rdy) begin
            for (int i = 0; i<REGIONS; i++) begin
                if (tr.sof[i] && meta_behav == config_item::META_SOF) begin
                    hi_tr = uvm_logic_vector::sequence_item#(META_WIDTH)::type_id::create("hi_tr");
                    hi_tr.data = tr.meta[i];
                    analysis_port.write(hi_tr);
                end else if (tr.eof[i] && meta_behav == config_item::META_EOF) begin
                    hi_tr = uvm_logic_vector::sequence_item#(META_WIDTH)::type_id::create("hi_tr");
                    hi_tr.data = tr.meta[i];
                    analysis_port.write(hi_tr);
                end
            end
       end
    endfunction
endclass
