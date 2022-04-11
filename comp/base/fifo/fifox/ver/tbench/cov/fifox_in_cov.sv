/*!
 * \file fifox_out_cov.sv
 * \brief Coverfage for input interface of fifox
 * \author Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>
 * \date 2016
*/
/*
 * SPDX-License-Identifier: BSD-3-Clause
*/


class fifoxInCov #(ITEM_WIDTH);
    virtual inFifox #(ITEM_WIDTH).monitor vif;

    covergroup cov_fifox_in @(vif.monitor_cb);
        
        written_data : coverpoint vif.monitor_cb.DI iff (vif.monitor_cb.WR & !vif.monitor_cb.FULL){
            option.auto_bin_max = 10;
        }
        
        written_transactions_sequence : coverpoint vif.monitor_cb.WR & !vif.monitor_cb.FULL {
            bins short   = (0 => 1 => 0);
            bins longer  = (0 => 1[*2:16]   => 0);
            bins long    = (0 => 1[*17:32]  => 0);
            bins longest = default;
        }

        wr : coverpoint vif.monitor_cb.WR {
            bins not_wr = {0};
            bins wr = {1};
        }

        afull : coverpoint vif.monitor_cb.AFULL {
            bins not_afull  = {0};
            bins afull      = {1};
        }

        
        full : coverpoint vif.monitor_cb.FULL {
            bins not_full  = {0};
            bins full      = {1};
        }

        full_write_cross : cross full, wr;


    endgroup

    function new (virtual inFifox #(ITEM_WIDTH).monitor itf);
        this.vif            = itf;
        this.cov_fifox_in   = new();
    endfunction

    function void display();
        $write("coverage %f %%\n", cov_fifox_in.get_inst_coverage());
    endfunction

endclass