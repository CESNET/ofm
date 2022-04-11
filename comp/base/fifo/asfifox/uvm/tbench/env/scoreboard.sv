//-- scoreboard.sv: Scoreboard for verification
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 


// Analysis implementations to support input from many places
`uvm_analysis_imp_decl(_mvb_rx)
`uvm_analysis_imp_decl(_mvb_tx)

// Scoreboard. Check if DUT implementation is correct.
class scoreboard #(ITEMS, ITEM_WIDTH) extends uvm_scoreboard;

    `uvm_component_utils(env::scoreboard #(ITEMS, ITEM_WIDTH))
    // Analysis components.
    uvm_analysis_imp_mvb_rx #(mvb::sequence_item #(ITEMS, ITEM_WIDTH), scoreboard #(ITEMS, ITEM_WIDTH)) analysis_imp_mvb_rx;
    uvm_analysis_imp_mvb_tx #(mvb::sequence_item #(ITEMS, ITEM_WIDTH), scoreboard #(ITEMS, ITEM_WIDTH)) analysis_imp_mvb_tx;
    //model m_model;
    mvb::sequence_item #(ITEMS, ITEM_WIDTH) fifo_content [$];
    int added_trans = 0;
    int removed_trans = 0; 
    
    // Contructor of scoreboard.
    function new(string name, uvm_component parent);
        super.new(name, parent);
        
        analysis_imp_mvb_rx = new("analysis_imp_mvb_rx", this);
        analysis_imp_mvb_tx = new("analysis_imp_mvb_tx", this);

    endfunction

    // Write rx transaction to fifo.
    virtual function void write_mvb_rx(mvb::sequence_item #(ITEMS, ITEM_WIDTH) tr);
        mvb::sequence_item #(ITEMS, ITEM_WIDTH) new_item = new();
        if(tr.SRC_RDY && tr.DST_RDY && |tr.VLD) begin
            //$write("Incomming transaction to be added: %s\n", tr.convert2string());

            new_item.copy(tr);
        
            //model.send_item(tr);
            fifo_content.push_back(new_item);

            added_trans++;
        end
    endfunction

    // Write tx transaction to fifo.
    virtual function void write_mvb_tx(mvb::sequence_item #(ITEMS, ITEM_WIDTH) tr);
       
        // Write sequence item to analysis port.
        if(tr.SRC_RDY && tr.DST_RDY && |tr.VLD) begin
            if(fifo_content.size > 0 && fifo_content[0].compare(tr)) begin
                //$write("Incomming transaction to be removed: %s\nFirst transaction in fifo %s\n", tr.convert2string(), fifo_content[0].convert2string());
                //fifo_content.pop_front();
                fifo_content.delete(0);
                removed_trans++; 
            end else begin
                `uvm_fatal(this.get_full_name(), "The fifo is empty, or the items does not match.");
            end 
        end 
    endfunction

    virtual function void report_phase(uvm_phase phase);
        $write("SCOREBOARD REPORT -----------------------------------------------\n");
        $write("Count of added items: %d \n", added_trans);
        $write("Count of removed items: %d \n", removed_trans);
        $write("Count of items inside fifo: %d \n", fifo_content.size);
        $write("END REPORT ------------------------------------------------------\n");
    endfunction

endclass
