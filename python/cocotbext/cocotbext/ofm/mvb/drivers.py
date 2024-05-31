# drivers.py: MVBDriver
# Copyright (C) 2024 CESNET z. s. p. o.
# Author(s): Ondřej Schwarz <Ondrej.Schwarz@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

import cocotb 
from cocotb_bus.drivers import BusDriver
from cocotb.triggers import RisingEdge
from cocotbext.ofm.mvb.utils import get_mvb_params

import random
import string

class MVBDriver(BusDriver):
    _signals = ["data", "vld", "src_rdy", "dst_rdy"]

    def __init__(self, entity, name, clock, array_idx=None, mvb_params=None):
        BusDriver.__init__(self, entity, name, clock, array_idx=array_idx)
        self._item_cnt = 0
        self._vld_item_cnt = 0
        self.clock = clock
        self._items = len(self.bus.vld)
        self._word_width = int(len(self.bus.data)/8) #word width in bytes
        self._item_width = int(self._word_width/self._items) #item width in bytes
        self._item_offset = 0
        self._clearControlSignals()
        self.bus.src_rdy.value = 0

        #random empty spaces
        self._cDelays, self._mode, self._delays_fill = get_mvb_params(self._items, mvb_params)

    def _fillEmptyWord(self): 
        for i in range(self._word_width):
            if self._mode == 1 or self._mode == 3:
                self._data[i] = self._delays_fill
            elif self._mode == 2:
                self._data[i] = random.randrange(0,256)
        self._vld = 0

    def _clearControlSignals(self):
        self._data = bytearray(self._word_width)
        self._vld = 0
        self._src_rdy = 0

    async def _moveItem(self):
        self._item_offset += 1

        if self._item_offset == self._items:
            await self._moveWord()
            self._item_offset = 0

    def _writeWord(self):
        self.bus.data.value = int.from_bytes(self._data, 'little')
        self.bus.vld.value = self._vld
        self.bus.src_rdy.value = self._src_rdy

    async def _moveWord(self):
        re = RisingEdge(self.clock)

        if (self._src_rdy):  
            self._writeWord()
 
        else:
            self._clearControlSignals()
            self.bus.src_rdy.value = 0
 
        while True:
            await re
            if self.bus.dst_rdy.value == 1:
                break
     
        if random.choices((0,1), weights=self._cDelays["wordDelayEn_wt"], k=1)[0]:
            for i in self._cDelays["wordDelay"]:
                self._fillEmptyWord()
                self._src_rdy = 1
                self._item_cnt += self._items
                self._writeWord()

        self._clearControlSignals()
       
    async def _sendData(self, data):            
        self.log.debug(f"ITEM {self._vld_item_cnt}:")
        self.log.debug(f"recieved item: {data}")

        self._data[self._item_offset*self._item_width:(self._item_offset+1)*self._item_width] = data   
        
        self.log.debug(f"word: {self._data}")
       
        self._vld += 1<<(self._item_cnt%self._items)
        
        self.log.debug(f"item vld: {1<<(self._item_cnt%self._items)}")
        self.log.debug(f"word vld: {self._vld}")

        self._src_rdy = 1
        
        self._item_cnt += 1
        self._vld_item_cnt += 1

        await self._moveItem()

        if random.choices((0,1), weights=self._cDelays["ivgEn_wt"], k=1)[0]:
            for i in self._cDelays["ivg"]:
                if self._mode:
                    for i in range(self._item_width):
                        if self._mode == 2:
                            self._delays_fill = random.randrange(0, 256)
                        self._data[self._item_offset*self._item_width+i] = self._delays_fill
                else:
                    self._data[self._item_offset*self._item_width:(self._item_offset+1)*self._item_width] = data
                
                self._src_rdy = 1
                self._item_cnt += 1
                await self._moveItem()

    async def _send_thread(self):
        while True:
            while not self._sendQ:
                self._pending.clear()
                await self._pending.wait()

            while self._sendQ:
                transaction, callback, event, kwargs = self._sendQ.popleft()
                assert len(transaction) == self._item_width
                await self._sendData(transaction)
                if event:
                    event.set()
                if callback:
                    callback(transaction)
            
            await self._moveWord()
            await self._moveWord()

