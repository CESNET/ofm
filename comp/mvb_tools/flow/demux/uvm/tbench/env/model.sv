// model.sv: Model of implementation
// Copyright (C) 2023-2024 CESNET z. s. p. o.
// Author(s): Oliver Gurka <xgurka00@stud.fit.vutbr.cz>
//            Vladislav Valek <valekv@cesnet.cz>

// SPDX-License-Identifier: BSD-3-Clause


class model #(ITEM_WIDTH, TX_PORTS) extends uvm_component;
    `uvm_component_param_utils(uvm_mvb_demux::model#(ITEM_WIDTH, TX_PORTS))

    // Model input
    uvm_tlm_analysis_fifo #(uvm_common::model_item #(uvm_logic_vector::sequence_item #(ITEM_WIDTH + $clog2(TX_PORTS))))  rx_mvb_analysis_fifo;
    // Model output
    uvm_analysis_port     #(uvm_common::model_item #(uvm_logic_vector::sequence_item #(ITEM_WIDTH)))                     tx_mvb_analysis_imp [TX_PORTS - 1 : 0];

    function new(string name = "model", uvm_component parent = null);
        super.new(name, parent);

        rx_mvb_analysis_fifo         = new("rx_mvb_analysis_fifo",  this);
        for (int i = 0; i < TX_PORTS; i++) begin
            tx_mvb_analysis_imp[i] = new($sformatf("tx_mvb_analysis_imp_%0d", i), this);
        end
    endfunction

    task run_phase(uvm_phase phase);
        int unsigned port = 0;

        uvm_common::model_item #(uvm_logic_vector::sequence_item #(ITEM_WIDTH + $clog2(TX_PORTS)))  rx_mvb_tr;
        uvm_common::model_item #(uvm_logic_vector::sequence_item #(ITEM_WIDTH))                     tx_mvb_tr;

        forever begin
            rx_mvb_analysis_fifo.get(rx_mvb_tr);

            // Read information about the output port from the input transaction
            port                = rx_mvb_tr.item.data[ITEM_WIDTH + $clog2(TX_PORTS) - 1 : ITEM_WIDTH];

            // Create output transaction on a specific port
            tx_mvb_tr           = uvm_common::model_item #(uvm_logic_vector::sequence_item #(ITEM_WIDTH))::type_id::create("tx_mvb_tr");
            tx_mvb_tr.item      = uvm_logic_vector::sequence_item #(ITEM_WIDTH)::type_id::create("tx_mvb_tr_seq_it");
            tx_mvb_tr.item.data = rx_mvb_tr.item.data[ITEM_WIDTH - 1 : 0];

            tx_mvb_analysis_imp[port].write(tx_mvb_tr);
        end
    endtask
endclass
