//-- sequence.sv
//-- Copyright (C) 2023 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <danielkriz@cesnet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

// This low level sequence define bus functionality
class logic_vector_array_sequence#(ITEM_WIDTH, string DEVICE, string ENDPOINT_TYPE) extends uvm_sequence #(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH));
    `uvm_object_param_utils(uvm_pcie_cq::logic_vector_array_sequence#(ITEM_WIDTH, DEVICE, ENDPOINT_TYPE))

    localparam IS_INTEL_DEV    = (DEVICE == "STRATIX10" || DEVICE == "AGILEX");
    localparam IS_MFB_META_DEV = (ENDPOINT_TYPE == "P_TILE" || ENDPOINT_TYPE == "R_TILE") && IS_INTEL_DEV;
    mailbox#(uvm_logic_vector::sequence_item#(131)) tr_export;

    function new(string name = "logic_vector_array_sequence");
        super.new(name);
    endfunction

    task body;
        uvm_logic_vector::sequence_item#(131) pcie_hdr;
        uvm_logic_vector_array::sequence_item#(ITEM_WIDTH) m_pcie_data;
        uvm_pcie_hdr::msg_type rw;
        int unsigned tr_cnt;

        forever begin
            string msg = "";
            int unsigned data_size;


            tr_export.get(pcie_hdr);
            rw = pcie_hdr.data[131-1 : 128];

            req         = uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)::type_id::create("req");
            m_pcie_data = uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)::type_id::create("m_pcie_data");

            if (IS_INTEL_DEV) begin
                data_size = unsigned'(pcie_hdr.data[10-1 : 0]) != 0 ? unsigned'(pcie_hdr.data[10-1 : 0]) : 'h400; 
            end else begin
                data_size = unsigned'(pcie_hdr.data[75-1 : 64]); 
            end
            assert(m_pcie_data.randomize() with {m_pcie_data.data.size() == data_size;});

            if (IS_MFB_META_DEV) begin
                // In case of Intel
                // Add only data to array
                //req.data = new[m_pcie_data.data.size()];
                req.data = m_pcie_data.data;
            end else begin
                // Add PCIe HDR and data to array
                req.data = new[m_pcie_data.data.size()+(sv_pcie_meta_pack::PCIE_META_REQ_HDR_W/ITEM_WIDTH)];
                if (ENDPOINT_TYPE == "H_TILE" && pcie_hdr.data[29] == 1'b0) begin
                    req.data = new[m_pcie_data.data.size()+(sv_pcie_meta_pack::PCIE_META_REQ_HDR_W/ITEM_WIDTH)-1];
                    req.data = {pcie_hdr.data[31 : 0], pcie_hdr.data[63 : 32], pcie_hdr.data[95 : 64], m_pcie_data.data};
                end else begin
                    req.data = new[m_pcie_data.data.size()+(sv_pcie_meta_pack::PCIE_META_REQ_HDR_W/ITEM_WIDTH)];
                    req.data = {pcie_hdr.data[31 : 0], pcie_hdr.data[63 : 32], pcie_hdr.data[95 : 64], pcie_hdr.data[127 : 96], m_pcie_data.data};
                end
            end

            if (rw == uvm_pcie_hdr::TYPE_READ) begin
                req = uvm_logic_vector_array::sequence_item#(ITEM_WIDTH)::type_id::create("req");
                if (!IS_MFB_META_DEV) begin
                    req.data = new[sv_pcie_meta_pack::PCIE_META_REQ_HDR_W/ITEM_WIDTH];
                    req.data = {pcie_hdr.data[31 : 0], pcie_hdr.data[63 : 32], pcie_hdr.data[95 : 64], pcie_hdr.data[127 : 96]};
                end else begin
                    req.data = new[1];
                    req.data[0] = '0;
                end
            end

            tr_cnt++;

            $swrite(msg, "\n\t =============== Driver CQ DATA =============== \n");
            $swrite(msg, "%s\nTransaction number: %0d\n", msg, tr_cnt);
            $swrite(msg, "%s\nDriver CQ Response Data %s\n", msg, req.convert2string());
            `uvm_info(this.get_full_name(), msg, UVM_FULL)

            start_item(req);
            finish_item(req);
        end
    endtask
endclass



class logic_vector_sequence#(META_WIDTH) extends uvm_sequence #(uvm_logic_vector::sequence_item#(META_WIDTH));
    `uvm_object_param_utils(uvm_pcie_cq::logic_vector_sequence#(META_WIDTH))

    mailbox#(uvm_logic_vector::sequence_item#(META_WIDTH)) tr_export;
    int unsigned tr_cnt;

    function new(string name = "logic_vector_sequence");
        super.new(name);
        tr_cnt = 0;
    endfunction

    task body;
        forever begin
            tr_export.get(req);

            tr_cnt++;
            start_item(req);
            finish_item(req);
        end
    endtask
endclass

