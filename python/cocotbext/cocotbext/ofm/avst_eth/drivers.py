import cocotb
from cocotb_bus.drivers import BusDriver
from cocotb.triggers import ClockCycles, FallingEdge, First, RisingEdge
from cocotb.result import TestFailure

import copy
import operator


class AvstEthDriver(BusDriver):
    _signals = ["data", "valid", "sop", "eop", "empty", "error"]
    # _optional_signals = ["status_valid", "status_data", "pause", "pfc"]

    def __init__(self, entity, name, clock, array_idx=None):
        BusDriver.__init__(self, entity, name, clock, array_idx=array_idx)
        self.clock = clock
        self._re = RisingEdge(self.clock)
        self._bus_width = len(self.bus.data) // 8
        self._bus_segments = len(self.bus.valid)
        self._bus_segment_width = self._bus_width // self._bus_segments
        self.clear_control_signals()

    def clear_control_signals(self):
        self.bus.valid.value = 0
        self.bus.sop.value = 0
        self.bus.eop.value = 0
        self.bus.empty.value = 0
        self.bus.error.value = 0

        self._vld = 0
        self._sop = 0
        self._eop = 0
        self._emp = 0
        self._err = 0

    def propagate_control_signals(self):
        self.bus.valid.value = self._vld
        self.bus.sop.value = self._sop
        self.bus.eop.value = self._eop
        self.bus.empty.value = self._emp
        self.bus.error.value = self._err

    async def write_packet(self, data, sync=True):
        data = copy.copy(data)
        datalen = len(data)

        if sync:
            await self._re

        while data:
            self._vld = 1

            if len(data) == datalen:
                self._sop = 1

            # TODO: ability to send 2 packets in one word
            if len(data) <= self._bus_width:
                if len(data) <= self._bus_segment_width:
                    self._eop = 1
                    self._emp = self._bus_segment_width - len(data)
                else:
                    self._eop = 2
                    self._emp = self._bus_width - len(data)
                data += [0] * (self._bus_width - len(data)) # fill the rest of the word with 0s

            self.bus.data.value = int.from_bytes(data[0:self._bus_width], byteorder="big")

            data = data[self._bus_width:]

            if sync:
                self.propagate_control_signals()
                await self._re
                self.clear_control_signals()
