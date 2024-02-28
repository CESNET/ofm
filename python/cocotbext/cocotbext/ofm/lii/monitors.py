# monitors.py: LIIMonitor
# Copyright (C) 2024 CESNET z. s. p. o.
# Author(s): Jakub Cabal <cabal@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

import cocotb
from cocotb_bus.monitors import BusMonitor
from cocotb.triggers import RisingEdge

class LIIProtocolError(Exception):
    pass

class LIIMonitor(BusMonitor):
    _signals = ["d", "db", "sof", "eof", "rdy"]

    def __init__(self, entity, name, clock, array_idx=None):
        BusMonitor.__init__(self, entity, name, clock, array_idx=array_idx)
        self.clock = clock
        self.frame_cnt = 0

    async def _monitor_recv(self):
        """Watch the pins and reconstruct transactions."""

        # Avoid spurious object creation by recycling
        clkedge = RisingEdge(self.clock)
        frame = b""
        in_frame = False

        while True:
            await clkedge

            if self.in_reset:
                continue

            if self.bus.rdy.value == 0:
                #if in_frame:
                #    raise LIIProtocolError("Invalid gap inside frame on LII bus!")
                continue

            db_val = self.bus.db.value
            d_val = self.bus.d.value
            d_val.big_endian = False
            d_bytes = d_val.buff

            if self.bus.sof.value == 1:
                if in_frame:
                    raise LIIProtocolError("Duplicate start-of-frame received on LII bus!")

                in_frame = True
                frame = b""

            if self.bus.eof.value == 1:
                if not in_frame:
                    raise LIIProtocolError("Duplicate end-of-frame received on LII bus!")
                in_frame = False
                frame += d_bytes[:db_val]

                self._recv(frame)
                self.frame_cnt += 1
                continue
            
            frame += d_bytes
