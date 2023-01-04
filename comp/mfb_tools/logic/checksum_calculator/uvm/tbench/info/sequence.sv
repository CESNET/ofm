// sequence.sv
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


// Reusable high level sequence. Contains transaction, which has only data part.
class ipv_4_tcp_sequence extends uvm_sequence #(uvm_header_type::sequence_item);
    `uvm_object_utils(uvm_header_type::ipv_4_tcp_sequence)

    rand int unsigned transaction_count;
    int unsigned transaction_count_min = 100;
    int unsigned transaction_count_max = 200;

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}

    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new(name);
    endfunction

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "uvm_header_type::ipv_4_tcp_sequence is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            // Generate random request, which must be in interval from min length to max length
            `uvm_do_with(req,
            {
                flag[2] == 1             ;
                flag[3] == 1             ;
                l3_size inside{[20 : 60]};
                (l3_size % 4) == 0       ;
                l4_size inside{[20 : 60]};
                (l4_size % 4) == 0       ;
                l2_size inside{[14 : 127]};
                payload_size inside{[10 : 100]};
            })
        end
    endtask

endclass

class ipv_4_udp_sequence extends uvm_sequence #(uvm_header_type::sequence_item);
    `uvm_object_utils(uvm_header_type::ipv_4_udp_sequence)

    rand int unsigned transaction_count;
    int unsigned transaction_count_min = 100;
    int unsigned transaction_count_max = 200;

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}

    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new(name);
    endfunction

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "uvm_header_type::ipv_4_udp_sequence is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            // Generate random request, which must be in interval from min length to max length
            `uvm_do_with(req,
            {
                flag[2] == 1             ;
                flag[3] == 0             ;
                l3_size inside{[20 : 60]};
                (l3_size % 4) == 0       ;
                l4_size == 8;
                (l4_size % 4) == 0       ;
                l2_size inside{[14 : 127]};
                payload_size inside{[10 : 100]};
            })
        end
    endtask

endclass

class ipv_6_tcp_sequence extends uvm_sequence #(uvm_header_type::sequence_item);
    `uvm_object_utils(uvm_header_type::ipv_6_tcp_sequence)

    rand int unsigned transaction_count;
    int unsigned transaction_count_min = 100;
    int unsigned transaction_count_max = 200;

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}

    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new(name);
    endfunction

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "uvm_header_type::ipv_6_tcp_sequence is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            // Generate random request, which must be in interval from min length to max length
            `uvm_do_with(req,
            {
                flag[2] == 0             ;
                flag[3] == 1             ;
                l3_size inside{[40 : 511]};
                (l3_size % 4) == 0       ;
                l4_size inside{[20 : 60]};
                (l4_size % 4) == 0       ;
                l2_size inside{[14 : 127]};
                payload_size inside{[10 : 100]};
            })
        end
    endtask

endclass

class ipv_6_udp_sequence extends uvm_sequence #(uvm_header_type::sequence_item);
    `uvm_object_utils(uvm_header_type::ipv_6_udp_sequence)

    rand int unsigned transaction_count;
    int unsigned transaction_count_min = 100;
    int unsigned transaction_count_max = 200;

    constraint c1 {transaction_count inside {[transaction_count_min : transaction_count_max]};}

    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new(name);
    endfunction

    // Generates transactions
    task body;
        `uvm_info(get_full_name(), "uvm_header_type::ipv_6_udp_sequence is running", UVM_DEBUG)
        repeat(transaction_count)
        begin
            // Generate random request, which must be in interval from min length to max length
            `uvm_do_with(req,
            {
                flag[2] == 0             ;
                flag[3] == 0             ;
                l3_size inside{[40 : 511]};
                (l3_size % 4) == 0       ;
                l4_size == 8;
                (l4_size % 4) == 0       ;
                l2_size inside{[14 : 127]};
                payload_size inside{[10 : 100]};
            })
        end
    endtask

endclass

/////////////////////////////////////////////////////////////////////////
// SEQUENCE LIBRARY
class sequence_lib extends uvm_sequence_library#(sequence_item);
  `uvm_object_utils(uvm_header_type::sequence_lib)
  `uvm_sequence_library_utils(uvm_header_type::sequence_lib)

    function new(string name = "sequence_library");
        super.new(name);
        init_sequence_library();
    endfunction

    // subclass can redefine and change run sequences
    // can be useful in specific tests
    virtual function void init_sequence();
        this.add_sequence(uvm_header_type::ipv_4_tcp_sequence::get_type());
        this.add_sequence(uvm_header_type::ipv_4_udp_sequence::get_type());
        this.add_sequence(uvm_header_type::ipv_6_tcp_sequence::get_type());
        this.add_sequence(uvm_header_type::ipv_6_udp_sequence::get_type());
    endfunction
endclass
