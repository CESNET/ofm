//-- driver.sv
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause


class driver#(CHANNELS, PKT_SIZE_MAX, ITEM_WIDTH, DATA_ADDR_W, HDR_ADDR_W, DEVICE) extends uvm_component;
    `uvm_component_param_utils(uvm_dma_ll_rx::driver#(CHANNELS, PKT_SIZE_MAX, ITEM_WIDTH, DATA_ADDR_W, HDR_ADDR_W, DEVICE))

    uvm_seq_item_pull_port #(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH), uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)) seq_item_port_logic_vector_array;
    uvm_seq_item_pull_port #(uvm_dma_ll_info::sequence_item, uvm_dma_ll_info::sequence_item)                                         seq_item_port_info;
    uvm_seq_item_pull_port #(uvm_dma_size::sequence_item, uvm_dma_size::sequence_item)                                               seq_item_port_dma_size[CHANNELS];

    mailbox#(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH))                      logic_vector_array_export;
    mailbox#(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)) logic_vector_export;

    uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)                      logic_vector_array_req;
    uvm_dma_ll_info::sequence_item                                          cq_header_req;
    uvm_dma_size::sequence_item                                             size_of_dma[CHANNELS]; // Size of DMA frame in DW with PCIE headers
    uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)                      logic_vector_array_new;
    uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH) logic_vector_new;

    logic [4-1 : 0] last_lbe[CHANNELS] = '{default:0};
    logic [4-1 : 0] my_last_lbe[CHANNELS] = '{default:0};
    logic           dma_done[CHANNELS] = '{default:1};
    string       debug_msg_c[CHANNELS];

    // ------------------------------------------------------------------------
    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);

        seq_item_port_logic_vector_array = new("seq_item_port_logic_vector_array", this);
        seq_item_port_info               = new("seq_item_port_info", this);
        for (int unsigned chan = 0; chan < CHANNELS; chan++) begin
            string i_string;
            i_string.itoa(chan);

            seq_item_port_dma_size[chan] = new({"seq_item_port_dma_size", i_string}, this);
        end

        logic_vector_array_export = new(1);
        logic_vector_export       = new(1);
    endfunction

    typedef struct{
        logic [4-1 : 0] fbe;
        logic [4-1 : 0] lbe;
    } packet_info;

    function packet_info count_be(logic [$clog2(CHANNELS)-1:0] channel, logic [11-1 : 0] pcie_len);
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
        packet_info  pkt_be;

        if (dma_done[int'(channel)]) begin

            $swrite(debug_msg_c[int'(channel)], "%sLAST\n", debug_msg_c[int'(channel)]);
            $swrite(debug_msg_c[int'(channel)], "%s==========================================================\n", debug_msg_c[int'(channel)]);
            `uvm_info(this.get_full_name(),              debug_msg_c[int'(channel)], UVM_MEDIUM)

            debug_msg_c[int'(channel)] = "";
        
            $swrite(debug_msg_c[int'(channel)], "%s==========================================================\n", debug_msg_c[int'(channel)]);
            $swrite(debug_msg_c[int'(channel)], "%sCHANNEL: %d\n", debug_msg_c[int'(channel)], channel);

            my_last_lbe[int'(channel)] = '0;
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
                if (my_last_lbe[int'(channel)][it] == 1'b1) begin
                    last_one_index = it;
                    tmp_fbe[it] = 1'b1;
                end
                // $write("INDEX %d\n", last_one_index);
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
                // $write("tmp_fbe %b\n", tmp_fbe);
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

        $swrite(debug_msg_c[int'(channel)], "%sFBE:      %b\n", debug_msg_c[int'(channel)], fbe);
        $swrite(debug_msg_c[int'(channel)], "%sLBE:      %b\n", debug_msg_c[int'(channel)], lbe);
        $swrite(debug_msg_c[int'(channel)], "%sPCIE LEN: %d\n", debug_msg_c[int'(channel)], pcie_len);
        pkt_be.lbe = lbe;
        pkt_be.fbe = fbe;
        if (pcie_len > 1) begin
            my_last_lbe[int'(channel)] = lbe;
        end else begin
            my_last_lbe[int'(channel)] = fbe;
        end

        return pkt_be;
    endfunction

    // ------------------------------------------------------------------------
    // Starts driving signals to interface
    task run_phase(uvm_phase phase);
        localparam PCIE_HDR_SIZE = 128;
        localparam DMA_HDR_SIZE  = 64;

        int unsigned pkt_cnt[CHANNELS];
        logic [$clog2(CHANNELS)-1:0] channel;
        logic [24-1:0]               meta;
        logic [DMA_HDR_SIZE-1:0]     dma_hdr;
        logic [PCIE_HDR_SIZE-1:0]    pcie_hdr;
        logic [11-1 : 0]             pcie_len;
        // BE logic
        logic [4-1:0]                fbe;
        logic [2-1:0]                dfbe;
        logic [4-1:0]                lbe;
        logic [2-1:0]                dlbe;
        logic                        first_lbe[CHANNELS]   = '{default:0};
        // Transaction construction logic
        int                          final_size[CHANNELS]  = '{default:0};
        logic                        last_status[CHANNELS] = '{default:1};
        // DEBUG
        string                       debug_msg;
        string                       debug_msg_ch[CHANNELS];
        packet_info                  pkt_be;

        forever begin
            // Get new sequence item to drive to interface
            seq_item_port_logic_vector_array.get_next_item(logic_vector_array_req);
            seq_item_port_info.get_next_item(cq_header_req);

            pcie_len = logic_vector_array_req.data.size();

            logic_vector_new            = uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)::type_id::create("logic_vector_new");
            logic_vector_array_new      = uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)::type_id::create("logic_vector_array_new");

            logic_vector_new.data = '0;
            pcie_hdr              = '0;
            channel               = cq_header_req.channel;

            pkt_be = count_be(channel, pcie_len);

            fbe = pkt_be.fbe;
            lbe = pkt_be.lbe;

            dfbe = sv_dma_bus_pack::encode_fbe(fbe);
            dlbe = sv_dma_bus_pack::encode_lbe(lbe);

            $swrite(debug_msg, "%sDRIVER CHANNEL: %d\n", debug_msg, channel);
            $swrite(debug_msg, "%sDRIVER SIZE:    %d\n", debug_msg, pcie_len);
            `uvm_info(this.get_full_name(),              debug_msg, UVM_MEDIUM)

            if (DEVICE == "ULTRASCALE") begin
                // In case of Xilinx
                // DATA Address (Not yet implemented in design)
                pcie_hdr[DATA_ADDR_W-1 : 2] = '0;
                // Channel num
                pcie_hdr[(DATA_ADDR_W+$clog2(CHANNELS))-1 : DATA_ADDR_W] = channel;
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
                logic_vector_new.data[127 : 0] = pcie_hdr;
                // BAR PREFIX
                logic_vector_new.data[159 : 128] = 6'd26;
            end


            meta = cq_header_req.meta;
            if (dma_done[int'(channel)] == 1) begin
                debug_msg_ch[int'(channel)] = "";
                seq_item_port_dma_size[int'(channel)].get_next_item(size_of_dma[int'(channel)]);

                if (pcie_len > size_of_dma[int'(channel)].dma_size) begin
                    size_of_dma[int'(channel)].dma_size = int'(pcie_len);
                end
                $swrite(debug_msg_ch[int'(channel)], "%s\n==========================================================\n", debug_msg_ch[int'(channel)]);
                $swrite(debug_msg_ch[int'(channel)], "%sCHANNEL %d\n", debug_msg_ch[int'(channel)], channel);
                $swrite(debug_msg_ch[int'(channel)], "%sDMA SIZE %d\n", debug_msg_ch[int'(channel)], size_of_dma[int'(channel)].dma_size);

                dma_done[int'(channel)] = 0;
                final_size[int'(channel)] = 0;
            end

            if (((final_size[int'(channel)]/4 + pcie_len) > size_of_dma[int'(channel)].dma_size)) begin
                logic_vector_array_new.data = new[((DMA_HDR_SIZE+PCIE_HDR_SIZE)/ITEM_WIDTH)];

                pcie_hdr[(DATA_ADDR_W+$clog2(CHANNELS))] = 1'b1;
                // DWORD CNT of DMA HDR
                pcie_hdr[74 : 64]                        = 2;

                if (pkt_cnt[int'(channel)] == 0) begin
                    `uvm_error(this.get_full_name(), "DMA HEADER but there are no PCIE transaction inside DMA FRAME");
                end

                dma_hdr[15 : 0]  = (final_size[int'(channel)]);
                $swrite(debug_msg_ch[int'(channel)], "%sSIZE %d\n", debug_msg_ch[int'(channel)], final_size[int'(channel)]);
                dma_hdr[31 : 16] = '0;
                dma_hdr[39 : 32] = '0;
                dma_hdr[63 : 40] = meta;
                logic_vector_new.data[166 : 163] = '1;
                logic_vector_new.data[170 : 167] = '1;
                fbe = '1;
                lbe = '1;

                $swrite(debug_msg_ch[int'(channel)], "%sDRIVER FBE:     %b\n", debug_msg_ch[int'(channel)], logic_vector_new.data[166 : 163]);
                $swrite(debug_msg_ch[int'(channel)], "%sDRIVER LBE:     %b\n", debug_msg_ch[int'(channel)], logic_vector_new.data[170 : 167]);
                $swrite(debug_msg_ch[int'(channel)], "%sLAST\n", debug_msg_ch[int'(channel)]);
                $swrite(debug_msg_ch[int'(channel)], "%s==========================================================\n", debug_msg_ch[int'(channel)]);
                `uvm_info(this.get_full_name(),              debug_msg_ch[int'(channel)], UVM_MEDIUM)

                $swrite(debug_msg, "%sDRIVER CHANNEL %d\n",  debug_msg, channel);
                $swrite(debug_msg, "%sPKT COUNT %d\n",       debug_msg, pkt_cnt[int'(channel)]);
                $swrite(debug_msg, "%sDMA HDR %h TIME %t\n", debug_msg, dma_hdr, $time());
                $swrite(debug_msg, "%sDRIVER PKT SIZE %d\n", debug_msg, dma_hdr[15 : 0]);
                $swrite(debug_msg, "%sDMA SIZE %d\n",        debug_msg, size_of_dma[int'(channel)].dma_size);
                $swrite(debug_msg, "%sPCIE HDR %h\n",        debug_msg, pcie_hdr);
                `uvm_info(this.get_full_name(),              debug_msg, UVM_MEDIUM)

                logic_vector_array_new.data = {pcie_hdr[31 : 0], pcie_hdr[63 : 32], pcie_hdr[95 : 64], pcie_hdr[127 : 96], dma_hdr[31 : 0], dma_hdr[63 : 32]};
                dma_done[int'(channel)]     = 1;
                pkt_cnt[int'(channel)] = 0;
                seq_item_port_dma_size[int'(channel)].item_done();
            end else begin

                $swrite(debug_msg_ch[int'(channel)], "%sPCIE SIZE %d\n", debug_msg_ch[int'(channel)], logic_vector_array_req.size());

                logic_vector_array_new.data              = new[pcie_len+(PCIE_HDR_SIZE/ITEM_WIDTH)];
                pcie_hdr[(DATA_ADDR_W+$clog2(CHANNELS))] = 1'b0;
                pcie_hdr[74 : 64]                        = pcie_len;

                logic_vector_array_new.data = {pcie_hdr[31 : 0], pcie_hdr[63 : 32], pcie_hdr[95 : 64], pcie_hdr[127 : 96], logic_vector_array_req.data};
                pkt_cnt[int'(channel)]++;
                $swrite(debug_msg, "%sDATA DRIVER\n %s\n", debug_msg, logic_vector_array_req.convert2string());
                `uvm_info(this.get_full_name(),            debug_msg, UVM_MEDIUM)
            end

            $swrite(debug_msg_ch[int'(channel)], "%sDRIVER FBE:     %b\n", debug_msg_ch[int'(channel)], logic_vector_new.data[166 : 163]);
            $swrite(debug_msg_ch[int'(channel)], "%sDRIVER LBE:     %b\n", debug_msg_ch[int'(channel)], logic_vector_new.data[170 : 167]);

            final_size[int'(channel)] += (pcie_len*4);
            $swrite(debug_msg, "%sOUT DATA DRIVER\n %s\n", debug_msg, logic_vector_array_new.convert2string());
            `uvm_info(this.get_full_name(),                debug_msg, UVM_MEDIUM)

            logic_vector_array_export.put(logic_vector_array_new);
            logic_vector_export.put(logic_vector_new);

            seq_item_port_logic_vector_array.item_done();
            seq_item_port_info.item_done();
        end
    endtask

endclass

