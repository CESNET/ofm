//-- model.sv: Model of implementation
//-- Copyright (C) 2023 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

class cc_mtc_item#(MFB_ITEM_WIDTH);

    uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH) data_tr;
    logic [8-1 : 0]                                         tag;
    logic                                                   error;

    function string convert2string();
        string msg;

        $swrite(msg, "\n\tDATA %s\n TAG %h\n ERROR %h", data_tr.convert2string(), tag, error);
        return msg;
    endfunction

endclass

//model
class model #(MFB_ITEM_WIDTH, DEVICE, ENDPOINT_TYPE, MI_DATA_WIDTH, MI_ADDR_WIDTH) extends uvm_component;
    `uvm_component_param_utils(uvm_mtc::model #(MFB_ITEM_WIDTH, DEVICE, ENDPOINT_TYPE, MI_DATA_WIDTH, MI_ADDR_WIDTH))

    uvm_tlm_analysis_fifo #(uvm_common::model_item #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH)))                  analysis_imp_cq_data;
    uvm_tlm_analysis_fifo #(uvm_common::model_item #(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH))) analysis_imp_cq_meta;
    uvm_analysis_port     #(uvm_common::model_item #(uvm_mi::sequence_item_request #(MI_DATA_WIDTH, MI_ADDR_WIDTH, 0)))        analysis_port_mi_data;

    function new (string name, uvm_component parent = null);
        super.new(name, parent);
        analysis_imp_cq_data  = new("analysis_imp_cq_data" , this);
        analysis_imp_cq_meta  = new("analysis_imp_cq_meta" , this);
        analysis_port_mi_data = new("analysis_port_mi_data", this);
    endfunction

    // TODO: Prepare for other DEVICEs, now support STRATIX10 (P_TILE)
    task count_mi_addr(input logic[sv_pcie_meta_pack::PCIE_META_REQ_HDR_W-1 : 0] hdr, input logic[(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH-sv_pcie_meta_pack::PCIE_META_REQ_HDR_W)-1 : 0] meta, output logic [64-1 : 0] mi_addr_base, output int unsigned hdr_offset);
        logic [32-1 : 0] bar_base_addr = '0;
        logic [64-1 : 0] addr          = '0;
        logic [3-1 : 0]  bar           = '0;
        // It is input port but now is set to constant 6'd26 (in case of Intel)
        logic [6-1 : 0] bar_ap = 6'd26;
        logic [64-1 : 0] tlp_addr_mask = '0;
        hdr_offset = 0;

        if (DEVICE == "ULTRASCALE" || DEVICE == "7SERIES") begin
            addr   = hdr[64-1 : 0];
            bar    = hdr[115-1 : 112];
            bar_ap = hdr[121-1 : 115];
            hdr_offset = sv_pcie_meta_pack::PCIE_META_REQ_HDR_W/MFB_ITEM_WIDTH;
        end else if(DEVICE == "STRATIX10" || DEVICE == "AGILEX") begin
            if (hdr[29] == 1'b1) begin
                addr = {hdr[95 : 64], hdr[127 : 98], 2'b00};
                if (ENDPOINT_TYPE == "H_TILE")
                    hdr_offset = sv_pcie_meta_pack::PCIE_META_REQ_HDR_W/MFB_ITEM_WIDTH;
            end else begin
                if (ENDPOINT_TYPE == "H_TILE")
                    hdr_offset = sv_pcie_meta_pack::PCIE_META_REQ_HDR_W/MFB_ITEM_WIDTH-1;

                addr = {32'h0, hdr[95 : 66], 2'b00};
            end

            bar  = meta[35-1 : 32];
        end

        case (bar)
            3'b000  : bar_base_addr = 'h01000000;
            3'b001  : bar_base_addr = 'h02000000;
            3'b010  : bar_base_addr = 'h03000000;
            3'b011  : bar_base_addr = 'h04000000;
            3'b100  : bar_base_addr = 'h05000000;
            3'b101  : bar_base_addr = 'h06000000;
            3'b110  : bar_base_addr = 'h0A000000;
            default : bar_base_addr = 'h0;
        endcase

        for (int unsigned it = 0; it < bar_ap; it++) begin
            tlp_addr_mask[it] = 1'b1;
        end

        mi_addr_base = (addr & tlp_addr_mask) + bar_base_addr;
    endtask

    task gen_mi_read(input logic[32-1 : 0] addr, input logic[(32/8)-1 : 0] be, output uvm_mi::sequence_item_request #(MI_DATA_WIDTH, MI_ADDR_WIDTH, 0) mi_tr);
        mi_tr = uvm_mi::sequence_item_request #(MI_DATA_WIDTH, MI_ADDR_WIDTH, 0)::type_id::create("mi_tr");

        mi_tr.dwr  = '0;
        mi_tr.addr = addr;
        mi_tr.be   = be;
        mi_tr.wr   = 1'b0;
        mi_tr.rd   = 1'b1;
        mi_tr.ardy = 1'b1;
        mi_tr.meta = 'z;
    endtask

    task gen_mi_write(input logic[32-1 : 0] addr, input logic[MFB_ITEM_WIDTH-1 : 0] data, input logic[(MI_DATA_WIDTH/8)-1 : 0] be, output uvm_mi::sequence_item_request #(MI_DATA_WIDTH, MI_ADDR_WIDTH, 0) mi_tr);
        mi_tr = uvm_mi::sequence_item_request #(MI_DATA_WIDTH, MI_ADDR_WIDTH, 0)::type_id::create("mi_tr");

        mi_tr.dwr  = data;
        mi_tr.addr = addr;
        mi_tr.be   = be;
        mi_tr.wr   = 1'b1;
        mi_tr.rd   = 1'b0;
        mi_tr.ardy = 1'b1;
        mi_tr.meta = 'z;
    endtask

    task run_phase(uvm_phase phase);
    
        localparam IS_INTEL_DEV    = (DEVICE == "STRATIX10" || DEVICE == "AGILEX");
        localparam IS_XILINX_DEV   = (DEVICE == "ULTRASCALE" || DEVICE == "7SERIES");
        localparam IS_MFB_META_DEV = (ENDPOINT_TYPE == "P_TILE" || ENDPOINT_TYPE == "R_TILE") && IS_INTEL_DEV;

        uvm_common::model_item #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH))                  cq_data_tr;
        uvm_common::model_item #(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)) cq_meta_tr;
        uvm_common::model_item #(uvm_mi::sequence_item_request #(MI_DATA_WIDTH, MI_ADDR_WIDTH, 0))        mi_tr;

        logic [64-1 : 0]     mi_addr_base = '0;
        logic [11-1 : 0]     dw_cnt       = '0;
        logic [4-1 : 0]      fbe          = '0;
        logic [4-1 : 0]      lbe          = '0;
        logic [8-1 : 0]      req_type     = '0;
        logic [(32/8)-1 : 0] be           = '0;
        logic [3-1 : 0]      rw           = '0;
        int unsigned hdr_offset           = 0;

        logic[sv_pcie_meta_pack::PCIE_META_REQ_HDR_W-1 : 0] hdr;
        logic[(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH-sv_pcie_meta_pack::PCIE_META_REQ_HDR_W)-1 : 0] meta;

        forever begin

            analysis_imp_cq_meta.get(cq_meta_tr);
            meta = cq_meta_tr.item.data[sv_pcie_meta_pack::PCIE_CQ_META_WIDTH-1 : sv_pcie_meta_pack::PCIE_META_REQ_HDR_W];
            `uvm_info(this.get_full_name(), cq_meta_tr.convert2string() ,UVM_MEDIUM)


            if (IS_MFB_META_DEV) begin
                // Only Intel
                hdr      = cq_meta_tr.item.data[sv_pcie_meta_pack::PCIE_META_REQ_HDR_W-1 : 0];
                fbe      = hdr[36-1 : 32];
                lbe      = hdr[40-1 : 36];
                dw_cnt   = hdr[10-1 : 0];
                req_type   = hdr[32-1 : 24];

                analysis_imp_cq_data.get(cq_data_tr);
            end else begin
                if (IS_INTEL_DEV) begin
                    analysis_imp_cq_data.get(cq_data_tr);
                    `uvm_info(this.get_full_name(), cq_data_tr.convert2string() ,UVM_MEDIUM)
                    // GET HEADER
                    for (int unsigned it = 0; it < (sv_pcie_meta_pack::PCIE_META_REQ_HDR_W/MFB_ITEM_WIDTH); it++) begin
                        hdr[((it+1)*32-1) -: 32] = cq_data_tr.item.data[it];
                    end

                    fbe        = hdr[36-1 : 32];
                    lbe        = hdr[40-1 : 36];
                    dw_cnt     = hdr[10-1 : 0];
                    req_type   = hdr[32-1 : 24];

                end else begin
                    analysis_imp_cq_data.get(cq_data_tr);
                    `uvm_info(this.get_full_name(), cq_data_tr.convert2string() ,UVM_MEDIUM)
                    // GET HEADER
                    for (int unsigned it = 0; it < (sv_pcie_meta_pack::PCIE_META_REQ_HDR_W/MFB_ITEM_WIDTH); it++) begin
                        hdr[((it+1)*32-1) -: 32] = cq_data_tr.item.data[it];
                    end

                    dw_cnt            = hdr[75-1 : 64];
                    fbe               = meta[39-1 : 35];
                    lbe               = meta[43-1 : 39];
                    req_type[4-1 : 0] = hdr[79-1 : 75];

                end
            end

            rw = uvm_pcie_hdr::encode_type(req_type, IS_INTEL_DEV);

            if (!(rw == 3'b011 || rw == 3'b010 || rw == 3'b100)) begin
                count_mi_addr(hdr, meta, mi_addr_base, hdr_offset);
                for (int unsigned it = hdr_offset; it < (dw_cnt + hdr_offset); it++) begin
                    mi_tr      = uvm_common::model_item #(uvm_mi::sequence_item_request #(MI_DATA_WIDTH, MI_ADDR_WIDTH, 0))::type_id::create("mi_tr");
                    mi_tr.item = uvm_mi::sequence_item_request #(MI_DATA_WIDTH, MI_ADDR_WIDTH, 0)::type_id::create("mi_tr_item");

                    if (it == hdr_offset)
                        be = fbe;
                    else if (it == (dw_cnt + hdr_offset) - MFB_ITEM_WIDTH/MI_DATA_WIDTH)
                        be = lbe;
                    else
                        be = '1;

                    if (rw == 3'b001) begin
                        gen_mi_write(mi_addr_base + (it - hdr_offset)*4, cq_data_tr.item.data[it], be, mi_tr.item);
                    end else if (rw == 3'b000)
                        gen_mi_read(mi_addr_base + (it - hdr_offset)*4, be, mi_tr.item);

                    analysis_port_mi_data.write(mi_tr);
                end
            end
        end
    endtask

endclass

class response_model #(MFB_ITEM_WIDTH, DEVICE, ENDPOINT_TYPE, MI_DATA_WIDTH, MI_ADDR_WIDTH) extends uvm_component;
    `uvm_component_param_utils(uvm_mtc::response_model #(MFB_ITEM_WIDTH, DEVICE, ENDPOINT_TYPE, MI_DATA_WIDTH, MI_ADDR_WIDTH))

    uvm_tlm_analysis_fifo #(uvm_common::model_item #(uvm_mi::sequence_item_response #(MI_DATA_WIDTH)))                         analysis_imp_cc_mi;
    uvm_analysis_port     #(uvm_common::model_item #(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CC_META_WIDTH))) analysis_port_cc_meta;
    uvm_analysis_port     #(uvm_common::model_item #(uvm_mtc::cc_mtc_item#(MFB_ITEM_WIDTH)))                                   analysis_port_cc;
    uvm_tlm_analysis_fifo #(uvm_common::model_item #(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH))) analysis_imp_cq_meta;
    uvm_tlm_analysis_fifo #(uvm_common::model_item #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH)))                  analysis_imp_cq_data;

    localparam IS_INTEL_DEV    = (DEVICE == "STRATIX10" || DEVICE == "AGILEX");
    localparam IS_XILINX_DEV   = (DEVICE == "ULTRASCALE" || DEVICE == "7SERIES");
    localparam IS_MFB_META_DEV = (ENDPOINT_TYPE == "P_TILE" || ENDPOINT_TYPE == "R_TILE") && IS_INTEL_DEV;

    logic[sv_pcie_meta_pack::PCIE_META_REQ_HDR_W-1 : 0] hdrs [$];
    logic[(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH-sv_pcie_meta_pack::PCIE_META_REQ_HDR_W)-1 : 0] metas [$];
    int pkt_cnt = 0;

    function new (string name, uvm_component parent = null);
        super.new(name, parent);
        analysis_port_cc_meta = new("analysis_port_cc_meta", this);
        analysis_port_cc      = new("analysis_port_cc", this);
        analysis_imp_cc_mi    = new("analysis_imp_cc_mi", this);
        analysis_imp_cq_meta  = new("analysis_imp_cq_meta", this);
        analysis_imp_cq_data  = new("analysis_imp_cq_data", this);
    endfunction

    typedef struct {
        logic[sv_pcie_meta_pack::PCIE_META_CPL_HDR_W-1 : 0]                                       hdr;
        logic[sv_pcie_meta_pack::PCIE_CC_META_WIDTH-sv_pcie_meta_pack::PCIE_META_CPL_HDR_W-1 : 0] meta;
        logic error;
        logic[8-1 : 0] tag;
    } pcie;

    task hdr_catch();
        uvm_common::model_item #(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)) cq_meta_tr;
        uvm_common::model_item #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH))                  cq_data_tr;

        logic[sv_pcie_meta_pack::PCIE_META_REQ_HDR_W-1 : 0] hdr;
        logic[8-1 : 0]                                      req_type;
        logic[3-1 : 0]                                      rw = '0;

        analysis_imp_cq_meta.get(cq_meta_tr);

        if (IS_MFB_META_DEV == 0) begin

            analysis_imp_cq_data.get(cq_data_tr);
            for (int unsigned it = 0; it < (sv_pcie_meta_pack::PCIE_META_REQ_HDR_W/MFB_ITEM_WIDTH); it++) begin
                hdr[((it+1)*32-1) -: 32] = cq_data_tr.item.data[it];
            end

        end else if (IS_MFB_META_DEV == 1)
            hdr = cq_meta_tr.item.data[sv_pcie_meta_pack::PCIE_META_REQ_HDR_W-1 : 0];
        else
            `uvm_error(this.get_full_name(), "Unsupported DEVICE");

        req_type = (IS_INTEL_DEV) ? hdr[32-1 : 24] : {4'b0000, hdr[79-1 : 75]};

        rw = uvm_pcie_hdr::encode_type(req_type, IS_INTEL_DEV);

        if (rw == 3'b000 || rw == 3'b100) begin
            hdrs.push_back(hdr);
            metas.push_back(cq_meta_tr.item.data[sv_pcie_meta_pack::PCIE_CQ_META_WIDTH-1 : sv_pcie_meta_pack::PCIE_META_REQ_HDR_W]);
        end
    endtask

    function pcie gen_meta(logic[sv_pcie_meta_pack::PCIE_META_REQ_HDR_W-1 : 0] hdr, logic[(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH-sv_pcie_meta_pack::PCIE_META_REQ_HDR_W)-1 : 0] meta);
            pcie             ret;
            logic [7-1 : 0]  low_addr;
            logic [2-1 : 0]  addr_type;
            logic [13-1 : 0] byte_cnt = '0;
            logic [11-1 : 0] dw_cnt;
            logic [3-1 : 0]  comp_st = '0;
            logic [16-1 : 0] req_id;
            logic [8-1 : 0]  tag;
            logic [8-1 : 0]  func_id;
            logic [8-1 : 0]  bus_num = '0;
            logic [3-1 : 0]  tc;
            logic [3-1 : 0]  attr;
            logic            comp_with_data = 1'b1;
            logic [8-1 : 0]  req_type = '0;
            logic[3-1 : 0]   rw = '0;

            logic [8-1 : 0] tph_st_tag;
            logic [2-1 : 0] tph_type;
            logic           tph_present;
            logic [4-1 : 0] lbe;
            logic [4-1 : 0] fbe;
            logic [64-1 : 0] addr;

            ret.hdr   = '0;
            ret.meta  = '0;
            ret.error = '0;
            // XILINX
            if (IS_INTEL_DEV) begin
                // Low address computation
                addr = hdr[128-1 : 64];
                if (|addr[64-1 : 32]) begin
                    low_addr = {addr[41-1 : 34], sv_dma_bus_pack::encode_fbe(hdr[36-1 : 32])};
                end else
                    low_addr = {addr[7-1 : 2], sv_dma_bus_pack::encode_fbe(hdr[36-1 : 32])};

                addr_type = hdr[12-1 : 10];
                dw_cnt        = hdr[10-1 : 0];
                req_id        = hdr[64-1 : 48];
                tag           = hdr[48-1 : 40];
                func_id       = meta[8-1 : 0];
                tc            = hdr[23-1 : 20];
                attr[2-1 : 0] = hdr[14-1 : 12];
                attr[2]       = hdr[19-1 : 18];
                req_type      = hdr[32-1 : 24];

                // Byte count computation
                if (dw_cnt == 1)
                    casex (hdr[36-1 : 32])
                        4'b1xx1 : byte_cnt = 4;
                        4'b01x1 : byte_cnt = 3;
                        4'b1x10 : byte_cnt = 3;
                        4'b0011 : byte_cnt = 2;
                        4'b0110 : byte_cnt = 2;
                        4'b1100 : byte_cnt = 2;
                        4'b0001 : byte_cnt = 1;
                        4'b0010 : byte_cnt = 1;
                        4'b0100 : byte_cnt = 1;
                        4'b1000 : byte_cnt = 1;
                        4'b0000 : byte_cnt = 1;
                    endcase
                else
                    byte_cnt = int'(hdr[10-1 : 0] * 4) - int'(sv_dma_bus_pack::encode_fbe(hdr[36-1 : 32])) - int'(sv_dma_bus_pack::encode_lbe(hdr[40-1 : 36]));

                rw = uvm_pcie_hdr::encode_type(req_type, IS_INTEL_DEV);

                if (rw == 3'b100) begin
                    // completion status (unsupported request)
                    comp_st = 3'b001;
                    low_addr = '0;
                    dw_cnt = 1;
                    ret.error = 1'b1;
                end

                ret.hdr = {req_id, tag, 1'b0, low_addr, 16'h0, comp_st, 1'b0, byte_cnt[12-1 : 0], 8'b01001010, 1'b0, tc, 1'b0, attr[2], 4'b0000, attr[2-1 : 0], addr_type, dw_cnt[10-1 : 0]};

            end else begin
                // Low address computation
                low_addr          = {hdr[7-1 : 2], sv_dma_bus_pack::encode_fbe(meta[39-1 : 35])};
                addr_type         = hdr[2-1 : 0];
                dw_cnt            = hdr[75-1 : 64];
                req_id            = hdr[96-1 : 80];
                tag               = hdr[104-1 : 96];
                func_id           = hdr[112-1 : 104];
                tc                = hdr[124-1 : 121];
                attr              = hdr[127-1 : 124];
                req_type[4-1 : 0] = hdr[79-1 : 75];

                rw = uvm_pcie_hdr::encode_type(req_type, IS_INTEL_DEV);

                // Byte count computation
                if (dw_cnt == 1)
                    casex (meta[39-1 : 35])
                        4'b1xx1 : byte_cnt = 4;
                        4'b01x1 : byte_cnt = 3;
                        4'b1x10 : byte_cnt = 3;
                        4'b0011 : byte_cnt = 2;
                        4'b0110 : byte_cnt = 2;
                        4'b1100 : byte_cnt = 2;
                        4'b0001 : byte_cnt = 1;
                        4'b0010 : byte_cnt = 1;
                        4'b0100 : byte_cnt = 1;
                        4'b1000 : byte_cnt = 1;
                        4'b0000 : byte_cnt = 1;
                    endcase
                else
                    byte_cnt = int'(hdr[75-1 : 64] * 4) - int'(sv_dma_bus_pack::encode_fbe(meta[39-1 : 35])) - int'(sv_dma_bus_pack::encode_lbe(meta[43-1 : 39]));

                if (rw == 3'b100) begin
                    // completion status (unsupported request)
                    comp_st = 3'b001;
                    low_addr = '0;
                    dw_cnt = 0;
                    ret.error = 1'b1;
                end

                                                                                                            // 32-1 : 0
                ret.hdr = {1'b0, attr, tc, 1'b0, bus_num, func_id, tag , req_id, 1'b0, 1'b0, comp_st, dw_cnt, 2'b00, 1'b0, byte_cnt, 6'b000000, addr_type, 1'b0, low_addr};

                tph_st_tag  = meta[54-1 : 46];
                tph_type    = meta[46-1 : 44];
                tph_present = meta[44-1 : 43];
                fbe         = meta[39-1 : 35];
                lbe         = meta[43-1 : 39];

                ret.meta = {8'b00000000, tph_st_tag, 5'b00000, tph_type, tph_present, lbe, fbe};
            end
            ret.tag = tag;
            return ret;
    endfunction
    task run_phase(uvm_phase phase);
        uvm_common::model_item #(uvm_mi::sequence_item_response #(MI_DATA_WIDTH))                         mi_cc_tr;
        uvm_common::model_item #(uvm_mtc::cc_mtc_item#(MFB_ITEM_WIDTH))                                   cc_tr;
        uvm_common::model_item #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH))                  cc_data_tr;
        uvm_common::model_item #(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CC_META_WIDTH)) cc_meta_tr;

        logic [MFB_ITEM_WIDTH-1 : 0] data_fifo[$];
        logic [11-1 : 0]             dw_cnt;
        pcie                         pcie_meta;
        int                          item = 0;
        string                       msg  = "\n";

        logic[sv_pcie_meta_pack::PCIE_META_REQ_HDR_W-1 : 0] hdr;
        logic[(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH-sv_pcie_meta_pack::PCIE_META_REQ_HDR_W)-1 : 0] meta;

        forever begin

            fork
                hdr_catch();
            join

            if (hdrs.size() != 0 && metas.size() != 0) begin
                hdr  = hdrs.pop_front();
                meta = metas.pop_front();
                pcie_meta = gen_meta(hdr, meta);

                cc_tr           = uvm_common::model_item #(uvm_mtc::cc_mtc_item#(MFB_ITEM_WIDTH))::type_id::create("cc_tr");
                cc_tr.item      = new();
                cc_data_tr      = uvm_common::model_item #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH))::type_id::create("cc_data_tr");
                cc_data_tr.item = uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)::type_id::create("cc_data_tr_item");
                cc_meta_tr      = uvm_common::model_item #(uvm_logic_vector::sequence_item #(sv_pcie_meta_pack::PCIE_CC_META_WIDTH))::type_id::create("cc_meta_tr");
                cc_meta_tr.item = uvm_logic_vector::sequence_item #(sv_pcie_meta_pack::PCIE_CC_META_WIDTH)::type_id::create("cc_meta_tr_item");

                cc_meta_tr.item.data = '0;

                if (IS_INTEL_DEV) begin
                    dw_cnt = pcie_meta.hdr[10-1 : 0];
                end else
                    dw_cnt = pcie_meta.hdr[43-1 : 32];

                if (!pcie_meta.error) begin
                    while (item != int'(dw_cnt)) begin
                        analysis_imp_cc_mi.get(mi_cc_tr);
                        if (mi_cc_tr.item.drdy == 1'b1) begin
                            data_fifo.push_back(mi_cc_tr.item.drd);
                            item++;
                        end
                    end
                end

                if (!IS_MFB_META_DEV) begin
                    if (pcie_meta.error && IS_XILINX_DEV) begin
                        data_fifo.push_front('0);
                        data_fifo.push_front('0);
                        data_fifo.push_front('0);
                        data_fifo.push_front('0);
                        data_fifo.push_front(pcie_meta.meta[1*32-1 : 0*32]);
                    end
                    data_fifo.push_front(pcie_meta.hdr[3*32-1 : 2*32]);
                    data_fifo.push_front(pcie_meta.hdr[2*32-1 : 1*32]);
                    data_fifo.push_front(pcie_meta.hdr[1*32-1 : 0*32]);
                end else begin
                    if (pcie_meta.error) begin
                        data_fifo.push_front('0);
                        cc_meta_tr.item.data[sv_pcie_meta_pack::PCIE_CC_META_WIDTH-1 : sv_pcie_meta_pack::PCIE_META_CPL_HDR_W] = pcie_meta.meta;
                    end
                end

                cc_meta_tr.item.data[sv_pcie_meta_pack::PCIE_META_CPL_HDR_W-1 : 0] = pcie_meta.hdr;

                cc_data_tr.item.data = data_fifo;
                data_fifo.delete();
                item = 0;
                pkt_cnt++;
                cc_tr.item.data_tr = cc_data_tr.item;
                cc_tr.item.tag     = pcie_meta.tag;
                cc_tr.item.error   = pcie_meta.error;
                analysis_port_cc.write(cc_tr);
                analysis_port_cc_meta.write(cc_meta_tr);
                $swrite(msg, "%s\t Model CC MFB         %s\n", msg, cc_data_tr.convert2string());
                $swrite(msg, "%s\t Model CC META32      %h\n", msg, cc_meta_tr.item.data[32-1 : 0]);
                $swrite(msg, "%s\t Model CC META64      %h\n", msg, cc_meta_tr.item.data[64-1 : 32]);
                $swrite(msg, "%s\t Model CC META96      %h\n", msg, cc_meta_tr.item.data[96-1 : 64]);
                $swrite(msg, "%s\t Model CC META128     %h\n", msg, pcie_meta.meta[1*32-1 : 0*32]);
                $swrite(msg, "%s\t Model CC TAG         %d\n", msg, pcie_meta.hdr[80-1 : 72]);
                $swrite(msg, "%s\t Model CC LOW ADDR    %h\n", msg, pcie_meta.hdr[7-1 : 0]);
                $swrite(msg, "%s\t Model CC GLOBAL ADDR %h\n", msg, hdr[7-1 : 2]);
                $swrite(msg, "%s\t Model CC FBE         %b\n", msg, meta[39-1 : 35]);
                $swrite(msg, "%s\t Model CC LBE         %b\n", msg, meta[43-1 : 39]);
                $swrite(msg, "%s\t Model CC ENCODE FBE  %h\n", msg, sv_dma_bus_pack::encode_fbe(meta[39-1 : 35]));
                $swrite(msg, "%s\t Model CC ENCODE LBE  %h\n", msg, sv_dma_bus_pack::encode_lbe(meta[43-1 : 39]));
                `uvm_info(this.get_full_name(), msg ,UVM_MEDIUM);
            end

        end
    endtask

endclass
