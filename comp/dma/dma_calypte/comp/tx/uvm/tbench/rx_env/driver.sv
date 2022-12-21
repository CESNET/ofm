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
    uvm_dma_ll_info::sync_link#(CHANNELS) link_sync;

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
        logic                        dma_done[CHANNELS]    = '{default:1};
        int                          final_size[CHANNELS]  = '{default:0};
        logic                        last_status[CHANNELS] = '{default:1};

        forever begin
            // Get new sequence item to drive to interface
            seq_item_port_logic_vector_array.get_next_item(logic_vector_array_req);
            seq_item_port_info.get_next_item(cq_header_req);

            logic_vector_new            = uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)::type_id::create("logic_vector_new");
            logic_vector_array_new      = uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)::type_id::create("logic_vector_array_new");

            logic_vector_new.data = '0;
            pcie_hdr              = '0;
            channel               = cq_header_req.channel;

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
                logic_vector_new.data[166 : 163] = '1;
                // LBE
                logic_vector_new.data[170 : 167] = '1;
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


            meta                             = cq_header_req.meta;
            if (dma_done[int'(channel)] == 1) begin
                seq_item_port_dma_size[int'(channel)].get_next_item(size_of_dma[int'(channel)]);

                if (logic_vector_array_req.data.size() > size_of_dma[int'(channel)].dma_size) begin
                    size_of_dma[int'(channel)].dma_size = int'(logic_vector_array_req.data.size());
                end

                dma_done[int'(channel)] = 0;
                final_size[int'(channel)] = 0;
            end

            if (((final_size[int'(channel)] + logic_vector_array_req.data.size()) > size_of_dma[int'(channel)].dma_size)) begin
                logic_vector_array_new.data = new[((DMA_HDR_SIZE+PCIE_HDR_SIZE)/ITEM_WIDTH)];

                pcie_hdr[(DATA_ADDR_W+$clog2(CHANNELS))] = 1'b1;
                // DWORD CNT of DMA HDR
                pcie_hdr[74 : 64]                        = 2;

                dma_hdr[15 : 0]   = (final_size[int'(channel)]*4);
                dma_hdr[31 : 16]  = '0;
                dma_hdr[39 : 32]  = '0;
                dma_hdr[63 : 40]  = meta;

                // $write("DRIVER CHANNEL %d\n", channel);
                // $write("PKT COUNT %d\n", pkt_cnt[int'(channel)]);
                // $write("DMA HDR %h TIME %t\n", dma_hdr, $time());
                // $write("DRIVER PKT SIZE %d\n", dma_hdr[15 : 0]);
                // $write("DMA SIZE %d\n", size_of_dma[int'(channel)].dma_size);
                // $write("PCIE HDR %h\n", pcie_hdr);

                logic_vector_array_new.data = {pcie_hdr[31 : 0], pcie_hdr[63 : 32], pcie_hdr[95 : 64], pcie_hdr[127 : 96], dma_hdr[31 : 0], dma_hdr[63 : 32]};
                dma_done[int'(channel)]   = 1;
                seq_item_port_dma_size[int'(channel)].item_done();
                // `uvm_info(this.get_full_name(), logic_vector_array_new.convert2string() ,UVM_NONE)
            end else begin
                pcie_hdr[(DATA_ADDR_W+$clog2(CHANNELS))] = 1'b0;
                // DWORD CNT of PCIE DATA
                pcie_hdr[74 : 64]                        = logic_vector_array_req.data.size();

                logic_vector_array_new.data = new[logic_vector_array_req.data.size()+(PCIE_HDR_SIZE/ITEM_WIDTH)];
                logic_vector_array_new.data = {pcie_hdr[31 : 0], pcie_hdr[63 : 32], pcie_hdr[95 : 64], pcie_hdr[127 : 96], logic_vector_array_req.data};
                pkt_cnt[int'(channel)]++;
                // $write("DATA DRIVER\n");
                // `uvm_info(this.get_full_name(), logic_vector_array_req.convert2string() ,UVM_NONE)
            end

            final_size[int'(channel)] += logic_vector_array_req.data.size();
            // $write("OUT DATA DRIVER\n");
            // `uvm_info(this.get_full_name(), logic_vector_array_new.convert2string() ,UVM_NONE)

            logic_vector_array_export.put(logic_vector_array_new);
            logic_vector_export.put(logic_vector_new);

            seq_item_port_logic_vector_array.item_done();
            seq_item_port_info.item_done();
        end
    endtask

endclass

