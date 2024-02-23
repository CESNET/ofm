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



class driver_sync#(ITEM_WIDTH, META_WIDTH);

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


class driver#(CHANNELS, PCIE_MTU, ITEM_WIDTH, DATA_ADDR_W, DEVICE) extends uvm_driver#(sequence_item);
    `uvm_component_param_utils(uvm_dma_ll_rx::driver#(CHANNELS, PCIE_MTU, ITEM_WIDTH, DATA_ADDR_W, DEVICE))

    localparam PCIE_HDR_SIZE = 128;
    localparam DMA_HDR_SIZE  = 64;
    localparam PACKET_ALIGNMENT = 32;


    driver_sync#(ITEM_WIDTH, sv_pcie_meta_pack::PCIE_CQ_META_WIDTH) data_export;

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

    function int unsigned encode_fbe(logic [4-1 : 0] be);
        int unsigned ret;
        casex (be)
            4'b0000 : ret = 0;
            4'bxxx1 : ret = 0;
            4'bxx10 : ret = 1;
            4'bx100 : ret = 2;
            4'b1000 : ret = 3;
        endcase
        return ret;
    endfunction

    function int unsigned encode_lbe(logic [4-1 : 0] be);
        int unsigned ret;
        casex (be)
            4'b0000 : ret = 4;
            4'b1xxx : ret = 4;
            4'b01xx : ret = 3;
            4'b001x : ret = 2;
            4'b0001 : ret = 1;
        endcase
        return ret;
    endfunction

    function logic[4-1 : 0] decode_lbe(logic [1 : 0] ib);
        logic[4-1 : 0] be;
        case (ib)
            2'b00 : be = 4'b1111;
            2'b01 : be = 4'b0001;
            2'b10 : be = 4'b0011;
            2'b11 : be = 4'b0111;
        endcase
        return be;
    endfunction

    function string print_data(logic [ITEM_WIDTH-1 : 0] data[]);
        string ret = $sformatf("\nData size %0d", data.size());
        for (int unsigned it = 0; it < data.size(); it++) begin
            if (it % 8 == 0) begin
                ret = {ret, $sformatf("\n\t%h", data[it])};
            end else begin
                ret = {ret, $sformatf(" %h", data[it])};
            end
        end
        return ret;
    endfunction

    function void regmodel_set(uvm_dma_regs::reg_channel m_regmodel);
        status_cbs cbs;

        this.ptr = new();
        cbs = new(this.ptr);
        this.m_regmodel = m_regmodel;

        uvm_reg_field_cb::add(this.m_regmodel.control.dma_enable, cbs);
    endfunction

    task wait_for_free_space(int unsigned space, uvm_reg hw_reg, logic[16-1:0] sw_addr, logic[16-1:0] mask);
        int unsigned   free_space;
        logic [16-1:0] hw_ptr;

        //free space
        ptr_read(hw_reg, hw_ptr);
        free_space = (hw_ptr-1 - sw_addr) & mask;
        while(free_space < space) begin
            #(200ns)
            ptr_read(hw_reg, hw_ptr);
            free_space = (hw_ptr-1 - sw_addr) & mask;
        end
    endtask

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
        pcie_info pcie_transactions[$];
        int unsigned packet_index;
        int unsigned pcie_len;
        logic [ITEM_WIDTH-1 : 0]  data[];

        logic [ITEM_WIDTH/8-1:0]  fbe;
        logic [ITEM_WIDTH/8-1:0]  lbe = '0; //fbe is negative last fbe
        logic [ITEM_WIDTH/8-1:0]  send_lbe = '0; // if pcie transaction have one dword then lbe is set to zero

        const int unsigned packet_len = (req.packet.size()+(ITEM_WIDTH/8-1))/(ITEM_WIDTH/8); //len in dwords
        int unsigned pcie_trans_cnt;
        string debug_msg;

        packet_index = 0;
        pcie_trans_cnt = 0;
        pcie_transactions.delete();
        //////////////////////////////////
        // DATA SEND

        while (packet_index < req.packet.size()) begin
            int unsigned data_index;
            logic [64-1 : 0] pcie_addr;
            string debug_msg;
            int unsigned rand_ret;

            //GENERATE RANDOM SIZE OF BLOCKS
            //pcie_len = 256; //$urandom_range(256, 1);
            //pcie_len = $urandom_range(256, 1);
            rand_ret = std::randomize(pcie_len) with {pcie_len dist {[1:63] :/ 5, [64:127] :/ 10,  [128:256] :/ 20, 256 :/ 65}; };
            if (rand_ret == 0) begin
                pcie_len = 256;
            end

            //lbe =
            fbe = (lbe == '1) ? '1 : ~lbe;
            if (packet_len <= (packet_index/(ITEM_WIDTH/8) + pcie_len)) begin
                pcie_len = packet_len - packet_index/(ITEM_WIDTH/8);
                lbe      = decode_lbe(req.packet.size() % ((ITEM_WIDTH/8)));
            end else begin
                assert(std::randomize(lbe) with {
                        if (pcie_len == 1){$countones(lbe & fbe) > 0;}
                        lbe inside {4'b1111, 4'b0111, 4'b0011, 4'b0001}; }
                    ) else `uvm_fatal(this.get_full_name(), "\n\tCannot randomize lbe");
            end

            // COPY DATA TO TEMPORALY VARIABLE
            data = new[pcie_len];
            data_index = 0;
            void'(std::randomize(data[0]));
            if (pcie_len > 1) begin
                void'(std::randomize(data[pcie_len-1]));
                //pealing FBE
                for (int unsigned jt = this.encode_fbe(fbe); jt < ITEM_WIDTH/8; jt++) begin
                    data[0][(jt+1)*8-1 -: 8] = req.packet[packet_index + data_index];
                    data_index++;
                end

                //Except first and last PCI WORD
                for (int unsigned it = 1; it < pcie_len-1; it++) begin
                    data[it] = { << 8 {req.packet[packet_index + data_index +: ITEM_WIDTH/8]}};
                    data_index += ITEM_WIDTH/8;
                end

                //pealing LBE
                for (int unsigned jt = 0; jt < this.encode_lbe(lbe); jt++) begin
                    data[pcie_len-1][(jt+1)*8-1 -: 8] = req.packet[packet_index + data_index];
                    data_index++;
                end
                send_lbe = lbe;
            end else begin
                for (int unsigned jt = this.encode_fbe(fbe); jt < this.encode_lbe(lbe); jt++) begin
                    data[0][(jt+1)*8-1 -: 8] = req.packet[packet_index + data_index];
                    data_index++;
                end
                fbe &= lbe;
                send_lbe = 0;
            end
            packet_index += data_index;

            pcie_addr = '0;
            pcie_addr[DATA_ADDR_W-1 : 0] = ptr.data_addr; // Address is in bytes
            pcie_addr[(DATA_ADDR_W+1+$clog2(CHANNELS))-1 : DATA_ADDR_W+1] = channel;
            pcie_addr[(DATA_ADDR_W+$clog2(CHANNELS)+1)] = 1'b0;
            pcie_transactions.push_back(create_pcie_req(pcie_addr, pcie_len, fbe, send_lbe, data));

            debug_msg = "\n";
            debug_msg = {debug_msg, "-----------------------------------------------\n"};
            debug_msg = {debug_msg, $sformatf("PCIe DATA TRANSACTION %0d on channel %0d\n", pcie_trans_cnt, channel)};
            debug_msg = {debug_msg, "-----------------------------------------------\n"};
            debug_msg = {debug_msg, $sformatf("\tdata_addr 0x%h(%0d)\n", ptr.data_addr, ptr.data_addr)};
            debug_msg = {debug_msg, $sformatf("\tpcie_addr 0x%h(%0d)\n", pcie_addr, pcie_addr)};
            debug_msg = {debug_msg, $sformatf("\tpcie_len  %0d dwords\n", pcie_len)};
            debug_msg = {debug_msg, $sformatf("\tfbe %h lbe %h\n", fbe, lbe)};
            debug_msg = {debug_msg, $sformatf("\tpcie_len  %0d dwords\n", pcie_len)};
            debug_msg = {debug_msg, print_data(data)};
            `uvm_info(this.get_full_name(), debug_msg, UVM_HIGH);

            //free space
            wait_for_free_space(pcie_len*(ITEM_WIDTH/8), m_regmodel.hw_data_pointer, ptr.data_addr, ptr.data_mask);

            //free space
            ptr.data_addr += data_index;
            ptr.data_addr &= ptr.data_mask;
            pcie_trans_cnt++;
        end

        //SHUFLE AND SEND DATA
        pcie_transactions.shuffle();
        for (int unsigned it = 0; it < pcie_transactions.size(); it++) begin
            data_export.put(channel, pcie_transactions[it].meta, pcie_transactions[it].data);
        end


        //Allign pointer to PACKET ALLIGMENT
        if ((ptr.data_addr % PACKET_ALIGNMENT) != 0) begin
            const int unsigned size_to_allign = (PACKET_ALIGNMENT-(ptr.data_addr % PACKET_ALIGNMENT));
            wait_for_free_space(size_to_allign, m_regmodel.hw_data_pointer, ptr.data_addr, ptr.data_mask);

            ptr.data_addr += size_to_allign;
            ptr.data_addr &= ptr.data_mask;
        end

        //actualize sdp_pointer
        ptr_write(m_regmodel.sw_data_pointer, ptr.data_addr);
    endtask

    task send_header(logic [16-1:0] packet_ptr);
        pcie_info pcie_transaction;
        int unsigned              pcie_len;
        logic [4-1:0]             fbe;
        logic [4-1:0]             lbe;
        logic [DMA_HDR_SIZE-1:0]  dma_hdr;
        logic [64-1 : 0]          pcie_addr;
        string debug_msg;

        //////////////////////////////////
        // DMA HEADER
        fbe                   = '1;
        lbe                   = '1;
        pcie_len              = 2;

        // DMA HDR Filling
        dma_hdr[15 : 0]  = req.packet.size();
        dma_hdr[31 : 16] = packet_ptr;
        dma_hdr[39 : 32] = '0;
        dma_hdr[63 : 40] = req.meta;

        pcie_addr = '0;
        pcie_addr[DATA_ADDR_W-1 : 0] = ptr.hdr_addr*2*(ITEM_WIDTH/8); //Address is in DMA headers (64B)
        pcie_addr[(DATA_ADDR_W+1+$clog2(CHANNELS))-1 : DATA_ADDR_W+1] = channel;
        pcie_addr[(DATA_ADDR_W+$clog2(CHANNELS)+1)] = 1'b1;
        pcie_transaction = create_pcie_req(pcie_addr, pcie_len, fbe, lbe, {dma_hdr[31 : 0], dma_hdr[63 : 32]});

        debug_msg = "\n";
        debug_msg = {debug_msg, "-----------------------------------------------\n"};
        debug_msg = {debug_msg, $sformatf("PCIe HEADER TRANSACTION on channel %0d\n", channel)};
        debug_msg = {debug_msg, "-----------------------------------------------\n"};
        debug_msg = {debug_msg, $sformatf("\theader_addr 0x%h(%0d)\n", pcie_addr[DATA_ADDR_W-1 : 0], pcie_addr[DATA_ADDR_W-1 : 0])};
        debug_msg = {debug_msg, $sformatf("\theader_num  0x%h(%0d)\n", ptr.hdr_addr, ptr.hdr_addr)};
        debug_msg = {debug_msg, $sformatf("\tpcie_len  %0d dwords\n", pcie_len)};
        debug_msg = {debug_msg, $sformatf("\tfbe %h fbe %h\n", fbe, lbe)};
        debug_msg = {debug_msg, $sformatf("\tpacket size    %0dB\n", req.packet.size())};
        debug_msg = {debug_msg, $sformatf("\tpacket pointer %0dB\n", packet_ptr)};
        debug_msg = {debug_msg, $sformatf("\tmeta %h\n", req.meta)};
        `uvm_info(this.get_full_name(), debug_msg, UVM_HIGH);

        wait_for_free_space(1, m_regmodel.hw_hdr_pointer, ptr.hdr_addr, ptr.hdr_mask);
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
            string debug_msg;

            seq_item_port.get_next_item(req);

            debug_msg = "\n";
            debug_msg = {debug_msg, "==========================================================\n"};
            debug_msg = {debug_msg, $sformatf("Send packet to channle %0d\n", channel)};
            debug_msg = {debug_msg, "==========================================================\n"};
            debug_msg = {debug_msg, req.convert2string()};
            `uvm_info(this.get_full_name(), debug_msg, UVM_FULL);

            ptr_read(m_regmodel.data_mask, ptr.data_mask);
            ptr_read(m_regmodel.hdr_mask , ptr.hdr_mask);

            //align start of packet to PACKET_ALIGMENT
            packet_ptr = ptr.data_addr;

            send_data();
            send_header(packet_ptr);
            seq_item_port.item_done();
        end
    endtask
endclass

