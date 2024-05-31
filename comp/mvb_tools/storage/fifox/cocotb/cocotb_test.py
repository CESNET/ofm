# cocotb_test.py:
# Copyright (C) 2024 CESNET z. s. p. o.
# Author(s): Ondřej Schwarz <Ondrej.Schwarz@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

import itertools

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from cocotbext.ofm.mvb.drivers import MVBDriver
from cocotbext.ofm.mvb.monitors import MVBMonitor
from cocotbext.ofm.ver.generators import *
from cocotb_bus.drivers import BitDriver
from cocotb_bus.scoreboard import Scoreboard

class testbench():
    def __init__(self, dut, debug=False):
        self.dut = dut
        self.stream_in = MVBDriver(dut, "RX", dut.CLK)
        self.backpressure = BitDriver(dut.TX_DST_RDY, dut.CLK)
        self.stream_out = MVBMonitor(dut, "TX", dut.CLK)

        # Create a scoreboard on the stream_out bus
        self.pkts_sent = 0
        self.expected_output = []
        self.scoreboard = Scoreboard(dut)
        self.scoreboard.add_interface(self.stream_out, self.expected_output)

        #self.stream_in_recovered = AvalonSTMonitor(dut, "stream_in", dut.clk, callback=self.model) 

        if debug:
            self.stream_in.log.setLevel(cocotb.logging.DEBUG)
            self.stream_out.log.setLevel(cocotb.logging.DEBUG)

    def model(self, transaction):
        """Model the DUT based on the input transaction"""
        self.expected_output.append(transaction)
        self.pkts_sent += 1

    async def reset(self):
        self.dut.RESET.value = 1
        await ClockCycles(self.dut.CLK, 2)
        self.dut.RESET.value = 0
        await RisingEdge(self.dut.CLK)

@cocotb.test()
async def run_test(dut, pkt_count=10000, item_width=1):
    # Start clock generator
    cocotb.start_soon(Clock(dut.CLK, 5, units='ns').start())
    tb = testbench(dut)
    await tb.reset()
    tb.backpressure.start((1, i % 5) for i in itertools.count())

    for transaction in random_packets(item_width, item_width, pkt_count):
        tb.model(transaction)
        cocotb.log.debug(f"generated transaction: {transaction.hex()}")
        tb.stream_in.append(transaction)

    last_num = 0

    while (tb.stream_out.item_cnt < pkt_count):
        if (tb.stream_out.item_cnt // 1000) > last_num:
            last_num = tb.stream_out.item_cnt // 1000
            cocotb.log.info(f"Number of transactions processed: {tb.stream_out.item_cnt}/{pkt_count}")
        await ClockCycles(dut.CLK, 100)
 
    raise tb.scoreboard.result
