//-- sync_tag.sv: Synchronization of tags
//-- Copyright (C) 2023 CESNET z. s. p. o.
//-- Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

class sync_tag extends uvm_component;
    `uvm_component_utils(uvm_pcie_hdr::sync_tag)

    logic [8-1 : 0] list_of_tags [logic [8-1 : 0]];
    int tag_cnt = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task fill_array();
        for (int unsigned it = 0; it < 256; it++) begin
            list_of_tags[it] = it;
            tag_cnt++;
        end
    endtask

    task add_element(logic[8-1 : 0] tag);
        list_of_tags[tag] = tag;
        tag_cnt++;
    endtask

    task remove_element(logic[8-1 : 0] tag);
        list_of_tags.delete(tag);
        tag_cnt--;
    endtask

    task print_all();
        for (int unsigned it = 0; it < 256; it++) begin
            if (list_of_tags.exists(it)) begin
                $write("TAG: %0d\n", list_of_tags[it]);
            end
        end
    endtask

    task print_element(logic[8-1 : 0] tag);
        $write("TAG: %0d\n", list_of_tags[tag]);
    endtask

endclass