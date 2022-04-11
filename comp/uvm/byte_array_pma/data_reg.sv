/*
 * file       : data_reg.sv
 * description: PMA data_reg
 * date       : 2021
 * author     : Daniel Kriz <xkrizd01@vutbr.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (C) 2021 CESNET z. s. p. o.
*/

class data_reg;
    int unsigned it = 0;
    logic [57 : 0] scramble_reg = 58'h0;
    logic data_vld = 0;
endclass
