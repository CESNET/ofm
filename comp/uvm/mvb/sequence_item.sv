//-- sequence_item.sv: Item for mvb sequencer
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

`ifndef MVB_SEQUENCE_ITEM_SV
`define MVB_SEQUENCE_ITEM_SV

class sequence_item #(ITEMS, ITEM_WIDTH) extends uvm_sequence_item;

    // ------------------------------------------------------------------------
    // Registration of object tools
    `uvm_object_param_utils(mvb::sequence_item #(ITEMS, ITEM_WIDTH))

    // ------------------------------------------------------------------------
    // Member attributes, equivalent with interface pins
    rand logic [ITEM_WIDTH-1 : 0] DATA [ITEMS];
    rand logic [ITEMS-1 : 0] VLD;
    rand logic SRC_RDY;
    rand logic DST_RDY;

    constraint data_gen_cons { |VLD == 0 -> SRC_RDY == 0;}
    
    // ------------------------------------------------------------------------
    // Constructor
    function new(string name = "sequence_item");
        super.new(name);
    endfunction

    // ------------------------------------------------------------------------
    // Common UVM functions

    // Properly copy all transaction attributes.
    function void do_copy(uvm_object rhs);
        sequence_item #(ITEMS, ITEM_WIDTH) rhs_;

        if(!$cast(rhs_, rhs)) begin
            `uvm_fatal( "mvb::sequence_item::do_copy:", "Failed to cast transaction object." )
            return;
        end

        // Now copy all attributes.
        super.do_copy(rhs);
        DATA        = rhs_.DATA;
        VLD         = rhs_.VLD;
        SRC_RDY     = rhs_.SRC_RDY;
        DST_RDY     = rhs_.DST_RDY;
    endfunction

    // Properly compare all transaction attributes representing output pins.
    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        sequence_item #(ITEMS, ITEM_WIDTH) rhs_;

        if(!$cast(rhs_, rhs)) begin
            `uvm_fatal("do_compare:", "Failed to cast transaction object.")
            return 0;
        end
        
        // Compare all attributes that maters
        return (super.do_compare(rhs, comparer) &&
            (DATA       == rhs_.DATA) &&
            (VLD        == rhs_.VLD)) && 
            (SRC_RDY    == rhs_.SRC_RDY) &&
            (DST_RDY    == rhs_.DST_RDY);
    endfunction

    // Visualize the sequence item to string 
    function string convert2string();
        string output_string = "";
        string data = "";

        $sformat(output_string, {"%s\n\tSRC_RDY: %b\n\tDST_RDY: %b\n"},
            super.convert2string(),
            SRC_RDY,
            DST_RDY
        );

        // Add new line for each item with correspondence valid bit
        for (int i = 0 ; i < ITEMS ; i++) begin
            $sformat(data, {"\tDATA: 'h%0h\tVLD: %b\n"},
            DATA[i],
            VLD[i]
            );
            output_string = {output_string, data}; 
        end
        
        return output_string;
    endfunction

endclass

`endif
