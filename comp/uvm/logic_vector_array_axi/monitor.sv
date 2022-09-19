//-- monitor.sv: Monitor for AXI environment
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

class monitor_logic_vector_array #(DATA_WIDTH, TUSER_WIDTH, ITEM_WIDTH, REGIONS) extends uvm_logic_vector_array::monitor #(ITEM_WIDTH);
    `uvm_component_param_utils(uvm_logic_vector_array_axi::monitor_logic_vector_array #(DATA_WIDTH, TUSER_WIDTH, ITEM_WIDTH, REGIONS))

    // Analysis port
    typedef monitor_logic_vector_array #(DATA_WIDTH, TUSER_WIDTH, ITEM_WIDTH, REGIONS) this_type;
    uvm_analysis_imp #(uvm_axi::sequence_item #(DATA_WIDTH, TUSER_WIDTH, REGIONS), this_type) analysis_export;

    uvm_reset::sync_terminate reset_sync;
    localparam ITEMS = DATA_WIDTH/ITEM_WIDTH;
    local uvm_logic_vector_array::sequence_item #(ITEM_WIDTH) hi_tr;
    local logic [ITEM_WIDTH-1 : 0] data[$];
    logic[REGIONS-1 : 0] last     = '0;
    logic eof                     = '0;
    logic inframe                 = '0;
    logic[3 : 0] eof_pos[REGIONS] = '{default: '0};
    logic[3 : 0] eof_pos_tmp      = '0;
    logic[3 : 0] sof              = '0;
    logic[3 : 0] sof_tmp          = '0;
    logic[2 : 0] sof_pos[REGIONS] = '{default: '0};
    logic[2 : 0] sof_pos_tmp      = '0;

    function new (string name, uvm_component parent);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        hi_tr      = null;
        reset_sync = new();
    endfunction

    function int unsigned sof_pos_count (logic sof, logic[1 : 0] pos);
        int unsigned ret = 0;
        if (sof == 1'b1) begin
            if (TUSER_WIDTH == 161) begin 
                case (pos)
                    2'b00 : ret = 0;
                    2'b01 : ret = (ITEMS/REGIONS);
                    2'b10 : ret = 2*(ITEMS/REGIONS);
                    2'b11 : ret = 3*(ITEMS/REGIONS);
                endcase
            end else begin
                if (pos[1] == 1'b1) begin
                    ret = (ITEMS/REGIONS);
                end else
                    ret = 0;
            end
        end
        return ret;
    endfunction

    function int unsigned eof_pos_count (logic eof, logic[3 : 0] pos);
        int unsigned ret = 0;
        if (eof == 1'b1) begin
            ret = pos % (ITEMS/REGIONS);
        end else
            ret = ((ITEMS/REGIONS)-1);
        return ret;
    endfunction

    function void process_eof(int unsigned index, int unsigned start_pos, uvm_axi::sequence_item #(DATA_WIDTH, TUSER_WIDTH, REGIONS) tr, logic eof, logic[3 : 0] pos);
        if (hi_tr != null) begin
            for (int unsigned it = start_pos; it <= eof_pos_count(eof, pos); it++) begin
                data.push_back(tr.tdata[index][(it+1)*ITEM_WIDTH-1 -: ITEM_WIDTH]);
            end
            hi_tr.data = data;
            analysis_port.write(hi_tr);
        end
    endfunction

    function void process_sof(int unsigned index, int unsigned end_pos, uvm_axi::sequence_item #(DATA_WIDTH, TUSER_WIDTH, REGIONS) tr, logic sof, logic[1 : 0] pos);
        hi_tr = uvm_logic_vector_array::sequence_item #(ITEM_WIDTH)::type_id::create("hi_tr");
        data.delete();
        for (int unsigned it = sof_pos_count(sof, pos); it <= end_pos; it++) begin
            data.push_back(tr.tdata[index][(it+1)*ITEM_WIDTH-1 -: ITEM_WIDTH]);
        end
    endfunction

    virtual function void write(uvm_axi::sequence_item #(DATA_WIDTH, TUSER_WIDTH, REGIONS) tr);
        if (reset_sync.has_been_reset()) begin
            hi_tr = null;
        end
        if (tr.tvalid == 1'b1 && tr.tready == 1'b1) begin
            for (int unsigned it = 0; it < REGIONS; it++) begin
                if (TUSER_WIDTH == 60) begin
                    for (int unsigned jt = 0; jt < ITEMS; jt++) begin
                        if (tr.tkeep[jt])
                            data.push_back(tr.tdata[it][(jt+1)*ITEM_WIDTH-1 -: ITEM_WIDTH]);
                    end
                    if (tr.tlast == 1'b1) begin
                        hi_tr      = uvm_logic_vector_array::sequence_item #(ITEM_WIDTH)::type_id::create("hi_tr");
                        hi_tr.data = data;
                        analysis_port.write(hi_tr);
                        hi_tr = null;
                        data.delete();
                    end
                end else begin
                    if (TUSER_WIDTH == 137) begin
                        sof_tmp     = tr.tuser[it + 20];
                        sof_pos_tmp = tr.tuser[23+(it*2) -: 2];
                        if (sof_tmp == 1'b1) begin
                            case (sof_pos_tmp)
                                2'b00 :
                                begin
                                    sof[0]     = 1'b1;
                                    sof_pos[0] = 0;
                                end
                                2'b10 :
                                begin
                                    sof[1]     = 1'b1;
                                    sof_pos[1] = 0;
                                end
                            endcase
                        end

                        eof         = tr.tuser[it + 26];
                        eof_pos_tmp = tr.tuser[31+(it*4) -: 4];
                    end
                    if (TUSER_WIDTH == 75) begin
                        if (tr.tuser[it + 32] != 0) begin
                            if ((tr.tuser[34] && (inframe && tr.tuser[37 -: 3] < (ITEMS/REGIONS))) && tr.tuser[32]) begin
                                sof[0] = 1'b0;
                                sof[1] = 1'b1;
                            end else
                                sof[it]     = tr.tuser[it + 32];
                        end
                        eof         = tr.tuser[(it*4) + 34];
                        sof_pos[it] = 0;
                        eof_pos_tmp = tr.tuser[(it*4 + 37) -: 3];
                    end
                    if (TUSER_WIDTH == 161) begin
                        sof_tmp     = tr.tuser[it + 64];
                        sof_pos_tmp = tr.tuser[69+(it*2) -: 2];
                        if (sof_tmp == 1'b1) begin
                            case (sof_pos_tmp)
                                2'b00 :
                                begin
                                    sof[0]     = 1'b1;
                                    sof_pos[0] = 0;
                                end
                                2'b01 :
                                begin
                                    sof[1]     = 1'b1;
                                    sof_pos[1] = 0;
                                end
                                2'b10 :
                                begin
                                    sof[2]     = 1'b1;
                                    sof_pos[2] = 0;
                                end
                                2'b11 :
                                begin
                                    sof[3]     = 1'b1;
                                    sof_pos[3] = 0;
                                end
                            endcase
                        end
                        eof         = tr.tuser[it + 76];
                        eof_pos_tmp = int'(tr.tuser[83+(it*4) -: 4]);
                    end

                    if (eof) begin
                        unique case(eof_pos_tmp) inside
                            [0 : (ITEMS/REGIONS)-1]:
                            begin
                                last[0]    = 1'b1;
                                eof_pos[0] = eof_pos_tmp;
                            end
                            [(ITEMS/REGIONS) : 2*(ITEMS/REGIONS)-1]:
                            begin
                                last[1]    = 1'b1;
                                eof_pos[1] = eof_pos_tmp;
                            end
                            [2*(ITEMS/REGIONS) : 3*(ITEMS/REGIONS)-1]:
                            begin
                                last[2]    = 1'b1;
                                eof_pos[2] = eof_pos_tmp;
                            end
                            [3*(ITEMS/REGIONS) : 4*(ITEMS/REGIONS)-1]:
                            begin
                                last[3]    = 1'b1;
                                eof_pos[3] = eof_pos_tmp;
                            end
                        endcase
                    end

                    if (sof[it] && last[it] && eof_pos_count(last[it], eof_pos[it]) < (sof_pos_count(sof[it], sof_pos[it]))) begin
                        process_eof(it, 0, tr, last[it], eof_pos[it]);
                        process_sof(it, ((ITEMS/REGIONS)-1), tr, sof[it], sof_pos[it]);
                    end else begin
                        int unsigned pos_end   = ((ITEMS/REGIONS)-1);
                        int unsigned pos_start = sof_pos_count(sof[it], sof_pos[it]);

                        pos_end = eof_pos_count(last[it], eof_pos[it]);

                        // SOF
                        if (sof[it]) begin
                            sof[it] = 1'b0;
                            inframe = 1'b1;
                            if (hi_tr != null) begin
                                `uvm_error(this.get_full_name(), "\n\tSOF has been set before previous frame haven't correctly ended. EOF haven't been set on end of packet")
                            end
                            hi_tr = uvm_logic_vector_array::sequence_item #(ITEM_WIDTH)::type_id::create("hi_tr");
                            data.delete();
                        end
                        if (hi_tr != null) begin
                            for (int unsigned jt = pos_start; jt <= pos_end; jt++) begin
                                data.push_back(tr.tdata[it][(jt+1)*ITEM_WIDTH-1 -: ITEM_WIDTH]);
                            end
                        end

                        // EOF
                        if (last[it] && hi_tr != null) begin
                            if (hi_tr == null) begin
                                `uvm_error(this.get_full_name(), "\n\tEOF has been set before frame heve been started. SOF havent been set before this EOF")
                            end else begin
                                hi_tr.data = data;
                                analysis_port.write(hi_tr);
                                inframe = 1'b0;
                                hi_tr    = null;
                                last[it] = 1'b0;
                            end
                        end
                    end
                end
            end
        end
    endfunction
endclass

class monitor_logic_vector #(DATA_WIDTH, TUSER_WIDTH, ITEM_WIDTH, REGIONS) extends uvm_logic_vector::monitor#(TUSER_WIDTH);
    `uvm_component_param_utils(uvm_logic_vector_array_axi::monitor_logic_vector #(DATA_WIDTH, TUSER_WIDTH, ITEM_WIDTH, REGIONS))

    typedef monitor_logic_vector #(DATA_WIDTH, TUSER_WIDTH, ITEM_WIDTH, REGIONS) this_type;
    // Analysis port
    uvm_analysis_imp #(uvm_axi::sequence_item #(DATA_WIDTH, TUSER_WIDTH, REGIONS), this_type) analysis_export;

    uvm_reset::sync_terminate reset_sync;
    config_item::meta_type    meta_behav;

    local uvm_logic_vector::sequence_item#(TUSER_WIDTH) hi_tr;

    function new (string name, uvm_component parent);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        reset_sync = new();
    endfunction

    virtual function void write(uvm_axi::sequence_item #(DATA_WIDTH, TUSER_WIDTH, REGIONS) tr);
        if (tr.tvalid == 1'b1 && tr.tready == 1'b1) begin
            if (TUSER_WIDTH == 60) begin
                if (tr.tlast && meta_behav == config_item::META_EOF) begin
                    hi_tr      = uvm_logic_vector::sequence_item#(TUSER_WIDTH)::type_id::create("hi_tr");
                    hi_tr.data = tr.tuser;
                    analysis_port.write(hi_tr);
                end
            end
            if (TUSER_WIDTH == 137) begin
                for (int unsigned it = 0; it < REGIONS; it++) begin
                    if ((tr.tuser[it + 26] == 1'b1) && meta_behav == config_item::META_EOF) begin
                        hi_tr      = uvm_logic_vector::sequence_item#(TUSER_WIDTH)::type_id::create("hi_tr");
                        hi_tr.data = tr.tuser;
                        analysis_port.write(hi_tr);
                    end
                end
            end
       end
    endfunction
endclass
