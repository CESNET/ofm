//-- driver.sv
//-- Copyright (C) 2023 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause


class driver#(MFB_ITEM_WIDTH, DEVICE, ENDPOINT_TYPE) extends uvm_component;
    `uvm_component_param_utils(uvm_pcie_cq::driver#(MFB_ITEM_WIDTH, DEVICE, ENDPOINT_TYPE))

    uvm_seq_item_pull_port #(uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH), uvm_logic_vector_array::sequence_item#(MFB_ITEM_WIDTH)) seq_item_port_pcie_data;
    uvm_seq_item_pull_port #(uvm_pcie_hdr::sequence_item, uvm_pcie_hdr::sequence_item)                                                       seq_item_port_pcie_hdr;

    mailbox#(uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)) logic_vector_export;
    mailbox#(uvm_logic_vector::sequence_item#(131))                                   pcie_hdr_rw_export;

    uvm_pcie_hdr::sequence_item                                             cq_header_req;
    uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH) cq_pcie_hdr;
    uvm_logic_vector::sequence_item#(131)                                   pcie_hdr_rw;
    uvm_pcie_hdr::sync_tag tag_sync;
    int tr_cnt = 0;
    int mi_cnt = 0;

    localparam IS_INTEL_DEV    = (DEVICE == "STRATIX10" || DEVICE == "AGILEX");
    localparam IS_MFB_META_DEV = (ENDPOINT_TYPE == "P_TILE" || ENDPOINT_TYPE == "R_TILE") && IS_INTEL_DEV;

    // ------------------------------------------------------------------------
    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);

        seq_item_port_pcie_data = new("seq_item_port_pcie_data", this);
        seq_item_port_pcie_hdr  = new("seq_item_port_pcie_hdr", this);

        logic_vector_export       = new(1);
        pcie_hdr_rw_export       = new(1);
    endfunction

    typedef struct {
        logic[sv_pcie_meta_pack::PCIE_META_REQ_HDR_W-1 : 0]                                       hdr;
        logic[sv_pcie_meta_pack::PCIE_CQ_META_WIDTH-sv_pcie_meta_pack::PCIE_META_REQ_HDR_W-1 : 0] meta;
    } pcie;

    // Function that generate PCIe HDR and metadata for MFB bus
    function pcie gen_meta(uvm_pcie_hdr::sequence_item cq_header_req);
            pcie ret;
            ret.hdr  = '0;
            ret.meta = '0;
            if(IS_INTEL_DEV) begin
                // Intel HDR:
                // DW count
                ret.hdr[10-1 : 0]   = cq_header_req.dw_count;
                // ADDR TYPE
                ret.hdr[12-1 : 10]  = cq_header_req.addr[2-1 : 0];
                // ATTR[1 : 0] - {No Snoop, Relax}
                ret.hdr[14-1 : 12] = cq_header_req.attr[1 : 0];
                // {EP, TD, TH, LN}
                ret.hdr[18-1 : 14] = '0;
                // ATTR[2] - ID-Based Ordering
                ret.hdr[19-1 : 18] = cq_header_req.attr[2];
                // TAG 8
                ret.hdr[20-1 : 19] = '0;
                // TC
                ret.hdr[23-1 : 20] = cq_header_req.tc;
                // TAG 9
                ret.hdr[24-1 : 23] = '0;
                // TYPE
                ret.hdr[32-1 : 24] = cq_header_req.req_type;
                // FBE
                ret.hdr[36-1 : 32] = cq_header_req.fbe;
                // LBE
                ret.hdr[40-1 : 36] = cq_header_req.lbe;
                // TAG
                ret.hdr[48-1 : 40] = cq_header_req.tag;
                // REQ ID
                ret.hdr[64-1 : 48] = cq_header_req.req_id;
                if (|cq_header_req.addr[64-1 : 32]) begin
                    ret.hdr[128-1 : 64] = {cq_header_req.addr[32-1 : 2], cq_header_req.addr[2-1 : 0], cq_header_req.addr[64-1 : 32]};
                end else
                    ret.hdr[128-1 : 64] = {32'h0000, cq_header_req.addr[2-1 : 0], cq_header_req.addr[32-1 : 2]};
                // TLP PREFIX
                ret.meta[32-1 : 0]  = 6'd26;
                // BAR
                ret.meta[35-1 : 32] = cq_header_req.bar;
            end else begin
                // ADDR TYPE
                ret.hdr[1 : 0]     = cq_header_req.addr[2-1 : 0];
                // ADDRESS
                ret.hdr[63 : 2]    = cq_header_req.addr[64-1 : 2];
                // DW count
                ret.hdr[74 : 64]   = cq_header_req.dw_count;
                // REQ TYPE
                ret.hdr[78 : 75]   = cq_header_req.req_type[4-1 : 0];
                // REQ ID
                ret.hdr[95 : 80]   = cq_header_req.req_id;
                // TAG (Solve tag generation for read requests)
                ret.hdr[103 : 96]  = cq_header_req.tag;
                // Target Function
                ret.hdr[111 : 104] = cq_header_req.t_func;
                // BAR ID, TODO: Use more BARs (Now one is used)
                ret.hdr[114 : 112] = cq_header_req.bar;
                // BAR Aperure
                ret.hdr[120 : 115] = cq_header_req.bar_ap;
                // TC
                ret.hdr[123 : 121] = cq_header_req.tc;
                // ATTR
                ret.hdr[126 : 124] = cq_header_req.attr;
                // FBE
                ret.meta[39-1 : 35] = cq_header_req.fbe;
                // LBE
                ret.meta[43-1 : 39] = cq_header_req.lbe;
                // TPH_PRESENT
                ret.meta[44-1 : 43] = cq_header_req.tph_present;
                // TPH TYPE
                ret.meta[46-1 : 44] = cq_header_req.tph_type;
                // TPH_ST_TAG
                ret.meta[54-1 : 46] = cq_header_req.tph_st_tag;
            end
            return ret;
    endfunction

    // ------------------------------------------------------------------------
    // Starts driving signals to interface
    task run_phase(uvm_phase phase);
        tag_sync.fill_array();

        forever begin
            string          msg = "";
            pcie            pcie_tr;
            uvm_pcie_hdr::msg_type rw;
            seq_item_port_pcie_hdr.get_next_item(cq_header_req);

            cq_pcie_hdr            = uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)::type_id::create("cq_pcie_hdr");
            pcie_hdr_rw            = uvm_logic_vector::sequence_item#(131)::type_id::create("pcie_hdr_rw");

            cq_pcie_hdr.data       = '0;

            rw = uvm_pcie_hdr::encode_type(cq_header_req.req_type, IS_INTEL_DEV);

            if (rw == uvm_pcie_hdr::TYPE_READ || rw == uvm_pcie_hdr::TYPE_ERR) begin
                while (!(tag_sync.list_of_tags.exists(cq_header_req.tag))) begin
                    #(10ns*$urandom_range(1, 100));
                end

                tag_sync.remove_element(cq_header_req.tag);
            end

            pcie_tr = gen_meta(cq_header_req);

            if (IS_MFB_META_DEV) begin
                // Add PCIe HDR to metadata
                cq_pcie_hdr.data[sv_pcie_meta_pack::PCIE_META_REQ_HDR_W-1 : 0] = pcie_tr.hdr;
            end
            cq_pcie_hdr.data[sv_pcie_meta_pack::PCIE_CQ_META_WIDTH-1 : sv_pcie_meta_pack::PCIE_META_REQ_HDR_W] = pcie_tr.meta;

            pcie_hdr_rw.data[128-1 : 0] = pcie_tr.hdr;
            pcie_hdr_rw.data[131-1 : 128] = rw;
            tr_cnt++;

            $swrite(msg, "\n\t =============== Driver CQ META =============== \n");
            $swrite(msg, "%s\nTransaction number: %0d\n", msg, tr_cnt);
            $swrite(msg, "%s\nDriver CQ Request Meta %s\n", msg, cq_pcie_hdr.convert2string());
            `uvm_info(this.get_full_name(), msg, UVM_FULL)

            pcie_hdr_rw_export.put(pcie_hdr_rw);
            logic_vector_export.put(cq_pcie_hdr);

            seq_item_port_pcie_hdr.item_done();
        end
    endtask

endclass

