//-- scoreboard.sv: Scoreboard for verification
//-- Copyright (C) 2023 CESNET z. s. p. o.
//-- Author:   Oliver Gurka <xgurka00@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

class mvb_comparer #(ITEMS, ITEM_WIDTH) extends uvm_common::comparer_ordered #(uvm_mvb::sequence_item #(ITEMS, ITEM_WIDTH));
    `uvm_component_param_utils(uvm_mvb_mux::mvb_comparer #(ITEMS, ITEM_WIDTH))

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction // new

    virtual function void write_dut(uvm_mvb::sequence_item #(ITEMS, ITEM_WIDTH) tr);
        if (tr.src_rdy == 1 && tr.dst_rdy == 1) begin
            dut_sends += 1;
            if (model_items.size() != 0) begin
                uvm_common::model_item #(uvm_mvb::sequence_item #(ITEMS, ITEM_WIDTH)) item;

                item = model_items.pop_front();
                if (this.compare(item.item, tr) == 0) begin
                    errors++;
                    `uvm_error(this.get_full_name(), $sformatf("\n\tTransaction %0d doesn't match.\n\t\tInput times %s\n\t\toutput time %0dns\n%s\n", dut_sends, item.convert2string_time(), $time()/1ns, this.message(item.item, tr)));
                end else begin
                    compared++;
                end
            end else begin
                uvm_common::comparer_dut #(uvm_mvb::sequence_item #(ITEMS, ITEM_WIDTH)) tmp_tr = new(dut_sends, $time(), tr);
                dut_items.push_back(tmp_tr);
            end
        end
    endfunction

endclass
