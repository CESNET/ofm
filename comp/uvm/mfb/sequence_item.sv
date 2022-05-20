//-- sequence_item.sv: Item for mfb sequencer
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

class sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) extends uvm_sequence_item;

    // ------------------------------------------------------------------------
    // Registration of object tools
    `uvm_object_param_utils(uvm_mfb::sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH))

    // ------------------------------------------------------------------------
    // Member attributes, equivalent with interface pins
    localparam DATA_WIDTH =  REGION_SIZE * BLOCK_SIZE * ITEM_WIDTH;
    localparam SOF_POS_WIDTH = $clog2(REGION_SIZE);
    localparam EOF_POS_WIDTH = $clog2(REGION_SIZE * BLOCK_SIZE);

    // ------------------------------------------------------------------------
    // Bus structure of mfb
    rand logic [DATA_WIDTH       -1 : 0] ITEMS [REGIONS];
    rand logic [META_WIDTH       -1 : 0] META [REGIONS];
    rand logic [SOF_POS_WIDTH    -1 : 0] SOF_POS [REGIONS];
    rand logic [EOF_POS_WIDTH    -1 : 0] EOF_POS [REGIONS];
    rand logic [REGIONS          -1 : 0] SOF;
    rand logic [REGIONS          -1 : 0] EOF;
    rand logic SRC_RDY;
    rand logic DST_RDY;


    // ------------------------------------------------------------------------
    // Constructor
    function new(string name = "sequence_item");
        super.new(name);
    endfunction

    // ------------------------------------------------------------------------
    // Common UVM functions

    // Properly copy all transaction attributes.
    function void do_copy(uvm_object rhs);
        sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) rhs_;

        if(!$cast(rhs_, rhs)) begin
            `uvm_fatal( "mvb::sequence_item::do_copy:", "Failed to cast transaction object." )
            return;
        end

        // Now copy all attributes.
        super.do_copy(rhs);
        ITEMS       = rhs_.ITEMS;
        META        = rhs_.META;
        SOF_POS     = rhs_.SOF_POS;
        EOF_POS     = rhs_.EOF_POS;
        SOF         = rhs_.SOF;
        EOF         = rhs_.EOF;
        SRC_RDY     = rhs_.SRC_RDY;
        DST_RDY     = rhs_.DST_RDY;
    endfunction

    // Properly compare all transaction attributes representing output pins.
    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) rhs_;

        if(!$cast(rhs_, rhs)) begin
            `uvm_fatal("do_compare:", "Failed to cast transaction object.")
            return 0;
        end

        // Compare all attributes that maters
        return (super.do_compare(rhs, comparer) &&
            (ITEMS      == rhs_.ITEMS) &&
            (META       == rhs_.META) &&
            (SOF_POS       == rhs_.SOF_POS) &&
            (EOF_POS       == rhs_.EOF_POS) &&
            (SOF       == rhs_.SOF) &&
            (EOF       == rhs_.EOF) &&
            (SRC_RDY    == rhs_.SRC_RDY) &&
            (DST_RDY    == rhs_.DST_RDY));

    endfunction

    // Visualize the sequence item to string
    function string convert2string();
        string output_string = "";
        string data = "";

        $sformat(output_string, {"\n\tSRC_RDY: %b\n\tDST_RDY: %b\n"},
            SRC_RDY,
            DST_RDY
        );

        for (int unsigned it = 0; it < REGIONS; it++) begin
            $swrite(output_string, "%s\n\t-- id %0d\n\tEOF %b EOF_POS %0d\n\tSOF %b SOF_POS %0d\n\tDATA %h\n\tMETA %h\n",output_string, it, EOF[it], EOF_POS[it], SOF[it], SOF_POS[it], ITEMS[it], META[it]);
        end

        // Print out all  items
        // TODO - přidat výpis všech itemů
/*
        for (int i = 0 ; i < ITEMS ; i++) begin
            $sformat(data, {"\tDATA: 'h%0h\tVLD: %b\n"},
            DATA[i],
            VLD[i]
            );
            output_string = {output_string, data}; 
        end
*/       
        return output_string;
    endfunction

endclass
