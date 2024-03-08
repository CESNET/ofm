# drivers.py: LIIDriver
# Copyright (C) 2024 CESNET z. s. p. o.
# Author(s): Jakub Cabal <cabal@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

import random
import cocotb
from cocotb_bus.drivers import BusDriver
from cocotb.triggers import RisingEdge

class LIIDriver(BusDriver):
    _signals = ["d", "db", "sof", "eof", "rdy", "crcok", "crcvld"]

    def __init__(self, entity, name, clock, array_idx=None):
        BusDriver.__init__(self, entity, name, clock, array_idx=array_idx)
        self.clock = clock
        self._bytes = len(self.bus.d) // 8
        self._clear_control_signals()
        self.frame_cnt = 0

    def _clear_control_signals(self):
        self.bus.sof.value = 0
        self.bus.eof.value = 0
        self.bus.rdy.value = 0
        self.bus.crcvld.value = 0

    async def _send_thread(self):
        while True:
            # Sleep until we have something to send
            while not self._sendQ:
                self._pending.clear()
                await self._pending.wait()

            # Send Transaction
            await RisingEdge(self.clock)

            while self._sendQ:
                data, callback, event, kwargs = self._sendQ.popleft()

                for bb in range(0, len(data), self._bytes):
                    self._clear_control_signals()

                    self.bus.d.value = int.from_bytes(data[bb:(bb+self._bytes)], byteorder="little")

                    # SOF flag
                    if bb == 0:
                        self.bus.sof.value = 1

                    # EOF flag
                    if (bb + self._bytes) >= len(data):
                        # Move EOF flag to next word
                        if (random.randint(0, 8) > 2) and ((bb + self._bytes) == len(data)):
                            self.bus.rdy.value = 1
                            await RisingEdge(self.clock)
                            # Random idle cycle before EOF flag with zero bytes
                            if (random.randint(0, 3) < 2):
                                self._clear_control_signals()
                                await RisingEdge(self.clock)

                            # EOF flag with zero bytes
                            self._clear_control_signals()
                            self.bus.eof.value = 1
                            self.bus.db.value = 0
                        else:
                            # EOF flag with non-zero bytes
                            self.bus.eof.value = 1
                            self.bus.db.value = len(data) - bb

                    self.bus.rdy.value = 1
                    await RisingEdge(self.clock)

                    # Random idle cycles
                    for ii in range(random.randint(0, 4)):
                        self.bus.sof.value = random.randint(0, 1)
                        self.bus.eof.value = random.randint(0, 1)
                        self.bus.db.value = random.randint(0, 4)
                        self.bus.rdy.value = 0
                        await RisingEdge(self.clock)

                self._clear_control_signals()
                await RisingEdge(self.clock)
                self.bus.crcok.value = 1
                self.bus.crcvld.value = 1
                await RisingEdge(self.clock)
                self.frame_cnt += 1
                self._clear_control_signals()
