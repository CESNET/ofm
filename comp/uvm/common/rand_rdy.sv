/*
 * file       : rand_rdy.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: bound to sequencer for generating spaces 
 * date       : 2021
 * author     : Radek Iša <isa@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/

////////////////////////////////////////////////
// CLASS WITH BOUNDS
class rdy_bounds;
    rand int unsigned one;
    rand int unsigned zero;

    function new();
        one  = 10;
        zero = 5;
    endfunction
endclass

class rdy_bounds_full extends rdy_bounds;
    function new();
        one = 100;
        zero = 0;
    endfunction

    constraint c_bounds {
        one  == 100;
        zero == 0;
    };
endclass

class rdy_bounds_speed extends rdy_bounds;
    function new();
        one  = 90;
        zero = 10;
    endfunction

    constraint c_bounds {
        one  <= 100;
        one  >= 90;
        zero <= 10;
        zero >= 0;
    };
endclass

class rdy_bounds_mid extends rdy_bounds;
    function new();
        one  = 70;
        zero = 30;
    endfunction

    constraint c_bounds {
        one  <= 70;
        one  >= 30;
        zero <= 70;
        zero >= 30;
    };
endclass

class rdy_bounds_low extends rdy_bounds;
    function new();
        one  = 50;
        zero = 50;
    endfunction

    constraint c_bounds {
        one  <= 70;
        one  >= 30;
        zero <= 70;
        zero >= 30;
    };
endclass

class rdy_bounds_stop extends rdy_bounds;
    function new();
        one  = 0;
        zero = 100;
    endfunction

    constraint c_bounds {
        one  == 0;
        zero == 100;
    };
endclass

////////////////////////////////////////////////
// RAND VALUE
class rand_rdy;
    rdy_bounds   m_bounds;
    rand logic   m_value;

    constraint c_value {
        m_value dist {1'b1 :/ m_bounds.one, 1'b0 :/ m_bounds.zero};
    };

    function new();
        m_bounds       = new();
    endfunction
endclass


class rand_rdy_rand extends rand_rdy;
    rdy_bounds   rand_bounds[];
    int unsigned rand_count_min = 25;
    int unsigned rand_count_max = 500;
    int unsigned rand_count;

    function new(rdy_bounds bounds_arr[] = {});
        super.new();
        if (bounds_arr.size() != 0) begin
            this.rand_bounds = bounds_arr;
        end else begin
            this.rand_bounds = new[5];
            this.rand_bounds[0] = rdy_bounds_full::new();
            this.rand_bounds[1] = rdy_bounds_speed::new();
            this.rand_bounds[2] = rdy_bounds_mid::new();
            this.rand_bounds[3] = rdy_bounds_low::new();
            this.rand_bounds[4] = rdy_bounds_stop::new();
        end
        rand_count = 0;
    endfunction

    function void pre_randomize();
        if (rand_count == 0) begin
            int unsigned index;
            rand_count = $urandom_range(rand_count_max, rand_count_min);
            index = $urandom_range(rand_bounds.size()-1, 0);
            void'(rand_bounds[index].randomize());
            m_bounds = rand_bounds[index];
        end else begin
            rand_count--;
        end
    endfunction
endclass


class rand_rdy_swap extends rand_rdy;
    int unsigned ones_count;
    int unsigned zeros_count;
    int unsigned ones_active;
    int unsigned zeros_active;

    function new(int unsigned ones = 32, int unsigned zeros = 16);
        ones_count   = ones;
        zeros_count  = zeros;
        ones_active  = 0;
        zeros_active = 0;
    endfunction

    function void pre_randomize();
        if (ones_active == 0 && zeros_active == 0) begin
            zeros_active = zeros_count;
            ones_active  = ones_count;
        end

        if (ones_active != 0) begin
            ones_active--;
            m_bounds.one  = 1;
            m_bounds.zero = 0;
        end else if (zeros_active != 0) begin
            zeros_active--;
            m_bounds.one  = 0;
            m_bounds.zero = 1;
        end else begin
            m_bounds.one  = 1;
            m_bounds.zero = 1;
        end

    endfunction
endclass

