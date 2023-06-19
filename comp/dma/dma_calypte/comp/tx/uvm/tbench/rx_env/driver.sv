//-- driver.sv
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause


class driver#(CHANNELS, PKT_SIZE_MAX, ITEM_WIDTH, DATA_ADDR_W, DEVICE) extends uvm_component;
    `uvm_component_param_utils(uvm_dma_ll_rx::driver#(CHANNELS, PKT_SIZE_MAX, ITEM_WIDTH, DATA_ADDR_W, DEVICE))

    uvm_seq_item_pull_port #(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH), uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)) seq_item_port_logic_vector_array;

    mailbox#(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH))                      logic_vector_array_export;
    mailbox#(uvm_logic_vector::sequence_item#(17))                                    sdp_export;
    mailbox#(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)) logic_vector_export;

    local uvm_dma_regs::regmodel#(CHANNELS) m_regmodel;
    uvm_dma_ll_info::watchdog #(CHANNELS)   m_watch_dog;

    uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)                      logic_vector_array_req;
    uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)                      logic_vector_array_new;
    uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH) logic_vector_new;
    uvm_logic_vector::sequence_item#(17)                                    sdp_tr;

    logic [4-1 : 0]              my_last_lbe = '0;
    logic                        dma_done    = 1'b1;
    int unsigned                 dma_cnt     = 0;
    string                       debug_msg_c;
    logic [$clog2(CHANNELS)-1:0] channel;
    logic [DATA_ADDR_W-1 : 0]    frame_pointer;
    logic [DATA_ADDR_W-1 : 0]    dma_len_c = 0;
    int unsigned min_index = 1;
    int unsigned max_index;
    int unsigned index_q[$];

    // ------------------------------------------------------------------------
    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);

        seq_item_port_logic_vector_array = new("seq_item_port_logic_vector_array", this);

        logic_vector_array_export      = new(10);
        logic_vector_export            = new(10);
        sdp_export                     = new(10);
    endfunction

    function void regmodel_set(uvm_dma_regs::regmodel#(CHANNELS) m_regmodel);
        this.m_regmodel = m_regmodel;
    endfunction

    typedef struct{
        uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)                      data;
        uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH) meta;
        uvm_logic_vector::sequence_item#(17)                                    sdp;
        int unsigned index = 0;
    } pcie_info;

    typedef struct{
        logic [DATA_ADDR_W-2-1 : 0] hdr_addr  = '0;
        logic [DATA_ADDR_W-2-1 : 0] data_addr = '0;
    } address_info;
    local address_info addr;

    typedef struct{
        logic [4-1 : 0] fbe;
        logic [4-1 : 0] lbe;
    } be_info;

    function be_info count_be(logic [$clog2(CHANNELS)-1:0] channel, logic [11-1 : 0] pcie_len, logic last = 1'b0);
        logic [4-1 : 0] fbe;
        logic [4-1 : 0] lbe;
        logic [4-1 : 0] one_dw_fbe_array[13]   = {4'b1001, 4'b1101, 4'b1011, 4'b1111, 4'b0101, 4'b0111, 4'b0011, 4'b0110, 4'b1100, 4'b0001, 4'b0010, 4'b0100, 4'b1000};
        logic [4-1 : 0] n_dw_fbe_array[15]    = {4'b0001, 4'b1001, 4'b0101, 4'b1101, 4'b0011, 4'b1011, 4'b0111, 4'b1111, 4'b0010, 4'b1010, 4'b0110, 4'b1110, 4'b0100, 4'b1100, 4'b1000};
        logic [4-1 : 0] fbe_array[$];
        logic [4-1 : 0] tmp_fbe;
        logic [4-1 : 0] valid_fbe   = '0;
        int unsigned last_one_index = 0;
        int unsigned fbe_index      = 0;
        int unsigned fifo_size      = 0;
        be_info      pkt_be;

        if (last == 0) begin
            if (dma_done && dma_cnt == 0) begin

                $swrite(debug_msg_c, "%sLAST\n", debug_msg_c);
                $swrite(debug_msg_c, "%s==========================================================\n", debug_msg_c);
                `uvm_info(this.get_full_name(),              debug_msg_c, UVM_DEBUG)

                debug_msg_c = "";

                $swrite(debug_msg_c, "%s==========================================================\n", debug_msg_c);
                $swrite(debug_msg_c, "%sCHANNEL: %d\n", debug_msg_c, channel);

                if (pcie_len > 1) begin
                                                    // 4'bxxx1, 4'bxxx1, 4'bxx10, 4'bxx10, 4'bx100, 4'bx100, 4'b1000
                    std::randomize(fbe) with {fbe inside {4'b0001, 4'b0011, 4'b0111, 4'b1111}; };
                                                    // 4'b0001, 4'b001x, 4'b001x, 4'b01xx, 4'b01xx, 4'b1xxx, 4'b1xxx
                    std::randomize(lbe) with {lbe inside {4'b1000, 4'b1100, 4'b1010, 4'b1110, 4'b1001, 4'b1101, 4'b1011, 4'b1111, 4'b0100, 4'b0110, 4'b0101, 4'b0111, 4'b0010, 4'b0011, 4'b0001}; };
                end else begin
                    std::randomize(fbe) with {fbe inside {4'b1111, 4'b0111, 4'b0011, 4'b0001}; };
                    lbe = '0;
                end
            end else begin
                tmp_fbe = '0;
                for (int unsigned it = 0; it < 4; it++) begin
                    if (my_last_lbe[it] == 1'b1) begin
                        last_one_index = it;
                        tmp_fbe[it] = 1'b1;
                    end
                end
                if (last_one_index > 3-1) begin
                    if (pcie_len > 1) begin
                                                        // 4'bxxx1, 4'bxxx1, 4'bxx10, 4'bxx10, 4'bx100, 4'bx100, 4'b1000
                        std::randomize(fbe) with {fbe inside {4'b0001, 4'b0011, 4'b0111, 4'b1111}; };
                                                        // 4'b0001, 4'b001x, 4'b001x, 4'b01xx, 4'b01xx, 4'b1xxx, 4'b1xxx
                        std::randomize(lbe) with {lbe inside {4'b1000, 4'b1100, 4'b1010, 4'b1110, 4'b1001, 4'b1101, 4'b1011, 4'b1111, 4'b0100, 4'b0110, 4'b0101, 4'b0111, 4'b0010, 4'b0011, 4'b0001}; };
                    end else begin
                        std::randomize(fbe) with {fbe inside {4'b1001, 4'b1101, 4'b1011, 4'b1111, 4'b0101, 4'b0111, 4'b0011, 4'b0001}; };
                        lbe = '0;
                    end
                end else begin
                    tmp_fbe[last_one_index+1] = 1'b1;
                    if (pcie_len > 1) begin
                                                        // 4'b0001, 4'b001x, 4'b001x, 4'b01xx, 4'b01xx, 4'b1xxx, 4'b1xxx
                        std::randomize(lbe) with {lbe inside {4'b1000, 4'b1100, 4'b1010, 4'b1110, 4'b1001, 4'b1101, 4'b1011, 4'b1111, 4'b0100, 4'b0110, 4'b0101, 4'b0111, 4'b0010, 4'b0011, 4'b0001}; };

                        for (int unsigned it = 0; it < 15; it++) begin
                            if (n_dw_fbe_array[it][last_one_index+1] == 1'b1) begin
                                for (int unsigned jt = 0; jt < last_one_index+1; jt++) begin
                                    valid_fbe[jt] = 1'b0;
                                    if (n_dw_fbe_array[it][jt] == 1'b1) begin
                                        valid_fbe[jt] = 1'b1;
                                    end
                                end
                                if (|valid_fbe == 1'b0) begin
                                    fbe_array.push_back(n_dw_fbe_array[it]);
                                end
                                valid_fbe = '0;
                            end
                        end
                    end else begin
                        lbe = '0;
                        for (int unsigned it = 0; it < 13; it++) begin
                            if (one_dw_fbe_array[it][last_one_index+1] == 1'b1) begin 
                                for (int unsigned jt = 0; jt < last_one_index+1; jt++) begin
                                    valid_fbe[jt] = 1'b0;
                                    if (|one_dw_fbe_array[it][jt] == 1'b1) begin
                                        valid_fbe[jt] = 1'b1;
                                    end
                                end
                                if (|valid_fbe == 1'b0) begin
                                    fbe_array.push_back(one_dw_fbe_array[it]);
                                end
                                valid_fbe = '0;
                            end
                        end
                    end
                    fifo_size = fbe_array.size();
                    std::randomize(fbe_index) with {fbe_index inside {[0 : fifo_size-1]}; };
                    fbe = fbe_array[fbe_index];
                    fbe_array.delete();
                end
            end

            $swrite(debug_msg_c, "%sFBE:      %b\n", debug_msg_c, fbe);
            $swrite(debug_msg_c, "%sLBE:      %b\n", debug_msg_c, lbe);
            $swrite(debug_msg_c, "%sPCIE LEN: %d\n", debug_msg_c, pcie_len);
            pkt_be.lbe = lbe;
            pkt_be.fbe = fbe;
            if (pcie_len > 1) begin
                my_last_lbe = lbe;
            end else begin
                my_last_lbe = fbe;
            end
        end else begin
            pkt_be.lbe = '1;
            pkt_be.fbe = '1;
        end

        return pkt_be;
    endfunction

    task check_status();
        forever begin
            if (m_watch_dog.channel_status[channel] == 1'b0) begin
                frame_pointer  = 0;
                dma_len_c      = 0;
                addr.data_addr = '0;
                addr.hdr_addr  = '0;
                dma_cnt        = 0;
            end
            #(4ns);
        end
    endtask

    // ------------------------------------------------------------------------
    // Starts driving signals to interface
    task run_phase(uvm_phase phase);
        localparam PCIE_HDR_SIZE = 128;
        localparam DMA_HDR_SIZE  = 64;

        int unsigned pkt_cnt;
        logic [24-1:0]               meta;
        logic [DMA_HDR_SIZE-1:0]     dma_hdr;
        logic [PCIE_HDR_SIZE-1:0]    pcie_hdr;
        logic [11-1 : 0]             pcie_len;
        // BE logic
        logic [4-1:0]                fbe;
        logic [2-1:0]                dfbe;
        logic [4-1:0]                lbe;
        logic [2-1:0]                dlbe;
        logic                        last            = 1'b0;
        // Transaction construction logic
        int                          final_size_be   = 0;
        // DEBUG
        string                       debug_msg;
        be_info                      pkt_be;

        int                          dma_len;
        int unsigned                 pcie_cnt;
        int unsigned                 data_index;
        uvm_logic_vector_array::sequence_item#(ITEM_WIDTH) data;
        // Preparation for out of order generation
        pcie_info                    pcie_tr_fifo[$];
        pcie_info                    pcie_tr;
        logic[16-1 : 0]              prev_sdp = '0;

        fork
            check_status();
        join_none

        forever begin

            // Get new sequence item to drive to interface
            seq_item_port_logic_vector_array.get_next_item(logic_vector_array_req);

            logic_vector_new            = uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)::type_id::create("logic_vector_new");
            logic_vector_array_new      = uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)::type_id::create("logic_vector_array_new");

            logic_vector_new.data = '0;
            pcie_hdr              = '0;

            void'(std::randomize(meta));

            debug_msg = "\n";

            dma_len = logic_vector_array_req.size();
            $swrite(debug_msg, "%s===============================================\n", debug_msg);
            $swrite(debug_msg, "%sCHANNEL %d\n",                                      debug_msg, channel);
            $swrite(debug_msg, "%sDMA LEN %d\n",                                      debug_msg, dma_len);

            // DATA logic
            // ====================================================================
            pcie_cnt = 0;

            final_size_be = 0;
            frame_pointer = dma_len_c;
            last = 1'b0;
            pcie_tr.index = 0;
            prev_sdp = 0;

            while (dma_len) begin
                data_index = 0;

                pcie_len = $urandom_range(256, 1);

                if (signed'(dma_len - pcie_len) <= 0) begin
                    pcie_len = dma_len;
                end

                $swrite(debug_msg, "%spcie len %d\n", debug_msg, pcie_len);

                pkt_be = count_be(channel, pcie_len, last);
                dma_done = 1'b0;

                fbe = pkt_be.fbe;
                lbe = pkt_be.lbe;

                if (pcie_len > 1) begin
                    dfbe = sv_dma_bus_pack::encode_fbe(fbe);
                    dlbe = sv_dma_bus_pack::encode_lbe(lbe);
                end else begin
                    dfbe = sv_dma_bus_pack::encode_fbe(fbe, 1'b1);
                    dlbe = '0;
                end

                $swrite(debug_msg, "%sfbe           %b\n", debug_msg, fbe);
                $swrite(debug_msg, "%sdfbe          %d\n", debug_msg, dfbe);
                $swrite(debug_msg, "%slbe           %b\n", debug_msg, lbe);
                $swrite(debug_msg, "%sdlbe          %d\n", debug_msg, dlbe);
                $swrite(debug_msg, "%sDATA ADDR     0x%h(%d)\n", debug_msg, addr.data_addr, addr.data_addr);
                $swrite(debug_msg, "%sFRAME POINTER 0x%h(%d)\n", debug_msg, frame_pointer, frame_pointer);

                dma_len -= pcie_len;
                pcie_tr.data      = uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)::type_id::create("pcie_tr.data");
                pcie_tr.meta      = uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)::type_id::create("pcie_tr.meta");
                pcie_tr.sdp       = uvm_logic_vector::sequence_item# (17)::type_id::create("pcie_tr.sdp");
                pcie_tr.meta.data = '0;

                if (DEVICE == "ULTRASCALE") begin
                    // In case of Xilinx
                    pcie_hdr[DATA_ADDR_W-1 : 2] = addr.data_addr;
                    // Channel num
                    pcie_hdr[(DATA_ADDR_W+$clog2(CHANNELS))-1 : DATA_ADDR_W] = channel;
                    // pcie length in DWORDS
                    pcie_hdr[74 : 64]   = pcie_len; 
                    // REQ TYPE
                    pcie_hdr[78 : 75]   = 4'b0001;
                    // REQ ID
                    pcie_hdr[95 : 80]   = '0;
                    // TAG
                    pcie_hdr[103 : 96]  = '0;
                    // Target Function
                    pcie_hdr[111 : 104] = '0;
                    // BAR ID
                    pcie_hdr[114 : 112] = 3'b010;
                    // BAR Aperure
                    pcie_hdr[120 : 115] = 6'd26;
                    // TC
                    pcie_hdr[123 : 121] = '0;
                    // ATTR
                    pcie_hdr[126 : 124] = '0;
                    // IS DMA HDR
                    pcie_hdr[(DATA_ADDR_W+$clog2(CHANNELS))] = 1'b0;
                    // BAR
                    pcie_tr.meta.data[162 : 160] = 3'b010;
                    // FBE
                    pcie_tr.meta.data[166 : 163] = fbe;
                    // LBE
                    pcie_tr.meta.data[170 : 167] = lbe;
                    // TPH_PRESENT
                    pcie_tr.meta.data[171 : 171] = '0;
                    // TPH TYPE
                    pcie_tr.meta.data[173 : 172] = '0;
                    // TPH_ST_TAG
                    pcie_tr.meta.data[181 : 174] = '0;
                end else begin
                    // In case of Intel
                    pcie_tr.meta.data[127 : 0] = pcie_hdr;
                    // BAR PREFIX
                    logic_vector_new.data[159 : 128] = 6'd26;
                end

                data = uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)::type_id::create("data");
                data.data = new[pcie_len];

                for (int unsigned it = pcie_cnt; it < (pcie_cnt + pcie_len); it++) begin
                    data.data[data_index] = logic_vector_array_req.data[it];
                    data_index++;
                end

                pcie_tr.data.data = {pcie_hdr[31 : 0], pcie_hdr[63 : 32], pcie_hdr[95 : 64], pcie_hdr[127 : 96], data.data};
                pcie_cnt += pcie_len;

                sdp_tr = uvm_logic_vector::sequence_item# (17)::type_id::create("sdp_tr");

                sdp_tr.data[16-1 : 0] = prev_sdp + (pcie_len*4) - dfbe - dlbe;
                sdp_tr.data[16] = 1'b0;
                prev_sdp += (pcie_len*4) - dfbe - dlbe;
                pcie_tr.sdp = sdp_tr;
                pcie_tr.index++;

                pcie_tr_fifo.push_back(pcie_tr);
                if (dma_len < 0) begin
                    `uvm_fatal(this.get_full_name(), "DMA LEN is lower than zero");
                end

                dma_len_c += (pcie_len*4) - dfbe - dlbe;
                final_size_be += (pcie_len*4) - dfbe - dlbe;

                if ((dma_len_c % 4) == 0) begin
                    addr.data_addr += pcie_len;
                end else begin
                    addr.data_addr += pcie_len-1;
                end

            end

            prev_sdp = '0;
            $swrite(debug_msg, "%sSIZE IN BYTES - BE %d\n", debug_msg, final_size_be);

            // Preparation for out of order generation
            pcie_tr_fifo.shuffle();

            for (int unsigned it = 0; it < pcie_tr_fifo.size(); it++) begin
                sdp_tr = uvm_logic_vector::sequence_item# (17)::type_id::create("sdp_tr");

                pcie_tr = pcie_tr_fifo[it];
                $swrite(debug_msg, "%sOUT DATA ADDR     0x%h(%d)\n", debug_msg, pcie_tr.data.data[0][DATA_ADDR_W-1 : 2], pcie_tr.data.data[0][DATA_ADDR_W-1 : 2]);
                $swrite(debug_msg, "%sOUT Transaction ID     %d\n", debug_msg, pcie_tr.index);
                $swrite(debug_msg, "%sOUT DATA               %s\n", debug_msg, pcie_tr.data.convert2string());

                if (pcie_tr.index >= min_index) begin
                    sdp_tr.data[16-1 :0] = pcie_tr.sdp.data[16-1 :0] - prev_sdp;
                    sdp_tr.data[16] = pcie_tr.sdp.data[16];
                    prev_sdp = pcie_tr.sdp.data[16-1 :0];
                    min_index = pcie_tr.index;
                end else begin
                    sdp_tr = pcie_tr.sdp;
                    sdp_tr.data[16-1 :0] = '0;
                end

                logic_vector_array_new = pcie_tr.data;
                logic_vector_new       = pcie_tr.meta;
                logic_vector_array_export.put(logic_vector_array_new);
                sdp_export.put(sdp_tr);
                logic_vector_export.put(logic_vector_new);

            end
            min_index = 1;
            // ====================================================================
            // DMA HDR logic
            logic_vector_new       = uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)::type_id::create("logic_vector_new");
            logic_vector_array_new = uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)::type_id::create("logic_vector_array_new");
            sdp_tr                 = uvm_logic_vector::sequence_item# (17)::type_id::create("sdp_tr");

            logic_vector_new.data = '0;
            fbe                   = '1;
            lbe                   = '1;
            pcie_len              = 2;

            if (DEVICE == "ULTRASCALE") begin
                // In case of Xilinx
                logic_vector_array_new.data = new[((DMA_HDR_SIZE+PCIE_HDR_SIZE)/ITEM_WIDTH)];
                // HDR address
                pcie_hdr[DATA_ADDR_W-1 : 2] = addr.hdr_addr;
                // Channel num
                pcie_hdr[(DATA_ADDR_W+$clog2(CHANNELS))-1 : DATA_ADDR_W] = channel;
                // pcie length in DWORDS
                pcie_hdr[74 : 64]   = pcie_len; 
                // REQ TYPE
                pcie_hdr[78 : 75]   = 4'b0001;
                // REQ ID
                pcie_hdr[95 : 80]   = '0;
                // TAG
                pcie_hdr[103 : 96]  = '0;
                // Target Function
                pcie_hdr[111 : 104] = '0;
                // BAR ID
                pcie_hdr[114 : 112] = 3'b010;
                // BAR Aperure
                pcie_hdr[120 : 115] = 6'd26;
                // TC
                pcie_hdr[123 : 121] = '0;
                // ATTR
                pcie_hdr[126 : 124] = '0;
                // IS DMA HDR
                pcie_hdr[(DATA_ADDR_W+$clog2(CHANNELS))] = 1'b1;
                // BAR
                logic_vector_new.data[162 : 160] = 3'b010;
                // FBE
                logic_vector_new.data[166 : 163] = fbe;
                // LBE
                logic_vector_new.data[170 : 167] = lbe;
                // TPH_PRESENT
                logic_vector_new.data[171 : 171] = '0;
                // TPH TYPE
                logic_vector_new.data[173 : 172] = '0;
                // TPH_ST_TAG
                logic_vector_new.data[181 : 174] = '0;
            end else begin
                // In case of Intel
                logic_vector_array_new.data = new[((DMA_HDR_SIZE)/ITEM_WIDTH)];
                // PCIE HDR
                logic_vector_new.data[127 : 0] = pcie_hdr;
                // BAR PREFIX
                logic_vector_new.data[159 : 128] = 6'd26;
            end

            $swrite(debug_msg, "%sHDR ADDR 0x%h(%d)\n", debug_msg, addr.hdr_addr, addr.hdr_addr);

            // DMA HDR Filling
            dma_hdr[15 : 0]  = (final_size_be);
            dma_hdr[31 : 16] = frame_pointer;
            dma_hdr[39 : 32] = '0;
            dma_hdr[63 : 40] = meta;
            dma_done = 1'b1;
            dma_cnt++;
            last = 1'b1;
            // Increment HDR address
            addr.hdr_addr += pcie_len;

            $swrite(debug_msg, "%sDMA SIZE %d\n", debug_msg, dma_hdr[15 : 0]);
            $swrite(debug_msg, "%sDMA CNT %d\n", debug_msg, dma_cnt);
            $swrite(debug_msg, "%sDMA HDR\n"   , debug_msg);
            $swrite(debug_msg, "%s===============================================\n", debug_msg);
            `uvm_info(this.get_full_name(),              debug_msg, UVM_HIGH)

            logic_vector_array_new.data = {pcie_hdr[31 : 0], pcie_hdr[63 : 32], pcie_hdr[95 : 64], pcie_hdr[127 : 96], dma_hdr[31 : 0], dma_hdr[63 : 32]};

            sdp_tr.data[16-1 : 0] = (pcie_len*4);
            sdp_tr.data[16] = 1'b1;

            logic_vector_array_export.put(logic_vector_array_new);
            sdp_export.put(sdp_tr);
            logic_vector_export.put(logic_vector_new);

            pcie_tr_fifo.delete();
            seq_item_port_logic_vector_array.item_done();

        end
    endtask

endclass

