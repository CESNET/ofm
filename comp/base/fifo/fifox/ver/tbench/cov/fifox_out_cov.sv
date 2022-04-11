/*!
 * \file fifox_out_cov.sv
 * \brief Coverfage for output interface of fifox
 * \author Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>
 * \date 2016
*/
/*
 * SPDX-License-Identifier: BSD-3-Clause
*/


class fifoxOutCov #(ITEM_WIDTH);
    virtual outFifox #(ITEM_WIDTH).monitor vif;

    covergroup cov_fifox_out @(vif.monitor_cb);
        
        readed_data : coverpoint vif.monitor_cb.DO iff (vif.monitor_cb.RD & !vif.monitor_cb.EMPTY){
            option.auto_bin_max = 10;
        }
        
        readed_transactions_sequence : coverpoint vif.monitor_cb.RD & !vif.monitor_cb.EMPTY {
            bins short   = (0 => 1 => 0);
            bins longer  = (0 => 1[*2:16]   => 0);
            bins long    = (0 => 1[*17:32]  => 0);
            bins longest = default;
        }

        rd : coverpoint vif.monitor_cb.RD {
            bins not_read   = {0};
            bins read       = {1};
        }

        aempty : coverpoint vif.monitor_cb.AEMPTY {
            bins not_aempty  = {0};
            bins aempty      = {1};
        }

        empty : coverpoint vif.monitor_cb.EMPTY {
            bins not_empty  = {0};
            bins empty      = {1};
        }

        empty_rd_cross : cross empty, rd;

    endgroup

    function new (virtual outFifox #(ITEM_WIDTH).monitor itf);
        this.vif            = itf;
        this.cov_fifox_out   = new();
    endfunction

    function void display();
        $write("coverage %f %%\n", cov_fifox_out.get_inst_coverage());
    endfunction

endclass