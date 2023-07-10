// pkg.sv
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


// Items description
//
// ========= ==================================================================
// LENGTH    Lenght of partial data packet without header.
// NEXT      Flag that indicates existence of other packet in current Superpacket.
// MASK      Mask of replications. Indicates max amount of possible replications.
// LOOP_ID   Number of repetition of one PCAP.
// TIMESTAMP Timestamp of Superpacket.
// META      Metadata of Superpacket.
// ========= ==================================================================


// This class represents high level transaction, which can be reusable for other components.
class sequence_item #(MVB_ITEM_WIDTH) extends uvm_sequence_item;
    // Registration of object tools.
    `uvm_object_param_utils(uvm_superpacket_header::sequence_item #(MVB_ITEM_WIDTH))

    // -----------------------
    // Variables.
    // -----------------------

    rand logic [15-1 : 0]             length;
    rand logic [1-1 : 0]              next;
    rand logic [(4*8)-1 : 0]          mask;
    rand logic [(2*8)-1 : 0]          loop_id;
    rand logic [(8*8)-1 : 0]          timestamp;
    rand logic [MVB_ITEM_WIDTH-1 : 0] meta;

    // Constructor - creates new instance of this class
    function new(string name = "sequence_item");
        super.new(name);
    endfunction

    // -----------------------
    // Common UVM functions.
    // -----------------------

    // Properly copy all transaction attributes.
    function void do_copy(uvm_object rhs);
        sequence_item #(MVB_ITEM_WIDTH) rhs_;

        if(!$cast(rhs_, rhs)) begin
            `uvm_fatal( "do_copy:", "Failed to cast transaction object.")
            return;
        end
        // Now copy all attributes
        super.do_copy(rhs);
        length    = rhs_.length;
        next      = rhs_.next;
        mask      = rhs_.mask;
        loop_id   = rhs_.loop_id;
        timestamp = rhs_.timestamp;
        meta      = rhs_.meta;
    endfunction: do_copy

    // Properly compare all transaction attributes representing output pins.
    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        bit ret;
        sequence_item #(MVB_ITEM_WIDTH) rhs_;

        if(!$cast(rhs_, rhs)) begin
            `uvm_fatal("do_compare:", "Failed to cast transaction object.")
            return 0;
        end

        ret  = super.do_compare(rhs, comparer);
        ret &= (length    == rhs_.length);
        ret &= (next      == rhs_.next);
        ret &= (mask      == rhs_.mask);
        ret &= (loop_id   == rhs_.loop_id);
        ret &= (timestamp == rhs_.timestamp);
        ret &= (meta      == rhs_.meta);
        return ret;
    endfunction: do_compare

    // Convert transaction into human readable form.
    function string convert2string();
        string ret;

        $swrite(ret, "\tlength : %h\n\tnext : %h\n\tmask : %h\n\tloop_id : %h\n\ttimestamp : %h\n\tmeta %h\n", 
                     length, next, mask, loop_id, timestamp, meta);

        return ret;
    endfunction
endclass

