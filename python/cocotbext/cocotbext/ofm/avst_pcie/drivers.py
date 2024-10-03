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
        self._ready_latency = 27
        self.current_ready_latency = 0

        if self._ready_latency == 0:
            self._write = self._write_rl_0
        else:
            self._write = self._write_rl

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

    async def _write_rl(self, data, sync=True):
        """
        Write data on the interface when ready latency is not zero.
        """
        #Check if data can be put into interface
        if not self.bus.READY.value:
            if self.current_ready_latency == 0:
                while not self.bus.READY.value:
                    await self._re
            else:
                self.current_ready_latency -= 1
        else:
            self.current_ready_latency = self._ready_latency

        if sync:
            await self._re

        self.bus.VALID.value = 1
        for signal, value in data.items():
            if signal != "":
                getattr(self.bus, signal).value = value

        await self._re
        self.bus.VALID.value = 0

    async def _write_rl_0(self, data, sync=True):
        """
        Write data on interface when ready latency is zero
        In this case interface behaves simular to MFB
        """
        #Wait for ready signal
        while not self.bus.READY.value:
            await self._re

        if sync:
            await self._re

        self.bus.VALID.value = 1

        for signal, value in data.items():
            if signal != "":
                getattr(self.bus, signal).value = value

        await self._re
        while not self.bus.READY.value:
            await self._re

        self.bus.VALID.value = 0


class AvstPcieDriverSlave(BusDriver):
    _signals = ["VALID", "READY"]

    def __init__(self, entity, name, clock, array_idx=None):
        BusDriver.__init__(self, entity, name, clock, array_idx=array_idx)

        self.bus.READY.setimmediatevalue(1)
