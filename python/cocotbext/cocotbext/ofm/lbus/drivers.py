import cocotb
from cocotb_bus.drivers import BusDriver
from cocotb.triggers import ClockCycles, FallingEdge, First, RisingEdge
from cocotb.result import TestFailure

import copy
import operator

#def byte_deserialize(data):
#    return reduce(operator.or_, [(data[i] & 0xff) << (8*i) for i in range(len(data))])


class LBusDriver(BusDriver):
    _signals = ["data", "ena", "sop", "eop", "err", "mty"]

    def __init__(self, entity, name, clock, array_idx=None):
        BusDriver.__init__(self, entity, name, clock, array_idx=array_idx)
        self.clock = clock
        self._segments = len(self.bus.data)
        self._next_segment = 0
        self.clear_control_signals()

    def clear_control_signals(self):
        self.bus.sop.value = 0
        self.bus.eop.value = 0
        self.bus.ena.value = 0
        self.bus.err.value = 0

        for i in range(self._segments):
            self.bus.mty[i].value = 0

        self._ena = 0
        self._sop = 0
        self._eop = 0
        self._mty = [0] * self._segments

    def propagate_control_signals(self):
        self.bus.ena.value = self._ena
        self.bus.sop.value = self._sop
        self.bus.eop.value = self._eop
        for i in range(self._segments):
            self.bus.mty[i].value = self._mty[i]

    @cocotb.coroutine
    async def write_packet(self, data, sync=True):
        orig_data = data
        data = copy.copy(data)
        datalen = len(data)

        if sync:
            await RisingEdge(self.clock)

        while data:
            i = self._next_segment

            self._ena |= 1 << i
            if len(data) == datalen:
                self._sop |= 1 << i

            if len(data) <= 16:
                self._eop |= 1 << i
                self._mty[i] = 16 - len(data)
                data += [0] * (16 - len(data))

            self.bus.data[i].value = int.from_bytes(data[0:16], byteorder="big")

            data = data[16:]
            self._next_segment = (self._next_segment + 1) % self._segments

            if self._next_segment == 0 or (not data and sync):
                self.propagate_control_signals()
                await RisingEdge(self.clock)
                self.clear_control_signals()
