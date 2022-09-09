//-- sequence.sv
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

// This low level sequence define bus functionality
class byte_array_sequence#(PCIE_UPHDR_WIDTH) extends uvm_sequence #(uvm_logic_vector_array::sequence_item #(32));
    `uvm_object_utils(uvm_pcie_rc::byte_array_sequence#(PCIE_UPHDR_WIDTH))

    uvm_pcie_rc::tr_planner #(PCIE_UPHDR_WIDTH) tr_plan;
    int unsigned mfb_cnt = 0;

    function new(string name = "sequence_simple_rx_base");
        super.new(name);
    endfunction


    task body;
        req = uvm_logic_vector_array::sequence_item #(32)::type_id::create("req");

        forever begin
            uvm_logic_vector::sequence_item#(PCIE_UPHDR_WIDTH) hl_tr;
            string debug_msg = "";

            wait(tr_plan.byte_array.size() != 0);
            hl_tr = tr_plan.byte_array.pop_front();
            start_item(req);
            assert(req.randomize() with {req.data.size() == int'(hl_tr.data[10-1 : 0]); });
            mfb_cnt++;
            $swrite(debug_msg, "%s\n\t RC SEQ MFB NUMBER %d: %s\n", debug_msg, mfb_cnt, req.convert2string());
            `uvm_info(this.get_full_name(), debug_msg ,UVM_MEDIUM)
            finish_item(req);
        end

    endtask
endclass

class logic_vector_sequence #(PCIE_DOWNHDR_WIDTH, PCIE_UPHDR_WIDTH) extends uvm_sequence #(uvm_logic_vector::sequence_item#(PCIE_DOWNHDR_WIDTH));
    `uvm_object_param_utils(uvm_pcie_rc::logic_vector_sequence #(PCIE_DOWNHDR_WIDTH, PCIE_UPHDR_WIDTH))

    uvm_pcie_rc::tr_planner #(PCIE_UPHDR_WIDTH) tr_plan;
    int unsigned mvb_cnt = 0;

    function new(string name = "logic_vector_sequence");
        super.new(name);
    endfunction

    function logic[7-1 : 0] count_low_addr(logic[64 : 0] global_id, logic [4-1 : 0] be);
        logic[7-1 : 0] ret; // low address
        logic[2-1 : 0] lab; // low address bits
        lab = sv_dma_bus_pack::encode_fbe(be);
        ret = {global_id[7-1 : 2], lab};
        return ret;
    endfunction

    task body;
        req = uvm_logic_vector::sequence_item#(PCIE_DOWNHDR_WIDTH)::type_id::create("req");

        forever begin
            string debug_msg = "";
            uvm_logic_vector::sequence_item#(PCIE_UPHDR_WIDTH) hl_tr;
            uvm_ptc_info_rc::sequence_item pcie_tr;
            logic [16-1 : 0] completer_id = '0; // '0
            logic [3-1 : 0] complete_st = '0;
            logic bcm = 1'b0;
            logic [12-1 : 0] byte_cnt = '0;
            logic [7-1 : 0] low_addr = '0;

            wait(tr_plan.logic_array.size() != 0);
            hl_tr = tr_plan.logic_array.pop_front();

            pcie_tr = uvm_ptc_info_rc::sequence_item::type_id::create("pcie_tr");
            pcie_tr.global_id = hl_tr.data[96-1 : 64]; // GLOBAL ID + PADDING 00
            pcie_tr.req_id    = hl_tr.data[64-1 : 48]; // same
            pcie_tr.tag       = hl_tr.data[48-1 : 40]; // same
            pcie_tr.lastbe    = hl_tr.data[40-1 : 36];
            pcie_tr.firstbe   = hl_tr.data[36-1 : 32];
            pcie_tr.fmt       = hl_tr.data[32-1 : 29];
            pcie_tr.type_n    = hl_tr.data[29-1 : 24];
            pcie_tr.tag_9     = hl_tr.data[23];
            pcie_tr.tc        = hl_tr.data[23-1 : 20];
            pcie_tr.tag_8     = hl_tr.data[19];
            pcie_tr.padd_0    = hl_tr.data[19-1 : 16];
            pcie_tr.td        = hl_tr.data[15];
            pcie_tr.ep        = hl_tr.data[14];
            pcie_tr.relaxed   = hl_tr.data[13];
            pcie_tr.snoop     = hl_tr.data[12];
            pcie_tr.at        = hl_tr.data[12-1 : 10];
            pcie_tr.len       = hl_tr.data[10-1 : 0];

            byte_cnt = int'(pcie_tr.len * 4) - int'(sv_dma_bus_pack::encode_fbe(pcie_tr.firstbe)) - int'(sv_dma_bus_pack::encode_lbe(pcie_tr.lastbe));

            low_addr = count_low_addr(pcie_tr.global_id, pcie_tr.firstbe);

            req.data = {pcie_tr.req_id, pcie_tr.tag, 1'b0, low_addr, completer_id, complete_st, bcm, byte_cnt, 
                        8'b01001010, pcie_tr.tag_9, pcie_tr.tc, pcie_tr.tag_8, pcie_tr.padd_0,
                        pcie_tr.td, pcie_tr.ep, pcie_tr.relaxed, pcie_tr.snoop, pcie_tr.at, pcie_tr.len};

            start_item(req);
            mvb_cnt++;

            $swrite(debug_msg, "%s\n\t Generated RC request MVB number %d: %s\n", debug_msg, mvb_cnt, req.convert2string());
            $swrite(debug_msg, "%s\n\t Deparsed RC MVB TR: \n", debug_msg);

            $swrite(debug_msg, "%s\n\t PACKET SIZE:      %d", debug_msg, pcie_tr.len);
            $swrite(debug_msg, "%s\n\t ATRIBUTES:        %h", debug_msg, pcie_tr.at);
            $swrite(debug_msg, "%s\n\t SNOOP:            %h", debug_msg, pcie_tr.snoop);
            $swrite(debug_msg, "%s\n\t RELAXED:          %h", debug_msg, pcie_tr.relaxed);
            $swrite(debug_msg, "%s\n\t ERROR POISON:     %h", debug_msg, pcie_tr.ep);
            $swrite(debug_msg, "%s\n\t TD:               %h", debug_msg, pcie_tr.td);
            $swrite(debug_msg, "%s\n\t PADD0:            %h", debug_msg, pcie_tr.padd_0);
            $swrite(debug_msg, "%s\n\t TAG_8:            %h", debug_msg, pcie_tr.tag_8);
            $swrite(debug_msg, "%s\n\t TRAFFIC CLASS:    %h", debug_msg, pcie_tr.tc);
            $swrite(debug_msg, "%s\n\t TAG_9:            %h", debug_msg, pcie_tr.tag_9);
            $swrite(debug_msg, "%s\n\t CONST:            %h", debug_msg, 8'b01001010);
            $swrite(debug_msg, "%s\n\t BYTE CNT:         %h", debug_msg, byte_cnt);
            $swrite(debug_msg, "%s\n\t BCM:              %h", debug_msg, bcm);
            $swrite(debug_msg, "%s\n\t COMPLETE STATUS:  %h", debug_msg, complete_st);
            $swrite(debug_msg, "%s\n\t COMPLETER ID:     %h", debug_msg, completer_id);
            $swrite(debug_msg, "%s\n\t LOW ADDRESS:      %h", debug_msg, low_addr);
            $swrite(debug_msg, "%s\n\t CONST:            %h", debug_msg, 1'b0);
            $swrite(debug_msg, "%s\n\t TAG:              %h", debug_msg, pcie_tr.tag);
            $swrite(debug_msg, "%s\n\t REQUEST ID:       %h", debug_msg, pcie_tr.req_id);

            `uvm_info(this.get_full_name(), debug_msg ,UVM_MEDIUM);

            finish_item(req);
        end

    endtask
endclass
