//-- monitor.sv: Mfb monitor
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 

// Definition of mfb monitor
class monitor #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) extends uvm_monitor;

    // ------------------------------------------------------------------------
    // Registration of agent to databaze
    `uvm_component_param_utils(mfb::monitor #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH))

    // ------------------------------------------------------------------------
    // Parameters
    localparam ITEM_CNT = REGIONS * REGION_SIZE * BLOCK_SIZE;

    // ------------------------------------------------------------------------
    // Variables
    sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH) si;

    // ------------------------------------------------------------------------
    // Reference to the virtual interface
    virtual mfb_if #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH).monitor vif;
    
    // ------------------------------------------------------------------------
    // Analysis port used to send transactions to all connected components.
    uvm_analysis_port #(sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH)) analysis_port;

    // ------------------------------------------------------------------------
    // Constructor
    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // ------------------------------------------------------------------------
    // Functions
    function void build_phase(uvm_phase phase);
        analysis_port = new("analysis port", this);
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(vif.monitor_cb);

            if (vif.monitor_cb.RESET == 0) begin
                si = sequence_item #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH)::type_id::create("si");
                si.SRC_RDY  = vif.monitor_cb.SRC_RDY;
                si.DST_RDY  = vif.monitor_cb.DST_RDY;

                for (int unsigned it = 0; it < REGIONS; it++) begin
                    si.SOF[it]      = vif.monitor_cb.SOF[it];
                    si.EOF[it]      = vif.monitor_cb.EOF[it];

                    si.ITEMS[it]   = vif.monitor_cb.DATA[(it+1)*REGION_SIZE*BLOCK_SIZE*ITEM_WIDTH -1 -: REGION_SIZE*BLOCK_SIZE*ITEM_WIDTH];
                    si.META[it]    = vif.monitor_cb.META[(it+1)*META_WIDTH                        -1 -: META_WIDTH];
                    si.SOF_POS[it] = vif.monitor_cb.SOF_POS[(it+1)*$clog2(REGION_SIZE)            -1 -: $clog2(REGION_SIZE)];
                    si.EOF_POS[it] = vif.monitor_cb.EOF_POS[(it+1)*$clog2(REGION_SIZE*BLOCK_SIZE) -1 -: $clog2(REGION_SIZE*BLOCK_SIZE)];
                end

                // Write sequence item to analysis port.
                analysis_port.write(si);
            end
        end
    endtask

endclass
