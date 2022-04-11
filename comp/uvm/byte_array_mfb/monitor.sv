//-- monitor.sv: Monitor for MFB environment
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

class monitor_byte_array #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) extends byte_array::monitor;
    `uvm_component_param_utils(byte_array_mfb_env::monitor_byte_array #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH))

    // Analysis port
    typedef monitor_byte_array #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) this_type;
    uvm_analysis_imp #(mfb::sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH), this_type) analysis_export;

    reset::sync_terminate reset_sync;
    local byte_array::sequence_item hi_tr;
    local byte unsigned data[$];

    function new (string name, uvm_component parent);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        hi_tr = null;
        reset_sync = new();
    endfunction

    function void process_eof(int unsigned index, int unsigned start_pos, mfb::sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) tr);
        if (hi_tr != null) begin
            for (int unsigned it = start_pos; it <= tr.EOF_POS[index]; it++) begin
                data.push_back(tr.ITEMS[index][(it+1)*ITEM_WIDTH-1 -: ITEM_WIDTH]);
            end
            hi_tr.data = data;
            analysis_port.write(hi_tr);
        end
    endfunction

    function void process_sof(int unsigned index, int unsigned end_pos, mfb::sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) tr);
        hi_tr = byte_array::sequence_item::type_id::create("hi_tr");
        data.delete();
        for (int unsigned it = BLOCK_SIZE*tr.SOF_POS[index]; it <= end_pos; it++) begin
            data.push_back(tr.ITEMS[index][(it+1)*ITEM_WIDTH-1 -: ITEM_WIDTH]);
        end
    endfunction


    virtual function void write(mfb::sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) tr);
        if (reset_sync.has_been_reset()) begin
            data.delete();
            hi_tr = null;
        end

        if (tr.SRC_RDY == 1'b1 && tr.DST_RDY == 1'b1) begin
            for (int unsigned it = 0; it < REGIONS; it++) begin
                // Eop is before next packet start
                if (tr.SOF[it] && tr.EOF[it] && tr.EOF_POS[it] < (BLOCK_SIZE*tr.SOF_POS[it])) begin
                    process_eof(it, 0, tr);
                    process_sof(it, REGION_SIZE*BLOCK_SIZE-1, tr);
                end else begin
                    int unsigned pos_start = tr.SOF[it] ? BLOCK_SIZE*tr.SOF_POS[it] : 0;
                    int unsigned pos_end   = tr.EOF[it] ? tr.EOF_POS[it] : (REGION_SIZE*BLOCK_SIZE-1);

                    if (tr.SOF[it]) begin
                        hi_tr = byte_array::sequence_item::type_id::create("hi_tr");
                        data.delete();
                    end

                    if (hi_tr != null) begin
                        for (int unsigned jt = pos_start; jt <= pos_end; jt++) begin
                            data.push_back(tr.ITEMS[it][(jt+1)*ITEM_WIDTH-1 -: ITEM_WIDTH]);
                        end
                    end

                    if (tr.EOF[it] && hi_tr != null) begin
                        hi_tr.data = data;
                        analysis_port.write(hi_tr);
                    end
                end
            end
        end
    endfunction
endclass

class monitor_logic_vector #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) extends logic_vector::monitor#(META_WIDTH);

    `uvm_component_param_utils(byte_array_mfb_env::monitor_logic_vector #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH))

    typedef monitor_logic_vector #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) this_type;
    // Analysis por
    uvm_analysis_imp #(mfb::sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH), this_type) analysis_export;
    reset::sync_terminate reset_sync;
    int meta_behav;

    local logic_vector::sequence_item#(META_WIDTH) hi_tr;


    function new (string name, uvm_component parent);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        reset_sync = new();
    endfunction

    virtual function void write(mfb::sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) tr);
        if (tr.SRC_RDY && tr.DST_RDY) begin
            for (int i = 0; i<REGIONS; i++) begin
                if (tr.SOF[i] && meta_behav == 1) begin
                    hi_tr = logic_vector::sequence_item#(META_WIDTH)::type_id::create("hi_tr");
                    hi_tr.data = tr.META[i];
                    analysis_port.write(hi_tr);
                end else if (tr.EOF[i] && meta_behav == 2) begin
                    hi_tr = logic_vector::sequence_item#(META_WIDTH)::type_id::create("hi_tr");
                    hi_tr.data = tr.META[i];
                    analysis_port.write(hi_tr);
                end
            end
       end
    endfunction
endclass
