// pkg.sv
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


// Items description
//
// ============ ==================================================================
// FLAG         Flag which contains information about:
//              Flag[2] Type of L3 protocol (1 - IPv4, 0 - IPv6).
//              Flag[3] Type of L4 protocol (1 - TCP, 0 - UDP).
//              Flag[1] TCP/UDP checksum enable.
//              Flag[0] IP checksum enable.
// L2_SIZE      Size of L2 header.
// L3_SIZE      Size of L3 header.
// L4_SIZE      Size of L4 header.
// PAYLOAD_SIZE Size of data payload.
// ============ ==================================================================


// This class represents high level transaction, which can be reusable for other components.
class sequence_item extends uvm_sequence_item;
    // Registration of object tools.
    `uvm_object_utils(uvm_header_type::sequence_item)

    // -----------------------
    // Variables.
    // -----------------------

    rand int l2_size;
    rand int l3_size;
    rand int l4_size;
    rand int payload_size;
    rand logic [4-1 : 0] flag;

    // Constructor - creates new instance of this class
    function new(string name = "sequence_item");
        super.new(name);
    endfunction

    // -----------------------
    // Common UVM functions.
    // -----------------------

    // Properly copy all transaction attributes.
    function void do_copy(uvm_object rhs);
        sequence_item rhs_;

        if(!$cast(rhs_, rhs)) begin
            `uvm_fatal( "do_copy:", "Failed to cast transaction object.")
            return;
        end
        // Now copy all attributes
        super.do_copy(rhs);
        flag = rhs_.flag;
        l2_size = rhs_.l2_size;
        l3_size = rhs_.l3_size;
        l4_size = rhs_.l4_size;
        payload_size = rhs_.payload_size;
    endfunction: do_copy

    // Properly compare all transaction attributes representing output pins.
    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        bit ret;
        sequence_item rhs_;

        if(!$cast(rhs_, rhs)) begin
            `uvm_fatal("do_compare:", "Failed to cast transaction object.")
            return 0;
        end

        ret  = super.do_compare(rhs, comparer);
        ret &= (flag == rhs_.flag);
        ret &= (l2_size == rhs_.l2_size);
        ret &= (l3_size == rhs_.l3_size);
        ret &= (l4_size == rhs_.l4_size);
        ret &= (payload_size == rhs_.payload_size);
        return ret;
    endfunction: do_compare

    // Convert transaction into human readable form.
    function string convert2string();
        string ret;

        $swrite(ret, "\n\tflag : %b\n\tl2_size : %d\n\tl3_size : %d\n\tl4_size : %d\n\tpayload_size : %d\n", 
                     flag, l2_size, l3_size, l4_size, payload_size);

        return ret;
    endfunction
endclass

