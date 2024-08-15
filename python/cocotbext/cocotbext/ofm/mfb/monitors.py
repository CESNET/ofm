# monitors.py: MFBMonitor
# Copyright (C) 2024 CESNET z. s. p. o.
# Author(s): Jakub Cabal <cabal@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

import cocotb
from cocotb_bus.monitors import BusMonitor
from cocotb.triggers import RisingEdge
from cocotbext.ofm.mfb.utils import get_mfb_params, signal_unpack

class MFBProtocolError(Exception):
    pass

class MFBMonitor(BusMonitor):
    _signals = ["data", "sof_pos", "eof_pos", "sof", "eof", "src_rdy", "dst_rdy"]

    def __init__(self, entity, name, clock, array_idx=None, mfb_params=None):
        BusMonitor.__init__(self, entity, name, clock, array_idx=array_idx)

        self.frame_cnt = 0
        self._regions, self._region_size, self._block_size, self._item_width = get_mfb_params(self.bus.data, self.bus.sof_pos, self.bus.eof_pos, self.bus.sof, mfb_params)
        self._region_items = self._region_size * self._block_size
        self._sof_arr = [0] * self._regions
        self._eof_arr = [0] * self._regions
        self._sof_pos_arr = [0] * self._regions
        self._eof_pos_arr = [0] * self._regions

    def _is_valid_word(self, signal_src_rdy, signal_dst_rdy):
        if signal_dst_rdy is None:
            return (signal_src_rdy.value == 1)
        else:
            return (signal_src_rdy.value == 1) and (signal_dst_rdy.value == 1)

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

            if self._is_valid_word(self.bus.src_rdy, self.bus.dst_rdy):
                #print("valid MFB word")
                data_val = self.bus.data.value
                data_val.big_endian = False
                data_bytes = data_val.buff

                self._sof_arr = signal_unpack(self._regions, self.bus.sof)
                self._eof_arr = signal_unpack(self._regions, self.bus.eof)
                self._sof_pos_arr = signal_unpack(self._regions, self.bus.sof_pos)
                self._eof_pos_arr = signal_unpack(self._regions, self.bus.eof_pos)
                #print("sof_arr " + str(self._sof_arr))
                #print("eof_arr " + str(self._eof_arr))
                #print("sof_pos_arr " + str(self._sof_pos_arr))
                #print("eof_pos_arr " + str(self._eof_pos_arr))

                for rr in range(self._regions):
                    eof_done = False
                    rs_inx = (rr*self._region_items)
                    re_inx = (rr*self._region_items+self._region_items)
                    ee_idx = (rr*self._region_items+self._eof_pos_arr[rr]+1)
                    ss_idx = (rr*self._region_items+(self._sof_pos_arr[rr]*self._block_size))

                    #print("rs_inx " + str(rs_inx))
                    #print("re_inx " + str(re_inx))
                    #print("ee_idx " + str(ee_idx))
                    #print("ss_idx " + str(ss_idx))

                    if (self._eof_arr[rr] == 1) and (in_frame):
                        #print("Frame End")
                        in_frame = False
                        eof_done = True
                        frame += data_bytes[rs_inx:ee_idx]
                        #print("frame done " + frame.hex())
                        self._recv(frame)
                        self.frame_cnt += 1

                    frame += data_bytes[rs_inx:re_inx]
                    #print("frame middle " + frame.hex())

                    if self._sof_arr[rr] == 1:
                        #print("Frame Start")
                        if in_frame:
                            raise MFBProtocolError("Duplicate start-of-frame received on MFB bus!")
                        in_frame = True
                        frame = b""

                        if (self._eof_arr[rr] == 1) and (not eof_done):
                            #print("Frame End in single region")
                            if not in_frame:
                                raise MFBProtocolError("Duplicate end-of-frame received on MFB bus!")
                            in_frame = False
                            frame += data_bytes[ss_idx:ee_idx]
                            #print("frame done single" + frame.hex())
                            self._recv(frame)
                            self.frame_cnt += 1
                        else:
                            frame += data_bytes[ss_idx:re_inx]
                            #print("frame start " + frame.hex())
