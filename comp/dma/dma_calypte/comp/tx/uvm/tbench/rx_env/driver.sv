//-- driver.sv
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause


class driver#(CHANNELS, PKT_SIZE_MAX, ITEM_WIDTH, DATA_ADDR_W, DEVICE) extends uvm_component;
    `uvm_component_param_utils(uvm_dma_ll_rx::driver#(CHANNELS, PKT_SIZE_MAX, ITEM_WIDTH, DATA_ADDR_W, DEVICE))

    localparam PACKET_ALIGNMENT = 32;

    uvm_seq_item_pull_port #(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH), uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)) seq_item_port_logic_vector_array;

    mailbox#(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH))                      logic_vector_array_export;
    mailbox#(uvm_logic_vector::sequence_item#(18))                                    sdp_export;
    mailbox#(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)) logic_vector_export;

    local uvm_dma_regs::regmodel#(CHANNELS) m_regmodel;
    uvm_dma_ll_info::watchdog #(CHANNELS)   m_watch_dog;

    uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)                      logic_vector_array_req;
    uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)                      logic_vector_array_new;
    uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH) logic_vector_new;
    uvm_logic_vector::sequence_item#(18)                                    sdp_tr;

    logic [4-1 : 0]              my_last_lbe = '0;
    logic                        dma_done    = 1'b1;
    int unsigned                 dma_cnt     = 0;
    string                       debug_msg_c;
    logic [$clog2(CHANNELS)-1:0] channel;
    logic [DATA_ADDR_W-1 : 0]    frame_pointer = 0;
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
        uvm_logic_vector::sequence_item#(18)                                    sdp;
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

    function be_info count_be_new(logic [11-1 : 0] pcie_len, logic [4-1 : 0] prev_lbe, logic first, logic last);
        logic [4-1 : 0] fbe;
        logic [4-1 : 0] lbe;
        logic [2-1:0]   prev_invalid_be;
        be_info         pkt_be;
        string          debug_msg;

        prev_invalid_be = sv_dma_bus_pack::encode_lbe(prev_lbe);

        if (first == 1) begin // first transaction of DMA packet
            if (pcie_len == 1) begin
                std::randomize(fbe) with {fbe inside {4'b1111, 4'b0111, 4'b0011, 4'b0001}; };
                lbe = '0;
            end else begin
                fbe = '1; // first transaction is aligned
                std::randomize(lbe) with {lbe inside {4'b1000, 4'b1100, 4'b1010, 4'b1110, 4'b1001, 4'b1101, 4'b1011, 4'b1111, 4'b0100, 4'b0110, 4'b0101, 4'b0111, 4'b0010, 4'b0011, 4'b0001}; };
            end
        end else begin
            if (prev_invalid_be == 0) begin
                fbe = '1;
            end else begin
                fbe = 16 - 2**(4-prev_invalid_be);
            end

            if (pcie_len == 1) begin
                lbe = '0;
            end else begin
                std::randomize(lbe) with {lbe inside {4'b1000, 4'b1100, 4'b1010, 4'b1110, 4'b1001, 4'b1101, 4'b1011, 4'b1111, 4'b0100, 4'b0110, 4'b0101, 4'b0111, 4'b0010, 4'b0011, 4'b0001}; };
            end
        end

        debug_msg = "\n";
        $swrite(debug_msg, "%s==========================================================\n", debug_msg);
        $swrite(debug_msg, "%sBYTE ENABLE CALCULATION:\n", debug_msg);
        $swrite(debug_msg, "%s==========================================================\n", debug_msg);
        $swrite(debug_msg, "%sPCIE LEN   : %0d\n", debug_msg, pcie_len);
        $swrite(debug_msg, "%sFIRST ITEM : %0b\n", debug_msg, first);
        $swrite(debug_msg, "%sLAST ITEM  : %0b\n", debug_msg, last);
        $swrite(debug_msg, "%sPREV BE    : %b\n", debug_msg, prev_lbe);
        $swrite(debug_msg, "%sPREV IBE   : %0d\n", debug_msg, prev_invalid_be);
        $swrite(debug_msg, "%sFIRST BE   : %b\n", debug_msg, fbe);
        $swrite(debug_msg, "%sLAST BE    : %b\n", debug_msg, lbe);
        $swrite(debug_msg, "%s==========================================================\n", debug_msg);
        `uvm_info(this.get_full_name(), debug_msg, UVM_FULL)

        pkt_be.lbe = lbe;
        pkt_be.fbe = fbe;

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
        logic [4-1:0]                prev_lbe;
        logic                        first = 1'b0;
        logic                        last = 1'b0;
        // Transaction construction logic
        int                          final_size_be   = 0;
        // DEBUG
        string                       debug_msg;
        be_info                      pkt_be;

        int                          dma_len;
        int unsigned                 pcie_cnt;
        int unsigned                 data_index;
        int unsigned                 pcie_trans_cnt;
        uvm_logic_vector_array::sequence_item#(ITEM_WIDTH) data;
        // Preparation for out of order generation
        pcie_info                    pcie_tr_fifo[$];
        pcie_info                    pcie_tr;
        logic[16-1 : 0]              prev_sdp = '0;
        logic[16-1 : 0]              sdp_move;
        logic [DATA_ADDR_W-1 : 0]    frame_pointer_old;
        logic [DATA_ADDR_W-1 : 0]    frame_pointer_first;

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
            $swrite(debug_msg, "%s==========================================================\n", debug_msg);
            $swrite(debug_msg, "%slogic_vector_array_export status : %0d\n", debug_msg, logic_vector_array_export.num());
            $swrite(debug_msg, "%sdp_export status                 : %0d\n", debug_msg, sdp_export.num());
            $swrite(debug_msg, "%slogic_vector_export status        : %0d\n", debug_msg, logic_vector_export.num());
            $swrite(debug_msg, "%s==========================================================\n", debug_msg);
            `uvm_info(this.get_full_name(), debug_msg, UVM_FULL)

            debug_msg = "\n";

            dma_len = logic_vector_array_req.size();
            $swrite(debug_msg, "%s===============================================\n", debug_msg);
            $swrite(debug_msg, "%sCREATE DMA TRANSACTION - CHANNEL %0d\n", debug_msg, channel);
            $swrite(debug_msg, "%s===============================================\n", debug_msg);
            $swrite(debug_msg, "%sCHANNEL            :        %0d\n", debug_msg, channel);
            $swrite(debug_msg, "%sDMA LEN IN DWORDS  :        %0d\n", debug_msg, dma_len);

            // DATA logic
            // ====================================================================
            pcie_cnt = 0;
            pcie_trans_cnt = 0;

            final_size_be = 0;

            last = 1'b0;
            pcie_tr.index = 0;
            prev_sdp = 0;
            frame_pointer_first = frame_pointer;
            first = 1'b1;

            while (dma_len) begin
                pcie_trans_cnt++;
                $swrite(debug_msg, "%s-----------------------------------------------\n", debug_msg);
                $swrite(debug_msg, "%sPCIe TRANSACTION %0d  \n", debug_msg, pcie_trans_cnt);
                $swrite(debug_msg, "%s-----------------------------------------------\n", debug_msg);
                data_index = 0;

                if (pcie_len == 1) begin
                    prev_lbe = pkt_be.fbe;
                end else begin
                    prev_lbe = pkt_be.lbe;
                end

                pcie_len = $urandom_range(256, 1);

                if (signed'(dma_len - pcie_len) <= 0) begin
                    pcie_len = dma_len;
                    last = 1'b1;
                end

                $swrite(debug_msg, "%sPCIE LEN IN DWORDS :        %0d\n", debug_msg, pcie_len);

                //pkt_be = count_be(channel, pcie_len, last);
                pkt_be = count_be_new(pcie_len, prev_lbe, first, last);
                first = 1'b0;
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

                dma_len -= pcie_len;
                pcie_tr.data      = uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)::type_id::create("pcie_tr.data");
                pcie_tr.meta      = uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)::type_id::create("pcie_tr.meta");
                pcie_tr.sdp       = uvm_logic_vector::sequence_item# (18)::type_id::create("pcie_tr.sdp");
                pcie_tr.meta.data = '0;

                if (DEVICE == "ULTRASCALE") begin
                    // In case of Xilinx
                    pcie_hdr[DATA_ADDR_W-1 : 2] = addr.data_addr;
                    // Channel num
                    pcie_hdr[(DATA_ADDR_W+1+$clog2(CHANNELS))-1 : DATA_ADDR_W+1] = channel;
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
                    pcie_hdr[(DATA_ADDR_W+$clog2(CHANNELS)+1)] = 1'b0;
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

                $swrite(debug_msg, "%sFBE                :        %b\n", debug_msg, fbe);
                $swrite(debug_msg, "%sDFBE               :        %d\n", debug_msg, dfbe);
                $swrite(debug_msg, "%sLBE                :        %b\n", debug_msg, lbe);
                $swrite(debug_msg, "%sDLBE               :        %d\n", debug_msg, dlbe);
                $swrite(debug_msg, "%sFULL ADDR          :        0x%0h\n", debug_msg, pcie_hdr[63 : 0]);
                $swrite(debug_msg, "%sDATA ADDR          :        0x%0h (%0d)\n", debug_msg, addr.data_addr, addr.data_addr);
                $swrite(debug_msg, "%sFRAME POINTER      :        0x%0h (%0d)\n", debug_msg, frame_pointer, frame_pointer);

                data = uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)::type_id::create("data");
                data.data = new[pcie_len];

                for (int unsigned it = pcie_cnt; it < (pcie_cnt + pcie_len); it++) begin
                    data.data[data_index] = logic_vector_array_req.data[it];
                    data_index++;
                end

                // todo intel fpga support
                pcie_tr.data.data = {pcie_hdr[31 : 0], pcie_hdr[63 : 32], pcie_hdr[95 : 64], pcie_hdr[127 : 96], data.data};
                pcie_cnt += pcie_len;

                sdp_tr = uvm_logic_vector::sequence_item# (18)::type_id::create("sdp_tr");

                sdp_tr.data[16-1 : 0] = prev_sdp + (pcie_len*4) - dfbe - dlbe;
                sdp_tr.data[16] = 1'b0; // 0 = is data transaction
                prev_sdp += (pcie_len*4) - dfbe - dlbe;
                pcie_tr.sdp = sdp_tr;
                pcie_tr.index++;

                pcie_tr_fifo.push_back(pcie_tr);
                if (dma_len < 0) begin
                    `uvm_fatal(this.get_full_name(), "DMA LEN is lower than zero");
                end

                frame_pointer += (pcie_len*4) - dfbe - dlbe;
                final_size_be += (pcie_len*4) - dfbe - dlbe;

                if ((frame_pointer % 4) == 0) begin
                    addr.data_addr += pcie_len;
                end else begin
                    addr.data_addr += pcie_len-1;
                end

            end

            prev_sdp = '0;
            $swrite(debug_msg, "%s-----------------------------------------------\n", debug_msg);
            $swrite(debug_msg, "%sSIZE IN BYTES - BE :        %0d\n", debug_msg, final_size_be);

            // Preparation for out of order generation
            pcie_tr_fifo.shuffle();

            for (int unsigned it = 0; it < pcie_tr_fifo.size(); it++) begin
                sdp_tr = uvm_logic_vector::sequence_item# (18)::type_id::create("sdp_tr");

                pcie_tr = pcie_tr_fifo[it];
                $swrite(debug_msg, "%s-----------------------------------------------\n", debug_msg);
                $swrite(debug_msg, "%sPCIe TRANSACTION with index %0d  \n", debug_msg, pcie_tr.index);
                $swrite(debug_msg, "%s-----------------------------------------------\n", debug_msg);
                $swrite(debug_msg, "%sOUT DATA ADDR      :        0x%0h (%0d)\n", debug_msg, pcie_tr.data.data[0][DATA_ADDR_W-1 : 2], pcie_tr.data.data[0][DATA_ADDR_W-1 : 2]);
                $swrite(debug_msg, "%sOUT Transaction ID :        %0d\n", debug_msg, pcie_tr.index);
                $swrite(debug_msg, "%sOUT DATA %s\n", debug_msg, pcie_tr.data.convert2string());

                logic_vector_array_new = pcie_tr.data;
                logic_vector_new       = pcie_tr.meta;

                if (it == 0) begin
                    // ====================================================================
                    // ALIGN AND UPDATE DATA SW POINTER
                    $swrite(debug_msg, "%s-----------------------------------------------\n", debug_msg);
                    $swrite(debug_msg, "%sALIGN POINTER AND ADDRESS TO 32B \n", debug_msg);
                    $swrite(debug_msg, "%s-----------------------------------------------\n", debug_msg);
                    $swrite(debug_msg, "%sFIRST FRAME PTR      :        %0d\n", debug_msg, frame_pointer_first);
                    $swrite(debug_msg, "%sUNALIGNED FRAME PTR  :        %0d\n", debug_msg, frame_pointer);
                    $swrite(debug_msg, "%sUNALIGNED PCIe ADDR  :        %0d\n", debug_msg, addr.data_addr);

                    if ((frame_pointer % PACKET_ALIGNMENT) != 0) begin
                        frame_pointer += (PACKET_ALIGNMENT-(frame_pointer % PACKET_ALIGNMENT));
                    end

                    addr.data_addr = frame_pointer / 4;

                    $swrite(debug_msg, "%sALIGNED FRAME PTR    :        %0d\n", debug_msg, frame_pointer);
                    $swrite(debug_msg, "%sALIGNED PCIe ADDR    :        %0d\n", debug_msg, addr.data_addr);

                    sdp_move = final_size_be;
                    if ((sdp_move % PACKET_ALIGNMENT) != 0) begin
                        sdp_move += (PACKET_ALIGNMENT-(sdp_move % PACKET_ALIGNMENT));
                    end

                    sdp_tr.data[16-1 : 0] = sdp_move;
                    sdp_tr.data[16] = 1'b0; // 0 = is data transaction

                    $swrite(debug_msg, "%s-----------------------------------------------\n", debug_msg);
                    $swrite(debug_msg, "%sUPDATE DATA SW POINTER\n", debug_msg);
                    $swrite(debug_msg, "%s-----------------------------------------------\n", debug_msg);
                    $swrite(debug_msg, "%SSDP [16-1 :0]      :        0x%0h (%0d)\n", debug_msg, sdp_tr.data[16-1 :0], sdp_tr.data[16-1 :0]);
                    //$swrite(debug_msg, "%sSDP [16] = HDR PTR :        0x%0h (%0d)\n", debug_msg, sdp_tr.data[16], sdp_tr.data[16]);
                end else begin
                    sdp_tr.data[16-1 : 0] = sdp_move;
                    sdp_tr.data[16] = 1'b0; // 0 = is data transaction
                end

                if ((it+1) == pcie_tr_fifo.size()) begin
                    sdp_tr.data[17] = 1'b1; // enable pointer update for last transaction
                end else begin
                    sdp_tr.data[17] = 1'b0; // disable pointer update, only check free space in the buffer
                end

                logic_vector_array_export.put(logic_vector_array_new);
                sdp_export.put(sdp_tr);
                logic_vector_export.put(logic_vector_new);

            end
            min_index = 1;

            // ====================================================================
            // DMA HDR logic
            logic_vector_new       = uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)::type_id::create("logic_vector_new");
            logic_vector_array_new = uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)::type_id::create("logic_vector_array_new");
            sdp_tr                 = uvm_logic_vector::sequence_item# (18)::type_id::create("sdp_tr");

            $swrite(debug_msg, "%s-----------------------------------------------\n", debug_msg);
            $swrite(debug_msg, "%sDMA HEADER  \n", debug_msg);
            $swrite(debug_msg, "%s-----------------------------------------------\n", debug_msg);

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
                pcie_hdr[(DATA_ADDR_W+1+$clog2(CHANNELS))-1 : DATA_ADDR_W+1] = channel;
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
                pcie_hdr[(DATA_ADDR_W+$clog2(CHANNELS)+1)] = 1'b1;
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

            $swrite(debug_msg, "%sFULL ADDR          :        0x%0h\n", debug_msg, pcie_hdr[63 : 0]);
            $swrite(debug_msg, "%sHDR ADDR           :        0x%0h (%0d)\n", debug_msg, addr.hdr_addr, addr.hdr_addr);

            // DMA HDR Filling
            dma_hdr[15 : 0]  = (final_size_be);
            dma_hdr[31 : 16] = frame_pointer_first;
            dma_hdr[39 : 32] = '0;
            dma_hdr[63 : 40] = meta;
            dma_done = 1'b1;
            dma_cnt++;
            last = 1'b1;
            // Increment HDR address
            addr.hdr_addr += pcie_len;

            $swrite(debug_msg, "%sDMA SIZE           :        %0d\n", debug_msg, dma_hdr[15 : 0]);
            $swrite(debug_msg, "%sDMA CNT            :        %0d\n", debug_msg, dma_cnt);
            $swrite(debug_msg, "%sDMA HDR %s\n"   , debug_msg, logic_vector_array_new.convert2string());
            $swrite(debug_msg, "%s===============================================\n", debug_msg);
            `uvm_info(this.get_full_name(),              debug_msg, UVM_MEDIUM)

            // todo intel fpga support
            logic_vector_array_new.data = {pcie_hdr[31 : 0], pcie_hdr[63 : 32], pcie_hdr[95 : 64], pcie_hdr[127 : 96], dma_hdr[31 : 0], dma_hdr[63 : 32]};

            sdp_tr.data[16-1 : 0] = 1; // one HDR = one item in SHP
            sdp_tr.data[16] = 1'b1; // is header pointer
            sdp_tr.data[17] = 1'b1; // enable pointer update

            logic_vector_array_export.put(logic_vector_array_new);
            sdp_export.put(sdp_tr);
            logic_vector_export.put(logic_vector_new);

            pcie_tr_fifo.delete();
            seq_item_port_logic_vector_array.item_done();

        end
    endtask

endclass

