/*
 * file       : interface.sv
 * Copyright (C) 2022 CESNET z. s. p. o.
 * description: General MII interface, can be used for both RX and TX
 * date       : 2022
 * author     : Oliver Gurka <xgurka00@stud.fit.vutbr.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/

interface mii_if #(CHANNELS, WIDTH) (input logic CLK);
    
    initial BYTES_ONLY : assert ((WIDTH & 7) == 0);

    localparam BYTES = WIDTH >> 3;

    logic [WIDTH - 1 : 0] DATA [CHANNELS];
    logic [BYTES - 1 : 0] CONTROL [CHANNELS];

    clocking driver_cb @(posedge CLK);
        output DATA, CONTROL;
    endclocking

    clocking monitor_cb @(posedge CLK);
        input DATA, CONTROL;
    endclocking

    modport dut_rx(input DATA, CONTROL);
    modport dut_tx(output DATA, CONTROL);

    modport monitor(clocking monitor_cb);

    modport driver(clocking driver_cb);

endinterface: mii_if
