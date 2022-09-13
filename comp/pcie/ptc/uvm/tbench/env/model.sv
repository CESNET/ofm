//-- model.sv: Model of implementation
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kříž  <xkrizd01@vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

class model #(META_WIDTH, MFB_DOWN_REGIONS, MFB_UP_REGIONS, DMA_PORTS, DMA_MVB_UP_ITEMS, PCIE_UPHDR_WIDTH, PCIE_DOWNHDR_WIDTH, PCIE_PREFIX_WIDTH, ENDPOINT_TYPE) extends uvm_component;
    `uvm_component_param_utils(uvm_ptc::model#(META_WIDTH, MFB_DOWN_REGIONS, MFB_UP_REGIONS, DMA_PORTS, DMA_MVB_UP_ITEMS, PCIE_UPHDR_WIDTH, PCIE_DOWNHDR_WIDTH, PCIE_PREFIX_WIDTH, ENDPOINT_TYPE))
    
    // Model inputs
    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item #(32))                         model_up_mfb_in[DMA_PORTS];
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(sv_dma_bus_pack::DMA_UPHDR_WIDTH)) model_up_mvb_in[DMA_PORTS];

    // Model outputs
    uvm_analysis_port #(uvm_logic_vector_array::sequence_item #(32))         model_up_mfb_out;
    uvm_analysis_port #(uvm_logic_vector::sequence_item #(PCIE_UPHDR_WIDTH)) model_up_mvb_out;

    int unsigned tag_cnt = 0;

    function new(string name = "model", uvm_component parent = null);
        super.new(name, parent);

        for (int unsigned it = 0; it < DMA_PORTS; it++) begin
            string str_it;

            str_it.itoa(it);
            model_up_mfb_in[it]    = new({"model_up_mfb_in_",       str_it}, this);
            model_up_mvb_in[it]    = new({"model_up_mvb_in_",       str_it}, this);
        end
        model_up_mfb_out    = new("model_up_mfb_out", this);
        model_up_mvb_out    = new("model_up_mvb_out", this);
    endfunction

    typedef struct packed {
        logic [sv_dma_bus_pack::DMA_REQUEST_RELAXED_W-1 : 0]  relaxed;
        logic [sv_dma_bus_pack::DMA_REQUEST_PASIDVLD_W-1 : 0] pasidvld;
        logic [sv_dma_bus_pack::DMA_REQUEST_PASID_W-1 : 0]    pasid;
        logic [sv_dma_bus_pack::DMA_REQUEST_VFID_W-1 : 0]     vfid;
        logic [sv_dma_bus_pack::DMA_REQUEST_GLOBAL_W-1 : 0]   global_id;
        logic [sv_dma_bus_pack::DMA_REQUEST_UNITID_W-1 : 0]   unitid;
        logic [sv_dma_bus_pack::DMA_REQUEST_TAG_W-1 : 0]      tag;
        logic [sv_dma_bus_pack::DMA_REQUEST_LASTIB_W-1 : 0]   lastib;
        logic [sv_dma_bus_pack::DMA_REQUEST_FIRSTIB_W-1 : 0]  firstib;
        logic [sv_dma_bus_pack::DMA_REQUEST_TYPE_W-1 : 0]     read_write; // For read '0', for write '1'
        logic [sv_dma_bus_pack::DMA_REQUEST_LENGTH_W-1 : 0]   packet_size; // LSB
    } dma_header_rq;

    typedef struct packed {
        logic [sv_dma_bus_pack::DMA_REQUEST_GLOBAL_W-1 : 0]    global_id;
        // Padding                            "00"
        logic [2-1 : 0]                       padd_1;
        logic [(sv_dma_bus_pack::DMA_REQUEST_TAG_W + 8)-1 : 0] req_id; // requester ID |vfid|"00000000"(MSB)|
        logic [sv_dma_bus_pack::DMA_REQUEST_TAG_W-1 : 0]       tag; // tag
        logic [4-1 : 0]                       lastbe; // last byte enable
        logic [4-1 : 0]                       firstbe; // first byte enable
        logic [3-1 : 0]                       fmt; // Request type |0|read_write|hdr_type ('1' for 4DWORD '0' for 3DWORD)
        logic [5-1 : 0]                       type_n;
        logic [1-1 : 0]                       tag_9;

        logic [3-1 : 0]                       tc; // Traffic Class
        logic [1-1 : 0]                       tag_8;
        // Padding                            "0000"
        logic [3-1 : 0]                       padd_0;
        logic [1-1 : 0]                       td; // ECRC
        logic [1-1 : 0]                       ep; // Poisoned request
        logic [sv_dma_bus_pack::DMA_REQUEST_RELAXED_W-1 : 0]   relaxed; // Relaxed bit
        logic [1-1 : 0]                       snoop; // Snoop bit
        logic [2-1 : 0]                       at;
        logic [10-1 : 0]                      len; // LSB (Paket size in DWORD)
    } pcie_header_rq;

    task parse(int index);

        logic [4-1 : 0] fbe;
        logic [4-1 : 0] lbe;
        logic [8-1 : 0] be;
        logic [1-1 : 0] hdr_type;
        // DMA HEADER
        dma_header_rq header_rq;
        // PCIE HEADER
        pcie_header_rq pcie_header_out;
        string msg = "";

        uvm_logic_vector_array::sequence_item #(32)                         tr_up_mfb_in;
        uvm_logic_vector::sequence_item #(sv_dma_bus_pack::DMA_UPHDR_WIDTH) tr_up_mvb_in;

        uvm_logic_vector_array::sequence_item #(32)           tr_up_mfb_out;
        uvm_logic_vector::sequence_item #(PCIE_UPHDR_WIDTH)   tr_up_mvb_out;

        model_up_mvb_in[index].get(tr_up_mvb_in);

        if (tr_up_mvb_in.data[sv_dma_bus_pack::DMA_REQUEST_FIRSTIB_O-1 : sv_dma_bus_pack::DMA_REQUEST_TYPE_O] == 1'b1) begin
            model_up_mfb_in[index].get(tr_up_mfb_in);
            if (tr_up_mfb_in.size() != tr_up_mvb_in.data[sv_dma_bus_pack::DMA_REQUEST_TYPE_O-1 : sv_dma_bus_pack::DMA_REQUEST_LENGTH_O]) begin
                $swrite(msg, "%s\n\tDATA SIZE: %d META SIZE: %d", msg, tr_up_mfb_in.size(), tr_up_mvb_in.data[sv_dma_bus_pack::DMA_REQUEST_TYPE_O-1 : sv_dma_bus_pack::DMA_REQUEST_LENGTH_O]);
                `uvm_fatal(this.get_full_name(), msg);
            end
        end

        tr_up_mfb_out = uvm_logic_vector_array::sequence_item #(32)::type_id::create("tr_up_mfb_out");
        tr_up_mvb_out = uvm_logic_vector::sequence_item #(PCIE_UPHDR_WIDTH)::type_id::create("tr_up_mvb_out");

        header_rq.relaxed     = tr_up_mvb_in.data[sv_dma_bus_pack::DMA_REQUEST_W-1 : sv_dma_bus_pack::DMA_REQUEST_RELAXED_O];
        header_rq.pasidvld    = tr_up_mvb_in.data[sv_dma_bus_pack::DMA_REQUEST_PASIDVLD_O];
        header_rq.pasid       = tr_up_mvb_in.data[sv_dma_bus_pack::DMA_REQUEST_PASID_O];
        header_rq.vfid        = tr_up_mvb_in.data[sv_dma_bus_pack::DMA_REQUEST_PASID_O-1 : sv_dma_bus_pack::DMA_REQUEST_VFID_O];
        header_rq.global_id   = tr_up_mvb_in.data[sv_dma_bus_pack::DMA_REQUEST_VFID_O-1 : sv_dma_bus_pack::DMA_REQUEST_GLOBAL_O];
        header_rq.unitid      = tr_up_mvb_in.data[sv_dma_bus_pack::DMA_REQUEST_GLOBAL_O-1 : sv_dma_bus_pack::DMA_REQUEST_UNITID_O];
        header_rq.tag         = tr_up_mvb_in.data[sv_dma_bus_pack::DMA_REQUEST_UNITID_O-1 : sv_dma_bus_pack::DMA_REQUEST_TAG_O];
        header_rq.lastib      = tr_up_mvb_in.data[sv_dma_bus_pack::DMA_REQUEST_TAG_O-1 : sv_dma_bus_pack::DMA_REQUEST_LASTIB_O];
        header_rq.firstib     = tr_up_mvb_in.data[sv_dma_bus_pack::DMA_REQUEST_LASTIB_O-1 : sv_dma_bus_pack::DMA_REQUEST_FIRSTIB_O];
        header_rq.read_write  = tr_up_mvb_in.data[sv_dma_bus_pack::DMA_REQUEST_FIRSTIB_O-1 : sv_dma_bus_pack::DMA_REQUEST_TYPE_O];
        header_rq.packet_size = tr_up_mvb_in.data[sv_dma_bus_pack::DMA_REQUEST_TYPE_O-1 : sv_dma_bus_pack::DMA_REQUEST_LENGTH_O]; // Size in DWORDS

        fbe = sv_dma_bus_pack::decode_fbe(header_rq.firstib);
        lbe = sv_dma_bus_pack::decode_lbe(header_rq.lastib);


        if (header_rq.packet_size == 0)
            be = '0;
        else if (header_rq.packet_size == 1)
            be = {4'h0, (fbe & lbe)};
        else
            be = {lbe, fbe};
        pcie_header_out.len     = header_rq.packet_size[10-1 : 0];
        pcie_header_out.at      = '0;
        pcie_header_out.relaxed = header_rq.relaxed;
        // no snoop
        pcie_header_out.snoop  = '0;
        // EP
        pcie_header_out.ep     = '0;
        // TD
        pcie_header_out.td     = '0;
        // Padding "000"
        pcie_header_out.padd_0 = '0;
        pcie_header_out.tag_8  = (sv_dma_bus_pack::DMA_COMPLETION_TAG_W == 9);
        // TC
        pcie_header_out.tc    = '0;
        pcie_header_out.tag_9 = (sv_dma_bus_pack::DMA_COMPLETION_TAG_W == 10);
        // TYPE
        pcie_header_out.type_n = '0;
        // Upravit pro 3DW (vrchnich 32 bitu global id jsou 0) hlavičku (tam bude posledni bit 0)
        // Navodit takovy stav
        if (|header_rq.global_id[64-1 : 32]) begin
            pcie_header_out.fmt = {1'b0, header_rq.read_write, 1'b1};
        end else
            pcie_header_out.fmt = {1'b0, header_rq.read_write, 1'b0};

        pcie_header_out.firstbe = be[4-1 : 0];
        pcie_header_out.lastbe  = be[8-1 : 4];
        if (header_rq.read_write == 1'b0) begin
            pcie_header_out.tag = header_rq.tag;
        end else
            pcie_header_out.tag = '0;

        pcie_header_out.req_id = {8'h00, header_rq.vfid};
        pcie_header_out.padd_1 = '0;

        if (|header_rq.global_id[64-1 : 32]) begin
            pcie_header_out.global_id = {header_rq.global_id[32-1 : 2], pcie_header_out.padd_1, header_rq.global_id[64-1 : 32]};
        end else
            pcie_header_out.global_id = {header_rq.global_id[32-1 : 2], pcie_header_out.padd_1, 32'h0000};

        tr_up_mvb_out.data = {pcie_header_out.global_id, pcie_header_out.req_id, pcie_header_out.tag,
                                pcie_header_out.lastbe, pcie_header_out.firstbe, pcie_header_out.fmt, pcie_header_out.type_n,
                                pcie_header_out.tag_9, pcie_header_out.tc, pcie_header_out.tag_8, pcie_header_out.padd_0,
                                pcie_header_out.td, pcie_header_out.ep, pcie_header_out.relaxed, pcie_header_out.snoop,
                                pcie_header_out.at, pcie_header_out.len};

        if (tr_up_mvb_in.data[sv_dma_bus_pack::DMA_REQUEST_FIRSTIB_O-1 : sv_dma_bus_pack::DMA_REQUEST_TYPE_O] == 1'b1) begin
            if (ENDPOINT_TYPE == "H_TILE") begin
                if (header_rq.read_write == 1'b1) begin
                    tr_up_mfb_out.data = new[tr_up_mfb_in.data.size + 4];
                end else
                    tr_up_mfb_out.data = new[4];
                tr_up_mfb_out.data[0 : 4-1] = {<<32{tr_up_mvb_out.data}};
                if (header_rq.read_write == 1'b1) begin
                    for (int j = 0; j < tr_up_mfb_in.data.size; j++) begin
                        tr_up_mfb_out.data[j+4] = tr_up_mfb_in.data[j];
                    end
                end
            end else begin
                tr_up_mfb_out.data = new[tr_up_mfb_in.data.size];
                for (int j = 0; j < tr_up_mfb_in.data.size; j++) begin
                    tr_up_mfb_out.data[j] = tr_up_mfb_in.data[j];
                end
            end
        end else begin
            tr_up_mfb_out.data = new[1];
            tr_up_mfb_out.data[0] = 32'h12345678;
        end

        model_up_mvb_out.write(tr_up_mvb_out);
        model_up_mfb_out.write(tr_up_mfb_out);

    endtask

    task run_phase(uvm_phase phase);
        for (int i = 0; i < DMA_PORTS; i++) begin
            fork
                automatic int unsigned index = i;
                forever begin
                    parse(index);
                end
            join_none;
        end
    endtask
endclass


class down_model #(DMA_PORTS, PCIE_DOWNHDR_WIDTH, PCIE_PREFIX_WIDTH) extends uvm_component;
    `uvm_component_param_utils(uvm_ptc::down_model#(DMA_PORTS, PCIE_DOWNHDR_WIDTH, PCIE_PREFIX_WIDTH))
    
    // Model inputs
    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item #(32))           model_rc_mfb_in;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(PCIE_DOWNHDR_WIDTH)) model_rc_meta_in;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(PCIE_PREFIX_WIDTH))  model_rc_prefix_mvb_in;


    uvm_analysis_port #(uvm_logic_vector_array::sequence_item #(32))          model_down_mfb_out[DMA_PORTS];
    uvm_analysis_port #(uvm_logic_vector::sequence_item #(sv_dma_bus_pack::DMA_DOWNHDR_WIDTH)) model_down_mvb_out[DMA_PORTS];
    int unsigned tag_cnt = 0;

    function new(string name = "model", uvm_component parent = null);
        super.new(name, parent);

        model_rc_mfb_in         = new("model_rc_mfb_in",         this);
        model_rc_meta_in        = new("model_rc_meta_in",         this);
        model_rc_prefix_mvb_in  = new("model_rc_prefix_mvb_in",  this);

        for (int unsigned it = 0; it < DMA_PORTS; it++) begin
            string str_it;

            str_it.itoa(it);
            model_down_mfb_out[it] = new({"model_down_mfb_out_",    str_it}, this);
            model_down_mvb_out[it] = new({"model_down_mvb_out_",      str_it}, this);
        end

    endfunction

    task run_phase(uvm_phase phase);

        uvm_logic_vector_array::sequence_item #(32)           tr_rc_mfb_in;
        uvm_logic_vector::sequence_item #(PCIE_DOWNHDR_WIDTH) tr_rc_meta_in;
        //uvm_logic_vector::sequence_item #(MFB_DOWN_REGIONS) tr_rc_prefix_mvb_in;

        uvm_logic_vector_array::sequence_item #(32)           tr_down_mfb_out;
        uvm_logic_vector::sequence_item #(sv_dma_bus_pack::DMA_DOWNHDR_WIDTH)  tr_down_mvb_out;

        forever begin
            tr_down_mfb_out = uvm_logic_vector_array::sequence_item #(32)::type_id::create("tr_down_mfb_out");
            tr_down_mvb_out = uvm_logic_vector::sequence_item #(sv_dma_bus_pack::DMA_DOWNHDR_WIDTH)::type_id::create("tr_down_mvb_out");

            model_rc_mfb_in.get(tr_rc_mfb_in);
            model_rc_meta_in.get(tr_rc_meta_in);

            tr_down_mfb_out = tr_rc_mfb_in;
            tr_down_mvb_out.data = {8'b00000000, tr_rc_meta_in.data[90-1 : 82], 1'b1, tr_rc_meta_in.data[10-1 :0]};

            model_down_mfb_out[tr_rc_meta_in.data[(PCIE_DOWNHDR_WIDTH-16)]].write(tr_down_mfb_out);
            model_down_mvb_out[tr_rc_meta_in.data[(PCIE_DOWNHDR_WIDTH-16)]].write(tr_down_mvb_out);
        end
    endtask
endclass
