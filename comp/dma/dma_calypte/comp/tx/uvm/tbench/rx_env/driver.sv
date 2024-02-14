//-- driver.sv
//-- Copyright (C) 2024 CESNET z. s. p. o.
//-- Author(s):Radek Iša <isa@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause


class driver_data;
    logic [16-1 : 0] hdr_addr;
    logic [16-1 : 0] hdr_mask;

    logic [16-1 : 0] data_addr;
    logic [16-1 : 0] data_mask;

    function new();
        hdr_addr  = 0;
        data_addr = 0;
    endfunction
endclass


class status_cbs extends uvm_reg_cbs;
    driver_data data;

    function new(driver_data data);
        this.data = data;
    endfunction

    virtual task pre_write(uvm_reg_item rw);
        if(rw.value[0][0] == 1'b1) begin
            data.hdr_addr  = 0;
            data.data_addr = 0;
        end
    endtask
endclass



class driver_sync#(META_WIDTH, ITEM_WIDTH);

    local semaphore sem;
    //local uvm_logic_vector::sequence_item#(META_WIDTH)       pcie_meta[$];
    //local uvm_logic_vector_array::sequence_item#(ITEM_WIDTH) pcie_data[$];
    mailbox#(uvm_logic_vector::sequence_item#(META_WIDTH))       pcie_meta;
    mailbox#(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)) pcie_data;

    function new();
        sem = new(1);
        pcie_meta = new(0);
        pcie_data = new(0);
    endfunction

    task put(int unsigned id, uvm_logic_vector::sequence_item#(META_WIDTH) meta, uvm_logic_vector_array::sequence_item#(ITEM_WIDTH) data);
        //wait(pcie_meta.size() != 0 || pcie_data.size() != 0);
        wait(pcie_meta.num() == 0 || pcie_data.num() == 0);

        sem.get(1);
        //pcie_meta.push_back(meta);
        //pcie_data.push_back(data);
        pcie_meta.put(meta);
        pcie_data.put(data);
        sem.put(1);
    endtask

    //task get_meta(output uvm_logic_vector_array::sequence_item#(ITEM_WIDTH) meta);
    //    wait(pcie_meta.size() != 0);
    //    meta = pcie_meta.pop_back();
    //endtask

    //task get_data(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH) data);
    //    wait(pcie_data.size() != 0);
    //    data = pcie_data.pop_back();
    //endtask
endclass


class driver#(CHANNELS, PKT_SIZE_MAX, ITEM_WIDTH, DATA_ADDR_W, DEVICE) extends uvm_driver#(sequence_item#(ITEM_WIDTH, sv_pcie_meta_pack::PCIE_CQ_META_WIDTH));
    `uvm_component_param_utils(uvm_dma_ll_rx::driver#(CHANNELS, PKT_SIZE_MAX, ITEM_WIDTH, DATA_ADDR_W, DEVICE))

    localparam PCIE_HDR_SIZE = 128;
    localparam DMA_HDR_SIZE  = 64;
    localparam PACKET_ALIGNMENT = 32;


    driver_sync#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH, ITEM_WIDTH) data_export;

    local uvm_dma_regs::reg_channel m_regmodel;
    local driver_data               ptr;
    int unsigned channel;

    typedef struct{
        uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)                      data;
        uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH) meta;
    } pcie_info;


    // ------------------------------------------------------------------------
    // Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task ptr_read(uvm_reg register, output logic [16-1:0] ptr);
        uvm_status_e   status;
        uvm_reg_data_t data;
        register.read(status, data);
        ptr = data;
    endtask

    task ptr_write(uvm_reg register, logic [16-1:0] ptr);
        uvm_status_e   status;
        uvm_reg_data_t data;

        data = ptr;
        register.write(status, data);
    endtask


    function void regmodel_set(uvm_dma_regs::reg_channel m_regmodel);
        status_cbs cbs;

        this.ptr = new();
        cbs = new(this.ptr);
        this.m_regmodel = m_regmodel;

        uvm_reg_field_cb::add(this.m_regmodel.control.dma_enable, cbs);
    endfunction

    function pcie_info create_pcie_req(logic [64-1 : 0] pcie_addr, logic [11-1 : 0] pcie_len, logic [4-1:0] fbe, logic [4-1:0] lbe, logic[ITEM_WIDTH-1:0] data[]);
        pcie_info ret;
        logic [PCIE_HDR_SIZE-1:0] pcie_hdr;

        ret.data      = uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)::type_id::create("pcie_tr.data");
        ret.meta      = uvm_logic_vector::sequence_item#(sv_pcie_meta_pack::PCIE_CQ_META_WIDTH)::type_id::create("pcie_tr.meta");

        pcie_hdr = '0;
        if (DEVICE == "ULTRASCALE") begin
            pcie_hdr[63 : 2]    = pcie_addr[63 : 2];
            pcie_hdr[74 : 64]   = pcie_len;
            pcie_hdr[78 : 75]   = 4'b0001; // REQ TYPE = WRITE
            pcie_hdr[114 : 112] = 3'b010; // BAR ID
            pcie_hdr[120 : 115] = 6'd26; // BAR Aperure
            ret.data.data = {pcie_hdr[31 : 0], pcie_hdr[63 : 32], pcie_hdr[95 : 64], pcie_hdr[127 : 96], data};

            ret.meta.data = '0;
            ret.meta.data[166 : 163] = fbe;
            ret.meta.data[170 : 167] = lbe;
        end else begin // Intel P/R-Tile
            logic is_4dw_tlp;

            if (pcie_addr[63 : 32] == 0) begin
                is_4dw_tlp = '0;
            end else begin
                is_4dw_tlp = '1;
            end

            pcie_hdr = '0;
            pcie_hdr[9 : 0]   = pcie_len[9 : 0];
            pcie_hdr[31 : 24] = 8'b01000000;
            pcie_hdr[29]      = is_4dw_tlp;
            pcie_hdr[35 : 32] = fbe;
            pcie_hdr[39 : 36] = lbe;
            if (is_4dw_tlp == 1) begin
                pcie_hdr[95 : 64]  = pcie_addr[63 : 32];
                pcie_hdr[127 : 98] = pcie_addr[31 : 2];
            end else begin
                pcie_hdr[95 : 66] = pcie_addr[31 : 2];
            end

            ret.data.data = data;

            ret.meta.data = '0;
            ret.meta.data[127 : 0]   = pcie_hdr;
            ret.meta.data[162 : 160] = 3'b010; // BAR ID
        end

        return ret;
    endfunction


    task send_data();
        pcie_info pcie_transaction;
        int unsigned data_index;
        int unsigned pcie_len;
        int unsigned free_space;
        logic [ITEM_WIDTH-1 : 0]  data[];

        logic [4-1:0]             fbe;
        logic [4-1:0]             lbe;

        logic [16-1 : 0] hw_ptr;

        data_index = 0;
        //////////////////////////////////
        // DATA SEND

        while (data_index < req.packet.size()) begin
            logic [64-1 : 0] pcie_addr;

            //GENERATE RANDOM SIZE OF BLOCKS
            pcie_len = 256; //$urandom_range(256, 1);
            //if (pcie_len == 1) begin
            //    prev_lbe = pkt_be.lbe & pkt_be.fbe;
            //end else begin
            //    prev_lbe = pkt_be.lbe;
            //end

            if (req.packet.size() < (data_index + pcie_len)) begin
                pcie_len = (req.packet.size() - data_index);
            end


            data = new[pcie_len];
            for (int unsigned it = 0; it < pcie_len; it++) begin
                data[it] = req.packet[data_index + it];
            end
            data_index += pcie_len;

            fbe = '1;
            lbe = '1;

            pcie_addr = '0;
            pcie_addr[DATA_ADDR_W-1 : 0] = ptr.data_addr;
            pcie_addr[(DATA_ADDR_W+1+$clog2(CHANNELS))-1 : DATA_ADDR_W+1] = channel;
            pcie_addr[(DATA_ADDR_W+$clog2(CHANNELS)+1)] = 1'b0;
            pcie_transaction = create_pcie_req(pcie_addr, pcie_len, fbe, lbe, data);

            //free space
            ptr_read(m_regmodel.hw_data_pointer, hw_ptr);
            free_space = (hw_ptr-1 - ptr.data_addr) & ptr.data_mask;
            while(free_space < pcie_len*(ITEM_WIDTH/8)) begin
                #(200ns)
                ptr_read(m_regmodel.hw_data_pointer, hw_ptr);
                free_space = (hw_ptr-1 - ptr.data_addr) & ptr.data_mask;
            end

            //free space
            ptr.data_addr += pcie_len*(ITEM_WIDTH/8);
            ptr.data_addr &= ptr.data_mask;

            //SEND DATA
            data_export.put(channel, pcie_transaction.meta, pcie_transaction.data);
        end

        //actualize sdp_pointer
        ptr_write(m_regmodel.sw_data_pointer, ptr.data_addr);
    endtask

    task send_header(logic [16-1:0] packet_ptr);
        pcie_info pcie_transaction;
        int unsigned              free_space;
        int unsigned              pcie_len;
        logic [4-1:0]             fbe;
        logic [4-1:0]             lbe;
        logic [16-1 : 0]          hw_ptr;
        logic [DMA_HDR_SIZE-1:0]  dma_hdr;
        logic [64-1 : 0]          pcie_addr;

        //////////////////////////////////
        // DMA HEADER
        fbe                   = '1;
        lbe                   = '1;
        pcie_len              = 2;

        // DMA HDR Filling
        dma_hdr[15 : 0]  = req.packet.size()*4;
        dma_hdr[31 : 16] = packet_ptr;
        dma_hdr[39 : 32] = '0;
        dma_hdr[63 : 40] = req.meta;

        pcie_addr = '0;
        pcie_addr[DATA_ADDR_W-1 : 0] = ptr.hdr_addr*2*(ITEM_WIDTH/8);
        pcie_addr[(DATA_ADDR_W+1+$clog2(CHANNELS))-1 : DATA_ADDR_W+1] = channel;
        pcie_addr[(DATA_ADDR_W+$clog2(CHANNELS)+1)] = 1'b1;
        pcie_transaction = create_pcie_req(pcie_addr, pcie_len, fbe, lbe, {dma_hdr[31 : 0], dma_hdr[63 : 32]});

        ptr_read(m_regmodel.hw_hdr_pointer, hw_ptr);
        free_space = (hw_ptr-1 - ptr.hdr_addr) & ptr.hdr_mask;
        while(free_space  == 0) begin
            #(200ns)
            ptr_read(m_regmodel.hw_hdr_pointer, hw_ptr);
            free_space = (hw_ptr-1 - ptr.hdr_addr) & ptr.hdr_mask;
        end

        //move hdr pointer
        ptr.hdr_addr += 1;
        ptr.hdr_addr &= ptr.hdr_mask;

        //SEND DATA
        data_export.put(channel, pcie_transaction.meta, pcie_transaction.data);
        //actualize sdp_pointer
        ptr_write(m_regmodel.sw_hdr_pointer, ptr.hdr_addr);
    endtask


    task run_phase(uvm_phase phase);
        forever begin
            logic [16-1:0] packet_ptr;
            seq_item_port.get_next_item(req);

            ptr_read(m_regmodel.data_mask, ptr.data_mask);
            ptr_read(m_regmodel.hdr_mask , ptr.hdr_mask);
            //align start of packet to PACKET_ALIGMENT
            if ((ptr.data_addr % PACKET_ALIGNMENT) != 0) begin
                ptr.data_addr += (PACKET_ALIGNMENT-(ptr.data_addr % PACKET_ALIGNMENT));
                ptr.data_addr %= ptr.data_mask;
            end
            packet_ptr = ptr.data_addr;

            send_data();
            send_header(packet_ptr);
            seq_item_port.item_done();
        end
    endtask
endclass

