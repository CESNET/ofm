import copy

import cocotb
from cocotb.triggers import RisingEdge
from cocotb_bus.drivers import BusDriver
from cocotb.queue import Queue


class AvstPcieDriverMaster(BusDriver):
    _signals = ["DATA", "HDR", "SOP", "EOP", "EMPTY", "VALID", "READY"]
    _optional_signals = ["PREFIX", "BAR_RANGE"]

    def __init__(self, entity, name, clock, array_idx=None):
        BusDriver.__init__(self, entity, name, clock, array_idx=array_idx)
        self._cq_q = Queue()
        self._rc_q = Queue()
        self._re = RisingEdge(self.clock)

        ms, os = self._signals, self._optional_signals
        signals = ms | os if isinstance(ms, dict) else ms + os
        for s in signals:
            if hasattr(self.bus, s) and s not in ["READY"]:
                getattr(self.bus, s).setimmediatevalue(0)

        cocotb.start_soon(self.send_transaction())

    async def write_cq(self, data, sync=True):
        self._cq_q.put_nowait((data, sync))

    async def write_rc(self, data, sync=True):
        self._rc_q.put_nowait((data, sync))

    async def send_transaction(self):
        while True:
            if self._rc_q.empty():
                if self._cq_q.empty():
                    await self._re
                    continue
                else:
                    data, sync = self._cq_q.get_nowait()
            else:
                data, sync = self._rc_q.get_nowait()

            await self._write(data, sync)

    async def _write(self, data, sync=True):
        data = copy.copy(data)

        while hasattr(self.bus, "READY") and not self.bus.READY.value:
            await self._re

        if sync:
            await self._re

        self.bus.VALID.value = 1

        for signal, value in data.items():
            if signal != "":
                getattr(self.bus, signal).value = value

        await self._re
        while hasattr(self.bus, "READY") and not self.bus.READY.value:
            await self._re

        self.bus.VALID.value = 0


class AvstPcieDriverSlave(BusDriver):
    _signals = ["VALID", "READY"]

    def __init__(self, entity, name, clock, array_idx=None):
        BusDriver.__init__(self, entity, name, clock, array_idx=array_idx)

        self.bus.READY.setimmediatevalue(1)
