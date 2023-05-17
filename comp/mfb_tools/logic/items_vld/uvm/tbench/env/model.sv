// model.sv: Model of implementation
// Copyright (C) 2023 CESNET z. s. p. o.
// Author(s): Daniel Kriz <danielkriz@cesnet.cz>

// SPDX-License-Identifier: BSD-3-Clause


class model #(META_WIDTH, MVB_DATA_WIDTH, MFB_ITEM_WIDTH, OFFSET_WIDTH, LENGTH_WIDTH, VERBOSITY) extends uvm_component;
    `uvm_component_param_utils(uvm_items_valid::model #(META_WIDTH, MVB_DATA_WIDTH, MFB_ITEM_WIDTH, OFFSET_WIDTH, LENGTH_WIDTH, VERBOSITY))

    uvm_tlm_analysis_fifo #(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH)) input_mfb;
    uvm_tlm_analysis_fifo #(uvm_logic_vector::sequence_item #(META_WIDTH))           input_meta;
    uvm_analysis_port #(uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH))           out_mvb;
    uvm_analysis_port #(uvm_logic_vector::sequence_item #(1))                        out_mvb_end;

    typedef logic [MVB_DATA_WIDTH-1 : 0] mvb_fifo[$];
    int                                  pkt_cnt = 0;

    function new(string name = "model", uvm_component parent = null);
        super.new(name, parent);

        input_mfb     = new("input_mfb", this);
        input_meta    = new("input_meta", this);
        out_mvb       = new("out_mvb", this);
        out_mvb_end = new("out_mvb_end", this);

    endfunction

    task extract_valid_data(uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH) frame, logic [OFFSET_WIDTH-1 : 0] offset, logic [LENGTH_WIDTH-1 : 0] length);
        uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH) out_mvb_tr;
        uvm_logic_vector::sequence_item #(1)              out_mvb_end_tr;
        string msg = "";
        int    mvb_cnt = 0;

        $swrite(msg, "%s\n\tMFB PKT COUNT %d", msg, pkt_cnt);
        `uvm_info(this.get_full_name(), msg ,UVM_MEDIUM)

        for (int i = offset; i < offset+length; i++) begin
            out_mvb_tr       = uvm_logic_vector::sequence_item #(MVB_DATA_WIDTH)::type_id::create("out_mvb_tr");
            out_mvb_end_tr = uvm_logic_vector::sequence_item #(1)::type_id::create("out_mvb_end_tr");
            out_mvb_tr.data  = frame.data[i];
            `uvm_info(this.get_full_name(), out_mvb_tr.convert2string() ,UVM_MEDIUM)
            mvb_cnt++;
            if (i < offset+length-1) begin
                out_mvb_end_tr.data = 1'b0;
            end else begin
                out_mvb_end_tr.data = 1'b1;
            end
            out_mvb_end.write(out_mvb_end_tr);
            out_mvb.write(out_mvb_tr);
        end
    endtask

    task run_phase(uvm_phase phase);

        uvm_logic_vector_array::sequence_item #(MFB_ITEM_WIDTH) tr_input_mfb;
        uvm_logic_vector::sequence_item #(META_WIDTH)           tr_input_meta;
        uvm_logic_vector::sequence_item #(1)                    chsum_en;

        logic [OFFSET_WIDTH-1 : 0] offset = '0;
        logic [LENGTH_WIDTH-1 : 0] length = '0;
        logic                      enable = '0;

        forever begin

            string msg = "";

            input_mfb.get(tr_input_mfb);
            input_meta.get(tr_input_meta);

            pkt_cnt++;
            if (VERBOSITY >= 1) begin
                `uvm_info(this.get_full_name(), tr_input_mfb.convert2string() ,UVM_NONE)
                `uvm_info(this.get_full_name(), tr_input_meta.convert2string() ,UVM_MEDIUM) // useless
            end

            offset = tr_input_meta.data[OFFSET_WIDTH-1              : 0];
            length = tr_input_meta.data[OFFSET_WIDTH+LENGTH_WIDTH-1 : OFFSET_WIDTH];
            enable = tr_input_meta.data[OFFSET_WIDTH+LENGTH_WIDTH   : OFFSET_WIDTH+LENGTH_WIDTH];
            $swrite(msg, "\n%s\nOFFSET %d\n", msg, offset);
            $swrite(msg, "\n%sLENGTH %d\n", msg, length);
            $swrite(msg, "\n%sENABLE %d\n", msg, enable);
            `uvm_info(this.get_full_name(), msg ,UVM_MEDIUM)
            if (enable) begin
                extract_valid_data(tr_input_mfb, offset, length);
            end

        end

    endtask
endclass
