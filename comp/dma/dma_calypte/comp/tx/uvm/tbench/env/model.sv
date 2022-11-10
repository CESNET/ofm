//-- model.sv: Model of implementation
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

class discard #(CHANNELS) extends uvm_component;
    `uvm_component_param_utils(uvm_dma_ll::discard #(CHANNELS))

    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item#(1)) analysis_imp_rx_dma;
    logic drop = 0;

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
        analysis_imp_rx_dma = new("analysis_imp_rx_dma", this);
    endfunction

    task get_tr();
        uvm_logic_vector::sequence_item#(1) drop_tr;
        analysis_imp_rx_dma.get(drop_tr);
        drop = drop_tr.data;
    endtask 

endclass

//model
class model #(CHANNELS, PKT_SIZE_MAX, DEVICE, USR_ITEM_WIDTH, USER_META_WIDTH, CQ_ITEM_WIDTH, DATA_ADDR_W,
              DEBUG, CHANNEL_ARBITER_EN) extends uvm_component;
    `uvm_component_param_utils(uvm_dma_ll::model #(CHANNELS, PKT_SIZE_MAX, DEVICE, USR_ITEM_WIDTH, USER_META_WIDTH,
                                                   CQ_ITEM_WIDTH, DATA_ADDR_W, DEBUG, CHANNEL_ARBITER_EN))

    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item#(CQ_ITEM_WIDTH))                   analysis_imp_rx;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)) analysis_imp_rx_meta;
    uvm_analysis_port     #(uvm_logic_vector_array::sequence_item#(USR_ITEM_WIDTH))                  analysis_port_tx[CHANNELS];
    uvm_analysis_port     #(uvm_logic_vector::sequence_item#(USER_META_WIDTH))                       analysis_port_meta_tx[CHANNELS];
    local regmodel#(CHANNELS)             m_regmodel;

    uvm_dma_ll_info::sync_link#(CHANNELS) link_sync;
    uvm_dma_ll::discard#(CHANNELS)        discard_comp[CHANNELS];

    typedef struct{
        logic [11-1 : 0]               dword_cnt;
        logic [$clog2(CHANNELS)-1 : 0] channel;
        logic [24-1 : 0]               meta;
        logic [2-1 : 0]                run; //[0] -> run, [1] -> soft compare
        logic                          hdr_identifier;
    } packet_info;
    local packet_info info;

    typedef struct{
        int unsigned dma_cnt            = 0;
        int unsigned byte_cnt           = 0;
        int unsigned discard_dma_cnt    = 0;
        int unsigned discard_byte_cnt   = 0;
        int unsigned read_delay_valid   = 0;
        int unsigned read_delay_discard = 0;
    } dma_cnt_reg;
    dma_cnt_reg cnt_reg [CHANNELS];

    function new (string name, uvm_component parent = null);
        super.new(name, parent);
        analysis_imp_rx       = new("analysis_imp_rx", this);
        analysis_imp_rx_meta  = new("analysis_imp_rx_meta", this);
        for (int chan = 0; chan < CHANNELS; chan++) begin
            string i_string;
            i_string.itoa(chan);
            discard_comp[chan]          = uvm_dma_ll::discard#(CHANNELS)::type_id::create({"discard_comp_", i_string}, this);
            analysis_port_tx[chan]      = new({"analysis_port_tx_", i_string}, this);
            analysis_port_meta_tx[chan] = new({"analysis_port_meta_tx_", i_string}, this);
        end
    endfunction

    function void regmodel_set(regmodel#(CHANNELS) m_regmodel);
        this.m_regmodel = m_regmodel;
    endfunction

    task run_phase(uvm_phase phase);
    
        uvm_logic_vector_array::sequence_item#(CQ_ITEM_WIDTH)                   in_data_tr;
        uvm_logic_vector_array::sequence_item#(CQ_ITEM_WIDTH)                   data_tr[CHANNELS];
        uvm_logic_vector_array::sequence_item#(USR_ITEM_WIDTH)                  pcie_data_tr[CHANNELS];
        uvm_logic_vector_array::sequence_item#(USR_ITEM_WIDTH)                  out_data_tr;
        uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH) meta_tr;
        uvm_logic_vector::sequence_item#(USER_META_WIDTH)                       out_meta_tr;

        logic [USR_ITEM_WIDTH-1 : 0] dma_frame[CHANNELS][$];
        logic [16-1 : 0] dma_size               = '0;
        logic [24-1 : 0] dma_meta               = '0;
        uvm_reg_data_t dma_cnt         ;
        uvm_reg_data_t byte_cnt        ;
        uvm_reg_data_t discard_dma_cnt ;
        uvm_reg_data_t discard_byte_cnt;
        uvm_status_e   status_r;
        logic status[CHANNELS];
        logic control[CHANNELS];
        string debug_msg;

        forever begin

           for (int chan = 0; chan < CHANNELS; chan++) begin
                string i_string;
                i_string.itoa(chan);
                pcie_data_tr[chan] = uvm_logic_vector_array::sequence_item #(USR_ITEM_WIDTH)::type_id::create({"pcie_data_tr_", i_string});
                data_tr[chan]      = uvm_logic_vector_array::sequence_item #(CQ_ITEM_WIDTH)::type_id::create({"data_tr_", i_string});
            end

            out_data_tr = uvm_logic_vector_array::sequence_item #(USR_ITEM_WIDTH)::type_id::create("out_data_tr");
            out_meta_tr = uvm_logic_vector::sequence_item #(USER_META_WIDTH)::type_id::create("out_meta_tr");

            analysis_imp_rx.get(in_data_tr);
            analysis_imp_rx_meta.get(meta_tr);

            info.dword_cnt      = in_data_tr.data[2][11-1 : 0];
            info.channel        = in_data_tr.data[0][(DATA_ADDR_W+$clog2(CHANNELS))-1 : DATA_ADDR_W];
            info.hdr_identifier = in_data_tr.data[0][(DATA_ADDR_W+$clog2(CHANNELS))];

            discard_comp[int'(info.channel)].get_tr();

            debug_msg = "";
            $swrite(debug_msg, "IN DATA %s ON CHANNEL %d\n", debug_msg, in_data_tr.convert2string(), int'(info.channel));
            `uvm_info(this.get_full_name(), debug_msg ,UVM_MEDIUM)

            info.run[0] = (m_regmodel.channel[info.channel].status.get() & 32'h1 ) | (m_regmodel.channel[info.channel].control.get() & 32'h1);
            info.run[1] = (m_regmodel.channel[info.channel].status.get() & 32'h1 ) ^ (m_regmodel.channel[info.channel].control.get() & 32'h1);

            status[info.channel]  = m_regmodel.channel[info.channel].status.get() & 32'h1;
            control[info.channel] = m_regmodel.channel[info.channel].control.get() & 32'h1;

            if (info.run[0] && discard_comp[int'(info.channel)].drop == 0) begin
                data_tr[int'(info.channel)].data = new[info.dword_cnt];
                for (int unsigned it = 0; it < (in_data_tr.data.size()-4); it++) begin
                    data_tr[int'(info.channel)].data[it] = in_data_tr.data[it+4];
                end

                // Unpack data from 32b to 8b
                pcie_data_tr[int'(info.channel)].data = new[data_tr[int'(info.channel)].data.size()*4];
                for (int unsigned it = 0; it < data_tr[int'(info.channel)].data.size(); it++) begin
                    pcie_data_tr[int'(info.channel)].data[it*4 +: 4] = {<<8{data_tr[int'(info.channel)].data[it]}};
                end

                $swrite(debug_msg, "%s\nIN 8 %s\n", debug_msg, pcie_data_tr[int'(info.channel)].convert2string());
                $swrite(debug_msg, "%sIN 32 %s\n", debug_msg, data_tr[int'(info.channel)].convert2string());
                $swrite(debug_msg, "%sSIZE OF 8 %d\n", debug_msg, data_tr[int'(info.channel)].data.size()*4);
                `uvm_info(this.get_full_name(), debug_msg ,UVM_MEDIUM)

                if (info.hdr_identifier == 1'b0) begin
                    foreach(pcie_data_tr[int'(info.channel)].data[i]) begin
                        dma_frame[int'(info.channel)].push_back(pcie_data_tr[int'(info.channel)].data[i]);
                    end
                end else begin
                    dma_size = in_data_tr.data[4][15 : 0];
                    dma_meta = in_data_tr.data[5][31 : 8];
                    out_meta_tr.data = {dma_size, info.channel, dma_meta};

                    out_data_tr.data = dma_frame[int'(info.channel)];

                    if (info.run[1] == 0 || (info.run[1] == 1 && discard_comp[int'(info.channel)].drop == 0)) begin
                        cnt_reg[int'(info.channel)].dma_cnt++;
                        cnt_reg[int'(info.channel)].byte_cnt += dma_frame[int'(info.channel)].size();

                        debug_msg = "";
                        $swrite(debug_msg, "%s\nOUT META %s\n", debug_msg, out_meta_tr.convert2string());
                        $swrite(debug_msg, "%s================================================================================= \n", debug_msg);
                        $swrite(debug_msg, "%sEND OF DMA FRAME number %d with size %d on channel %d\n", debug_msg, cnt_reg[int'(info.channel)].dma_cnt, dma_size, int'(info.channel));
                        $swrite(debug_msg, "%sSTATUS %b and CONTROL %b\n", debug_msg, status[int'(info.channel)], control[int'(info.channel)]);
                        $swrite(debug_msg, "%s================================================================================= \n", debug_msg);
                        `uvm_info(this.get_full_name(), debug_msg ,UVM_MEDIUM)

                        dma_frame[int'(info.channel)].delete();

                        if (CHANNEL_ARBITER_EN) begin 
                            analysis_port_tx[0].write(out_data_tr);
                            analysis_port_meta_tx[0].write(out_meta_tr);
                        end else begin
                            analysis_port_tx[int'(info.channel)].write(out_data_tr);
                            analysis_port_meta_tx[int'(info.channel)].write(out_meta_tr);
                        end
                    end
                end
            end

            if (discard_comp[int'(info.channel)].drop == 1) begin
                cnt_reg[int'(info.channel)].read_delay_discard = 0;
                if (info.hdr_identifier == 1'b1) begin
                    cnt_reg[int'(info.channel)].discard_dma_cnt++;

                    if (cnt_reg[int'(info.channel)].read_delay_valid == 30) begin
                        m_regmodel.channel[int'(info.channel)].sent_packets.write(status_r, {32'h1, 32'h1});
                        m_regmodel.channel[int'(info.channel)].sent_packets.read(status_r, dma_cnt);
                        m_regmodel.channel[int'(info.channel)].sent_bytes.write(status_r, {32'h1, 32'h1});
                        m_regmodel.channel[int'(info.channel)].sent_bytes.read(status_r, byte_cnt);

                        if (int'(byte_cnt) != cnt_reg[int'(info.channel)].byte_cnt &&
                            int'(dma_cnt)  != cnt_reg[int'(info.channel)].dma_cnt) begin
                            debug_msg = "";
                            $swrite(debug_msg, "%s\nWRONG VALID COUNTERS ON CHANNEL %d\n", debug_msg, int'(info.channel));
                            $swrite(debug_msg, "%s\nDUT BYTE COUNT %d and MODEL BYTE COUNT %d\n", debug_msg, byte_cnt, cnt_reg[int'(info.channel)].byte_cnt);
                            $swrite(debug_msg, "%sDUT DMA COUNT %d and MODEL DMA COUNT %d\n", debug_msg, dma_cnt, cnt_reg[int'(info.channel)].dma_cnt);
                            `uvm_error(this.get_full_name(), debug_msg);
                        end

                        debug_msg = "";
                        $swrite(debug_msg, "%s\nRECEIVED STATISTICS\n", debug_msg);
                        $swrite(debug_msg, "%sTIME %t\n", debug_msg, $time());
                        $swrite(debug_msg, "%sCHANNEL %d\n", debug_msg, int'(info.channel));
                        $swrite(debug_msg, "%sDMA CNT %d\n", debug_msg, cnt_reg[int'(info.channel)].dma_cnt);
                        $swrite(debug_msg, "%sDMA CNT REG %d\n", debug_msg, dma_cnt);
                        $swrite(debug_msg, "%sBYTE CNT %d\n", debug_msg, cnt_reg[int'(info.channel)].byte_cnt);
                        $swrite(debug_msg, "%sBYTE CNT REG %d\n", debug_msg, byte_cnt);
                        `uvm_info(this.get_full_name(), debug_msg ,UVM_MEDIUM)

                    end
                    cnt_reg[int'(info.channel)].read_delay_valid++;
                    dma_frame[int'(info.channel)].delete();
                end else
                    cnt_reg[int'(info.channel)].discard_byte_cnt += info.dword_cnt*4;

            end else begin
                cnt_reg[int'(info.channel)].read_delay_valid = 0;

                if (cnt_reg[int'(info.channel)].read_delay_discard == 30) begin
                    m_regmodel.channel[int'(info.channel)].discarded_packets.write(status_r, {32'h1, 32'h1});
                    m_regmodel.channel[int'(info.channel)].discarded_packets.read(status_r, discard_dma_cnt);
                    m_regmodel.channel[int'(info.channel)].discarded_bytes.write(status_r, {32'h1, 32'h1});
                    m_regmodel.channel[int'(info.channel)].discarded_bytes.read(status_r, discard_byte_cnt);

                    if (int'(discard_byte_cnt) != cnt_reg[int'(info.channel)].discard_byte_cnt &&
                        int'(discard_dma_cnt)  != cnt_reg[int'(info.channel)].discard_dma_cnt) begin
                        debug_msg = "";
                        $swrite(debug_msg, "%s\nWRONG DISCARD COUNTERS ON CHANNEL %d\n", debug_msg, int'(info.channel));
                        $swrite(debug_msg, "%s\nDUT DISCARD BYTE COUNT %d and MODEL DISCARD BYTE COUNT %d\n", debug_msg, discard_byte_cnt, cnt_reg[int'(info.channel)].discard_byte_cnt);
                        $swrite(debug_msg, "%sDUT DISCARD DMA COUNT %d and MODEL DISCARD DMA COUNT %d\n", debug_msg, discard_dma_cnt, cnt_reg[int'(info.channel)].discard_dma_cnt);
                        `uvm_error(this.get_full_name(), debug_msg);
                    end

                    debug_msg = "";
                    $swrite(debug_msg, "%s\nDISCARD STATISTICS\n", debug_msg);
                    $swrite(debug_msg, "%sTIME %t\n", debug_msg, $time());
                    $swrite(debug_msg, "%sCHANNEL %d\n", debug_msg, int'(info.channel));
                    $swrite(debug_msg, "%sDMA CNT %d\n", debug_msg, cnt_reg[int'(info.channel)].discard_dma_cnt);
                    $swrite(debug_msg, "%sDMA CNT REG %d\n", debug_msg, discard_dma_cnt);
                    $swrite(debug_msg, "%sBYTE CNT %d\n", debug_msg, cnt_reg[int'(info.channel)].discard_byte_cnt);
                    $swrite(debug_msg, "%sBYTE CNT REG %d\n", debug_msg, discard_byte_cnt);
                    `uvm_info(this.get_full_name(), debug_msg ,UVM_MEDIUM)
                end
                cnt_reg[int'(info.channel)].read_delay_discard++;
            end

        end
    endtask

endclass
