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
              DEBUG) extends uvm_component;
    `uvm_component_param_utils(uvm_dma_ll::model #(CHANNELS, PKT_SIZE_MAX, DEVICE, USR_ITEM_WIDTH, USER_META_WIDTH,
                                                   CQ_ITEM_WIDTH, DATA_ADDR_W, DEBUG))

    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item#(CQ_ITEM_WIDTH))                            analysis_imp_rx;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH))          analysis_imp_rx_meta;
    uvm_analysis_port     #(uvm_common::model_item #(uvm_logic_vector_array::sequence_item#(USR_ITEM_WIDTH))) analysis_port_tx;
    uvm_analysis_port     #(uvm_logic_vector::sequence_item#(USER_META_WIDTH))                                analysis_port_meta_tx;
    local uvm_dma_regs::regmodel#(CHANNELS)                                                                   m_regmodel;

    uvm_dma_ll::discard#(CHANNELS) discard_comp;

    typedef struct{
        logic [11-1 : 0]                                        dword_cnt;
        logic [$clog2(CHANNELS)-1 : 0]                          channel;
        logic [2-1 : 0]                                         fbe[CHANNELS];
        logic [2-1 : 0]                                         lbe[CHANNELS];
        logic [4-1 : 0]                                         fbe_vld[CHANNELS];
        logic [4-1 : 0]                                         lbe_vld[CHANNELS];
        logic                                                   hdr_identifier;
        logic [DATA_ADDR_W-2-1 : 0]                             addr;
        uvm_logic_vector_array::sequence_item #(USR_ITEM_WIDTH) pcie_data;
    } pcie_info;
    local pcie_info m_pcie_info;

    typedef struct{
        logic [2-1 : 0] run; //[0] -> run, [1] -> soft compare
        logic           status[CHANNELS] ;
        logic           control[CHANNELS];
    } model_info;
    local model_info m_model_info;

    typedef struct{
        logic [16-1 : 0] dma_size     = '0;
        logic [24-1 : 0] dma_meta     = '0;
        logic [16-1 : 0] frame_pointer    ;
    } dma_info;
    local dma_info dma_hdr;

    typedef struct{
        int unsigned dma_cnt            = 0;
        int unsigned byte_cnt           = 0;
        int unsigned discard_dma_cnt    = 0;
        int unsigned discard_byte_cnt   = 0;
        logic        read_valid         = 1'b1;
        int unsigned read_delay_discard = 0;
    } dma_cnt_reg;
    dma_cnt_reg cnt_reg [CHANNELS];

    function new (string name, uvm_component parent = null);
        super.new(name, parent);
        analysis_imp_rx       = new("analysis_imp_rx", this);
        analysis_imp_rx_meta  = new("analysis_imp_rx_meta", this);
        analysis_port_tx      = new("analysis_port_tx", this);
        analysis_port_meta_tx = new("analysis_port_meta_tx", this);
        discard_comp          = uvm_dma_ll::discard#(CHANNELS)::type_id::create("discard_comp", this);
    endfunction

    function void regmodel_set(uvm_dma_regs::regmodel#(CHANNELS) m_regmodel);
        this.m_regmodel = m_regmodel;
    endfunction

    function logic[4-1 : 0] count_fbe_vld(logic [4-1 : 0] be);
        logic[4-1 : 0] ret;
        casex (be)
            4'b1xx1 : ret = 4'b1111;
            4'b01x1 : ret = 4'b0111;
            4'b1x10 : ret = 4'b1110;
            4'b0011 : ret = 4'b0011;
            4'b0110 : ret = 4'b0110;
            4'b1100 : ret = 4'b1100;
            4'b0001 : ret = 4'b0001;
            4'b0010 : ret = 4'b0010;
            4'b0100 : ret = 4'b0100;
            4'b1000 : ret = 4'b1000;
            4'b0000 : ret = 4'b0000;
        endcase
        return ret;
    endfunction

    task run_phase(uvm_phase phase);

        uvm_logic_vector_array::sequence_item#(CQ_ITEM_WIDTH)                            in_data_tr;
        uvm_logic_vector_array::sequence_item#(CQ_ITEM_WIDTH)                            data_tr[CHANNELS];
        uvm_logic_vector_array::sequence_item#(USR_ITEM_WIDTH)                           pcie_data_tr[CHANNELS];
        uvm_common::model_item #(uvm_logic_vector_array::sequence_item#(USR_ITEM_WIDTH)) out_data_tr;
        uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)          meta_tr;
        uvm_logic_vector::sequence_item#(USER_META_WIDTH)                                out_meta_tr;

        logic [USR_ITEM_WIDTH-1 : 0] dma_memory[CHANNELS][logic [DATA_ADDR_W-1 : 0]];

        uvm_reg_data_t   dma_cnt         ;
        uvm_reg_data_t   byte_cnt        ;
        uvm_reg_data_t   discard_dma_cnt ;
        uvm_reg_data_t   discard_byte_cnt;
        uvm_status_e     status_r        ;
        string           debug_msg       ;
        int unsigned     data_index  = 0 ;
        int unsigned     sw_move     = 0 ;
        int unsigned     tr_cnt      = 0 ;

        forever begin

           for (int chan = 0; chan < CHANNELS; chan++) begin
                string i_string;
                i_string.itoa(chan);
                pcie_data_tr[chan] = uvm_logic_vector_array::sequence_item #(USR_ITEM_WIDTH)::type_id::create({"pcie_data_tr_", i_string});
                data_tr[chan]      = uvm_logic_vector_array::sequence_item #(CQ_ITEM_WIDTH)::type_id::create({"data_tr_", i_string});
            end

            out_data_tr      = uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(USR_ITEM_WIDTH))::type_id::create("out_data_tr");
            out_data_tr.item = uvm_logic_vector_array::sequence_item #(USR_ITEM_WIDTH)::type_id::create("out_data_tr_item");
            out_meta_tr      = uvm_logic_vector::sequence_item #(USER_META_WIDTH)::type_id::create("out_meta_tr");

            debug_msg = "\n";
            $swrite(debug_msg, "%s================ MODEL - WAIT FOR DATA ==================== \n", debug_msg);
            `uvm_info(this.get_full_name(), debug_msg, UVM_FULL)

            analysis_imp_rx.get(in_data_tr);
            out_data_tr.start["model mfb out"] = $time();

            debug_msg = "\n";
            $swrite(debug_msg, "%s================ MODEL - WAIT FOR META ==================== \n", debug_msg);
            `uvm_info(this.get_full_name(), debug_msg, UVM_FULL)

            analysis_imp_rx_meta.get(meta_tr);

            m_pcie_info.dword_cnt      = in_data_tr.data[2][11-1 : 0];
            m_pcie_info.addr           = in_data_tr.data[0][DATA_ADDR_W-1 : 2];
            m_pcie_info.channel        = in_data_tr.data[0][(DATA_ADDR_W+1+$clog2(CHANNELS))-1 : DATA_ADDR_W+1];
            m_pcie_info.hdr_identifier = in_data_tr.data[0][(DATA_ADDR_W+1+$clog2(CHANNELS))];

            if (m_pcie_info.dword_cnt > 1) begin
                m_pcie_info.fbe[int'(m_pcie_info.channel)] = sv_dma_bus_pack::encode_fbe(meta_tr.data[167-1 : 163]);
                m_pcie_info.lbe[int'(m_pcie_info.channel)] = sv_dma_bus_pack::encode_lbe(meta_tr.data[171-1 : 167]);
            end else begin
                m_pcie_info.lbe[int'(m_pcie_info.channel)]     = '0;
                m_pcie_info.fbe[int'(m_pcie_info.channel)]     = '0;
                m_pcie_info.lbe_vld[int'(m_pcie_info.channel)] = meta_tr.data[167-1 : 163];
                m_pcie_info.lbe_vld[int'(m_pcie_info.channel)] = count_fbe_vld(meta_tr.data[167-1 : 163]);
            end

            discard_comp.get_tr();

            debug_msg = "\n";
            tr_cnt++;
            $swrite(debug_msg, "%s================================================================================= \n", debug_msg);
            $swrite(debug_msg, "%sMODEL INPUT PCIe TRANSACTION %0d\n", debug_msg, tr_cnt);
            $swrite(debug_msg, "%s================================================================================= \n", debug_msg);
            $swrite(debug_msg, "%sCHANNEL   : %0d\n", debug_msg, int'(m_pcie_info.channel));
            $swrite(debug_msg, "%sHDR FLAG  : %0b\n", debug_msg, (m_pcie_info.hdr_identifier != 1'b0));
            $swrite(debug_msg, "%sDW CNT    : %0d\n",  debug_msg, m_pcie_info.dword_cnt);
            $swrite(debug_msg, "%sFBE       : %b\n", debug_msg, meta_tr.data[167-1 : 163]);
            $swrite(debug_msg, "%sDFBE      : %d\n", debug_msg, m_pcie_info.fbe[int'(m_pcie_info.channel)]);
            $swrite(debug_msg, "%sLBE       : %b\n", debug_msg, meta_tr.data[171-1 : 167]);
            $swrite(debug_msg, "%sDLBE      : %d\n", debug_msg, m_pcie_info.lbe[int'(m_pcie_info.channel)]);
            //$swrite(debug_msg, "%sDROP FLAG : %0b\n", debug_msg, (m_model_info.run[0] && discard_comp.drop == 0));
            $swrite(debug_msg, "%sDATA      : %s\n", debug_msg, in_data_tr.convert2string());
            $swrite(debug_msg, "%s================================================================================= \n", debug_msg);
            `uvm_info(this.get_full_name(), debug_msg, UVM_FULL)

            m_model_info.run[0] = (m_regmodel.channel[m_pcie_info.channel].status.get() & 32'h1 ) | (m_regmodel.channel[m_pcie_info.channel].control.get() & 32'h1);
            m_model_info.run[1] = (m_regmodel.channel[m_pcie_info.channel].status.get() & 32'h1 ) ^ (m_regmodel.channel[m_pcie_info.channel].control.get() & 32'h1);

            m_model_info.status[m_pcie_info.channel]  = m_regmodel.channel[m_pcie_info.channel].status.get() & 32'h1;
            m_model_info.control[m_pcie_info.channel] = m_regmodel.channel[m_pcie_info.channel].control.get() & 32'h1;

            if (m_model_info.run[0] && discard_comp.drop == 0) begin
                data_tr[int'(m_pcie_info.channel)].data = new[m_pcie_info.dword_cnt];
                for (int unsigned it = 0; it < (in_data_tr.data.size()-4); it++) begin
                    data_tr[int'(m_pcie_info.channel)].data[it] = in_data_tr.data[it+4];
                end

                pcie_data_tr[int'(m_pcie_info.channel)].data = new[(data_tr[int'(m_pcie_info.channel)].data.size()*4)];

                // Unpack data from 32b to 8b
                for (int unsigned it = 0; it < data_tr[int'(m_pcie_info.channel)].data.size(); it++) begin
                    pcie_data_tr[int'(m_pcie_info.channel)].data[it*4 +: 4] = {<<8{data_tr[int'(m_pcie_info.channel)].data[it]}};
                end

                m_pcie_info.pcie_data = pcie_data_tr[int'(m_pcie_info.channel)];

                debug_msg = "\n";
                $swrite(debug_msg, "%sMODEL INPUT PCIe TRANSACTION %0d -- CONVERSION TO BYTES\n", debug_msg, tr_cnt);
                $swrite(debug_msg, "%s================================================================================= \n", debug_msg);
                $swrite(debug_msg, "%sSIZE IN BYTES : %0d\n", debug_msg, data_tr[int'(m_pcie_info.channel)].data.size()*4);
                $swrite(debug_msg, "%sDATA : %s\n", debug_msg, pcie_data_tr[int'(m_pcie_info.channel)].convert2string());
                $swrite(debug_msg, "%s================================================================================= \n", debug_msg);
                `uvm_info(this.get_full_name(),        debug_msg, UVM_FULL)
                sw_move = 0;

                // If PCIE transaction is not DMA HDR, insert it to DMA FRAME
                if (m_pcie_info.hdr_identifier == 1'b0) begin
                    if (m_pcie_info.dword_cnt == 1) begin
                        for (int unsigned it = 0; it < 4; it++) begin
                            if (m_pcie_info.lbe_vld[int'(m_pcie_info.channel)][it] == 1'b1) begin
                                dma_memory[int'(m_pcie_info.channel)][m_pcie_info.addr*4+it] = pcie_data_tr[int'(m_pcie_info.channel)].data[it];
                                sw_move++;
                            end
                        end
                    end else begin
                        for (int unsigned it = int'(m_pcie_info.fbe[int'(m_pcie_info.channel)]); it < pcie_data_tr[int'(m_pcie_info.channel)].data.size() - int'(m_pcie_info.lbe[int'(m_pcie_info.channel)]); it++) begin
                            dma_memory[int'(m_pcie_info.channel)][m_pcie_info.addr*4+it] = pcie_data_tr[int'(m_pcie_info.channel)].data[it];
                        end
                        sw_move = pcie_data_tr[int'(m_pcie_info.channel)].data.size() - int'(m_pcie_info.lbe[int'(m_pcie_info.channel)]) - int'(m_pcie_info.fbe[int'(m_pcie_info.channel)]);
                    end

                    debug_msg = "";
                    $swrite(debug_msg, "%sCHANNEL       : %0d\n", debug_msg, m_pcie_info.channel);
                    $swrite(debug_msg, "%sPCIE ADDR     : 0x%0h (%0d)\n", debug_msg, m_pcie_info.addr, m_pcie_info.addr);
                    $swrite(debug_msg, "%sFBE           : %0d\n",      debug_msg, m_pcie_info.fbe[int'(m_pcie_info.channel)]);
                    $swrite(debug_msg, "%sLBE           : %0d\n",      debug_msg, m_pcie_info.lbe[int'(m_pcie_info.channel)]);
                    $swrite(debug_msg, "%sDW CNT        : %0d\n",  debug_msg, m_pcie_info.dword_cnt);
                    $swrite(debug_msg, "%sSIZE IN BYTES : %0d\n",     debug_msg, pcie_data_tr[int'(m_pcie_info.channel)].data.size());
                    $swrite(debug_msg, "%s================================================================================= \n", debug_msg);
                    `uvm_info(this.get_full_name(),       debug_msg, UVM_FULL)
                // If PCIE transaction is DMA HDR, construct metadata and and DMA FRAME wihtout HDR
                end else begin
                    // DMA HDR construction
                    dma_hdr.dma_size      = in_data_tr.data[4][15 : 0];
                    dma_hdr.frame_pointer = in_data_tr.data[4][31 : 16];
                    dma_hdr.dma_meta      = in_data_tr.data[5][31 : 8];
                    out_meta_tr.data      = {dma_hdr.dma_size, m_pcie_info.channel, dma_hdr.dma_meta};

                    out_data_tr.item.data = new[dma_hdr.dma_size];

                    debug_msg = "\n";
                    $swrite(debug_msg, "%sCHANNEL              : %0d\n", debug_msg, int'(m_pcie_info.channel));
                    $swrite(debug_msg, "%sFRAME POINTER        : %0d\n", debug_msg, dma_hdr.frame_pointer);
                    $swrite(debug_msg, "%sSIZE IN BYTES        : %0d\n", debug_msg, dma_hdr.dma_size);
                    $swrite(debug_msg, "%sMETADATA             : %0d\n", debug_msg, dma_hdr.dma_meta);
                    $swrite(debug_msg, "%s================================================================================= \n", debug_msg);
                    `uvm_info(this.get_full_name(), debug_msg, UVM_FULL)

                    sw_move = 8;

                    data_index = 0;
                    for (int unsigned it = dma_hdr.frame_pointer; it < dma_hdr.frame_pointer+dma_hdr.dma_size; it++) begin
                        out_data_tr.item.data[data_index] = dma_memory[int'(m_pcie_info.channel)][it];
                        data_index++;
                    end

                    if (out_data_tr.item.data.size() != dma_hdr.dma_size) begin
                        debug_msg = "";
                        $swrite(debug_msg, "%s\nSize of transaction %d and size in HDR %d does not fit\n", debug_msg, out_data_tr.item.data.size(), dma_hdr.dma_size);
                        `uvm_error(this.get_full_name(), debug_msg);
                    end

                    // Check if data are valid (channel is running and there is no drop)
                    if (m_model_info.run[1] == 0 || (m_model_info.run[1] == 1 && discard_comp.drop == 0)) begin
                        cnt_reg[int'(m_pcie_info.channel)].dma_cnt++;
                        cnt_reg[int'(m_pcie_info.channel)].byte_cnt += dma_hdr.dma_size;

                        debug_msg = "\n";
                        $swrite(debug_msg, "%s================================================================================= \n", debug_msg);
                        $swrite(debug_msg, "%sMODEL OUTPUT DMA TRANSACTION %0d\n", debug_msg, cnt_reg[int'(m_pcie_info.channel)].dma_cnt);
                        $swrite(debug_msg, "%s================================================================================= \n", debug_msg);
                        $swrite(debug_msg, "%sCHANNEL              : %0d\n", debug_msg, int'(m_pcie_info.channel));
                        $swrite(debug_msg, "%sFRAME POINTER        : %0d\n", debug_msg, dma_hdr.frame_pointer);
                        $swrite(debug_msg, "%sSIZE IN BYTES        : %0d\n", debug_msg, dma_hdr.dma_size);
                        $swrite(debug_msg, "%sCHANNEL STATUS FLAG  : %0b\n", debug_msg, m_model_info.status[int'(m_pcie_info.channel)]);
                        $swrite(debug_msg, "%sCHANNEL CONTROL FLAG : %0b\n", debug_msg, m_model_info.control[int'(m_pcie_info.channel)]);
                        $swrite(debug_msg, "%s================================================================================= \n", debug_msg);
                        $swrite(debug_msg, "%sOUT META: %s\n", debug_msg, out_meta_tr.convert2string());
                        $swrite(debug_msg, "%sOUT DATA: %s\n", debug_msg, out_data_tr.convert2string());
                        $swrite(debug_msg, "%s================================================================================= \n", debug_msg);
                        `uvm_info(this.get_full_name(), debug_msg, UVM_MEDIUM)


                        analysis_port_tx.write(out_data_tr);
                        analysis_port_meta_tx.write(out_meta_tr);
                    end
                end
            end

            // Counters checker
            if (discard_comp.drop == 1) begin
                cnt_reg[int'(m_pcie_info.channel)].read_delay_discard = 0;
                if (m_pcie_info.hdr_identifier == 1'b1) begin
                    dma_hdr.dma_size = in_data_tr.data[4][15 : 0];

                    cnt_reg[int'(m_pcie_info.channel)].discard_dma_cnt++;
                    cnt_reg[int'(m_pcie_info.channel)].discard_byte_cnt += dma_hdr.dma_size;

                    if (m_model_info.status[int'(m_pcie_info.channel)] == 1'b0 && cnt_reg[int'(m_pcie_info.channel)].read_valid == 1'b1) begin
                        m_regmodel.channel[int'(m_pcie_info.channel)].sent_packets.write(status_r, {32'h1, 32'h1});
                        m_regmodel.channel[int'(m_pcie_info.channel)].sent_packets.read(status_r, dma_cnt);
                        m_regmodel.channel[int'(m_pcie_info.channel)].sent_bytes.write(status_r, {32'h1, 32'h1});
                        m_regmodel.channel[int'(m_pcie_info.channel)].sent_bytes.read(status_r, byte_cnt);

                        if (int'(byte_cnt) != cnt_reg[int'(m_pcie_info.channel)].byte_cnt &&
                            int'(dma_cnt)  != cnt_reg[int'(m_pcie_info.channel)].dma_cnt) begin
                            debug_msg = "";
                            $swrite(debug_msg, "%s\nWRONG VALID COUNTERS ON CHANNEL %d\n",        debug_msg, int'(m_pcie_info.channel));
                            $swrite(debug_msg, "%s\nDUT BYTE COUNT %d and MODEL BYTE COUNT %d\n", debug_msg, byte_cnt, cnt_reg[int'(m_pcie_info.channel)].byte_cnt);
                            $swrite(debug_msg, "%sDUT DMA COUNT %d and MODEL DMA COUNT %d\n",     debug_msg, dma_cnt, cnt_reg[int'(m_pcie_info.channel)].dma_cnt);
                            `uvm_error(this.get_full_name(),                                      debug_msg);
                        end

                        debug_msg = "";
                        $swrite(debug_msg, "%s\nRECEIVED STATISTICS\n", debug_msg);
                        $swrite(debug_msg, "%sTIME %t\n",               debug_msg, $time());
                        $swrite(debug_msg, "%sCHANNEL %d\n",            debug_msg, int'(m_pcie_info.channel));
                        $swrite(debug_msg, "%sDMA CNT %d\n",            debug_msg, cnt_reg[int'(m_pcie_info.channel)].dma_cnt);
                        $swrite(debug_msg, "%sDMA CNT REG %d\n",        debug_msg, dma_cnt);
                        $swrite(debug_msg, "%sBYTE CNT %d\n",           debug_msg, cnt_reg[int'(m_pcie_info.channel)].byte_cnt);
                        $swrite(debug_msg, "%sBYTE CNT REG %d\n",       debug_msg, byte_cnt);
                        `uvm_info(this.get_full_name(),                 debug_msg, UVM_MEDIUM)

                        cnt_reg[int'(m_pcie_info.channel)].read_valid = 0;

                    end
                end

            end else begin
                cnt_reg[int'(m_pcie_info.channel)].read_valid = 1;

                if (cnt_reg[int'(m_pcie_info.channel)].read_delay_discard == 30) begin
                    m_regmodel.channel[int'(m_pcie_info.channel)].discarded_packets.write(status_r, {32'h1, 32'h1});
                    m_regmodel.channel[int'(m_pcie_info.channel)].discarded_packets.read(status_r, discard_dma_cnt);
                    m_regmodel.channel[int'(m_pcie_info.channel)].discarded_bytes.write(status_r, {32'h1, 32'h1});
                    m_regmodel.channel[int'(m_pcie_info.channel)].discarded_bytes.read(status_r, discard_byte_cnt);

                    if (int'(discard_byte_cnt) != cnt_reg[int'(m_pcie_info.channel)].discard_byte_cnt &&
                        int'(discard_dma_cnt)  != cnt_reg[int'(m_pcie_info.channel)].discard_dma_cnt) begin
                        debug_msg = "";
                        $swrite(debug_msg, "%s\nWRONG DISCARD COUNTERS ON CHANNEL %d\n", debug_msg, int'(m_pcie_info.channel));
                        $swrite(debug_msg, "%s\nDUT DISCARD BYTE COUNT %d and MODEL DISCARD BYTE COUNT %d\n", debug_msg, discard_byte_cnt, cnt_reg[int'(m_pcie_info.channel)].discard_byte_cnt);
                        $swrite(debug_msg, "%sDUT DISCARD DMA COUNT %d and MODEL DISCARD DMA COUNT %d\n", debug_msg, discard_dma_cnt, cnt_reg[int'(m_pcie_info.channel)].discard_dma_cnt);
                        `uvm_error(this.get_full_name(), debug_msg);
                    end

                    debug_msg = "";
                    $swrite(debug_msg, "%s\nDISCARD STATISTICS\n", debug_msg);
                    $swrite(debug_msg, "%sTIME %t\n",              debug_msg, $time());
                    $swrite(debug_msg, "%sCHANNEL %d\n",           debug_msg, int'(m_pcie_info.channel));
                    $swrite(debug_msg, "%sDMA CNT %d\n",           debug_msg, cnt_reg[int'(m_pcie_info.channel)].discard_dma_cnt);
                    $swrite(debug_msg, "%sDMA CNT REG %d\n",       debug_msg, discard_dma_cnt);
                    $swrite(debug_msg, "%sBYTE CNT %d\n",          debug_msg, cnt_reg[int'(m_pcie_info.channel)].discard_byte_cnt);
                    $swrite(debug_msg, "%sBYTE CNT REG %d\n",      debug_msg, discard_byte_cnt);
                    `uvm_info(this.get_full_name(),                debug_msg, UVM_MEDIUM)
                end
                cnt_reg[int'(m_pcie_info.channel)].read_delay_discard++;
            end

        end
    endtask

endclass
