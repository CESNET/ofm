/*!
 * \file dut.sv
 * \brief Design Under Test
 * \author Lukas Kekely <kekely@cesnet.cz>
 * \date 2016
*/
/*
 * SPDX-License-Identifier: BSD-3-Clause
*/

import test_pkg::*;


module DUT (
    input logic     CLK,
    input logic     RESET,
    iMvbRx.dut      RX,
    iMvbTx.dut      TX,
    inFifox         IN_FIFOX,
    outFifox        OUT_FIFOX
);

logic FIFO_EMPTY;
logic FIFO_AEMPTY;
logic FIFO_FULL;
logic FIFO_AFULL;

    always @(*) begin 
        IN_FIFOX.DI     <= RX.DATA;
        IN_FIFOX.WR     <= RX.SRC_RDY;
        IN_FIFOX.FULL   <= FIFO_FULL;
        IN_FIFOX.AFULL  <= FIFO_AFULL;
    end

    always @(*) begin 
        OUT_FIFOX.DO        <= TX.DATA;
        OUT_FIFOX.RD        <= TX.DST_RDY;
        OUT_FIFOX.EMPTY     <= FIFO_EMPTY;
        OUT_FIFOX.AEMPTY    <= FIFO_AEMPTY;
    end

    FIFOX #(
        .ITEMS       (FIFO_ITEMS),
        .DATA_WIDTH  (ITEM_WIDTH),
        .RAM_TYPE            (RAM_TYPE),
        .DEVICE              (DEVICE),
        .ALMOST_FULL_OFFSET  (ALMOST_FULL_OFFSET),
        .ALMOST_EMPTY_OFFSET (ALMOST_EMPTY_OFFSET),
        .FAKE_FIFO           (FAKE_FIFO) 
    ) VHDL_DUT_U (
        .CLK         (CLK),
        .RESET       (RESET),
        .DI          (RX.DATA),
        .WR          (RX.SRC_RDY),
        .FULL        (FIFO_FULL),
        .AFULL       (FIFO_AFULL),
        .DO          (TX.DATA),
        .EMPTY       (FIFO_EMPTY),
        .AEMPTY      (FIFO_AEMPTY),
        .RD          (TX.DST_RDY)
    );

assign TX.VLD = 1;
assign TX.SRC_RDY = !FIFO_EMPTY;
assign RX.DST_RDY = !FIFO_FULL;
endmodule
