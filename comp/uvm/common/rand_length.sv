/*
 * file       : rand_length.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: length randomization 
 * date       : 2021
 * author     : Radek Iša <isa@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/

////////////////////////////////////////////////
// CLASS WITH BOUNDS
class length_bounds;
    rand int unsigned min;
    rand int unsigned max;

    function new();
        min = 5;
        max = 10;
    endfunction

    constraint c_main {
        min <= max;
    };
endclass


class length_bounds_max extends length_bounds;
    function new();
        min = 0;
        max = 0;
    endfunction

    constraint c_bounds {
        min >= 0;
        min <= 0;
        max >= 0;
        max <= 0;
    };
endclass


class length_bounds_speed extends length_bounds;
    function new();
        min = 0;
        max = 15;
    endfunction

    constraint c_bounds {
        min >= 0;
        min <= 15;
        max >= 0;
        max <= 15;
    };
endclass

class length_bounds_mid extends length_bounds;
    function new();
        min = 15;
        max = 30;
    endfunction

    constraint c_bounds {
        min >= 15;
        min <= 30;
        max >= 15;
        max <= 30;
    };
endclass

class length_bounds_longer extends length_bounds;
    function new();
        min = 50;
        max = 100;
    endfunction

    constraint c_bounds {
        min >= 50;
        min <= 100;
        max >= 50;
        max <= 100;
    };
endclass

class length_bounds_long extends length_bounds;
    function new();
        min = 500;
        max = 1000;
    endfunction

    constraint c_bounds {
        min >= 500;
        min <= 1000;
        max >= 500;
        max <= 1000;
    };
endclass

class length_bounds_size extends length_bounds;
    int unsigned size;

    function new();
        min = 0;
        max = 0;
    endfunction

    constraint c_bounds {
        min == size;
        max == size;
    };

    function void pre_randomize();
       size = $urandom_range(15,0);
    endfunction
endclass

////////////////////////////////////////////////
// RAND VALUE
class rand_length;
    length_bounds     m_bounds;
    rand int unsigned m_value;

    constraint c_value {
        m_value inside {[m_bounds.min:m_bounds.max]};
    };

    function new();
        m_bounds = new();
    endfunction
endclass

////////////////////////////////////////////////
// RAND VALUE
class rand_length_rand extends rand_length;
    length_bounds rand_bounds[];
    int unsigned  rand_count_min = 25;
    int unsigned  rand_count_max = 500;
    int unsigned  rand_count;

    function new(length_bounds bounds_arr[] = {});
        super.new();
        if (bounds_arr.size() != 0) begin
            this.rand_bounds = bounds_arr;
        end else begin
            this.rand_bounds = new[6];
            this.rand_bounds[0] = length_bounds_max::new();
            this.rand_bounds[1] = length_bounds_speed::new();
            this.rand_bounds[2] = length_bounds_mid::new();
            this.rand_bounds[3] = length_bounds_longer::new();
            this.rand_bounds[4] = length_bounds_long::new();
            this.rand_bounds[5] = length_bounds_size::new();
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

class rand_length_stable extends rand_length;
    int unsigned  rand_count_min = 25;
    int unsigned  rand_count_max = 500;
    int unsigned  rand_count;

    function new();
        super.new();
        rand_count = 0;
    endfunction

    function void pre_randomize();
        if (rand_count == 0) begin
            int unsigned  rand_size;
            rand_count = $urandom_range(rand_count_max, rand_count_min);
            rand_size  = $urandom_range(100, 0);
            m_bounds.min = rand_size;
            m_bounds.max = rand_size;
        end else begin
            rand_count--;
        end
    endfunction
endclass


