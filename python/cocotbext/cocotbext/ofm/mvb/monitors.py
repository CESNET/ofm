# monitors.py: MVBMonitor
# Copyright (C) 2024 CESNET z. s. p. o.
# Author(s): Ondřej Schwarz <Ondrej.Schwarz@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

import cocotb
from cocotb_bus.monitors import BusMonitor
from cocotb.triggers import RisingEdge

class MVBProtocolError(Exception):
    pass

class MVBMonitor(BusMonitor):
    _signals = ["data", "vld", "src_rdy", "dst_rdy"]

    def __init__(self, entity, name, clock, array_idx=None) -> None:
        super().__init__(entity, name, clock, array_idx=array_idx)
        self.item_cnt = 0
        self._items = len(self.bus.vld)
        self._word_width = int(len(self.bus.data)/8) #width in bytes
        self._item_width = int(self._word_width/self._items)

    def _is_valid_word(self, signal_src_rdy, signal_dst_rdy) -> bool:
        if signal_dst_rdy is None:
            return (signal_src_rdy.value == 1)
        else:
            return (signal_src_rdy.value == 1) and (signal_dst_rdy.value == 1)

    async def _monitor_recv(self) -> None:
        """Watch the pins and reconstruct transactions."""

        # Avoid spurious object creation by recycling
        clk_re = RisingEdge(self.clock)

        while True:
            await clk_re

            if self.in_reset:
                continue
            
            if self._is_valid_word(self.bus.src_rdy, self.bus.dst_rdy):
                data_val = self.bus.data.value
                data_val.big_endian = False
                data_bytes = data_val.buff

                vld = self.bus.vld.value

                for offset in range(self._items):   
                    if (vld[self._items-offset-1]):
                        self.log.debug(f"ITEM {self.item_cnt}")
                        self.log.debug(f"recieved item: {data_bytes[offset*self._item_width:(offset+1)*self._item_width]}")
                        self.log.debug(f"word: {data_bytes}")
                        self.log.debug(f"item vld: {vld[self._items-offset-1]}")
                        self.log.debug(f"word vld: {vld}")
                        self._recv(data_bytes[offset*self._item_width:(offset+1)*self._item_width])

                        self.item_cnt += 1
