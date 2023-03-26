#!/usr/bin/env python3
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>

import nfb
import time
import math

class DataLogger:

    # MI registers addresses
    CTRL_ADDR  = 0
    STATS_ADDR = 4
    INDEX_ADDR = 8
    SLICE_ADDR = 12
    HIST_ADDR  = 16
    VALUE_ADDR = 20

    # Statistics id
    CNTER_CNT_ID        = 0
    VALUE_CNT_ID        = 1
    MI_DATA_WIDTH_ID    = 2
    CTRLO_WIDTH_ID      = 3
    CTRLI_WIDTH_ID      = 4
    CNTER_WIDTH_ID      = 5
    VALUE_WIDTH_ID      = 6
    VALUE_EN_ID         = 7
    SUM_EXTRA_WIDTH_ID  = 8
    HIST_BOX_CNT_ID     = 9
    HIST_BOX_WIDTH_ID   = 10
    CTRLO_ID            = 11
    CTRLI_ID            = 12
    CNTER_ID            = 13
    VALUE_MIN_ID        = 14
    VALUE_MAX_ID        = 15
    VALUE_SUM_ID        = 16
    VALUE_HIST_ID       = 17

    SW_RST_BIT          = 0
    RST_DONE_BIT        = 1

    # VALUE_EN_BITS
    MIN_EN_BIT          = 0
    MAX_EN_BIT          = 1
    SUM_EN_BIT          = 2
    HIST_EN_BIT         = 3

    def __init__(self, dev="/dev/nfb0", compatible="netcope,data_logger", index=0):
        dev = nfb.open(dev)

        self.last_stat  = None
        self.last_index = None
        self.last_slice = None
        self.last_hist_addr = None

        self.comp = dev.comp_open(compatible, index)
        self.config = self.load_config()
         
    def mi_read(self, addr):
        return self.comp.read32(addr)
    
    def mi_write(self, addr, data):
        return self.comp.write32(addr, data)
    
    def main_ctrl_read(self):
        ctrl = self.mi_read(self.CTRL_ADDR)
        return {
            "sw_rst":   (ctrl & (1 << self.SW_RST_BIT))     > 0,
            "rst_done": (ctrl & (1 << self.RST_DONE_BIT))   > 0,
        }

    def rst(self):
        self.mi_write(self.CTRL_ADDR, 1 << self.SW_RST_BIT)
        self.mi_write(self.CTRL_ADDR, 0)

        tries = 1000
        i = 0
        while not (self.mi_read(self.CTRL_ADDR) & (1 << self.RST_DONE_BIT)):
            time.sleep(0.001)

            i += 1
            if i >= tries:
                print("Err: Could not reset data_logger!")
                break

    def load_slices(self, width):
        slices = math.ceil(width / self.config["MI_DATA_WIDTH"])
        value = 0
        
        for i in range(0, slices):
            if self.last_slice != i:
                self.mi_write(self.SLICE_ADDR, i)
                self.last_slice = i

            value += self.mi_read(self.VALUE_ADDR) << (i * self.config["MI_DATA_WIDTH"])

        return value
    
    def stat_read(self, stat, index=0, en_slices=True):
        if self.last_stat != stat:
            self.mi_write(self.STATS_ADDR, stat)
            self.last_stat = stat
        if self.last_index != index:
            self.mi_write(self.INDEX_ADDR, index)
            self.last_index = index

        if not en_slices:
            if self.last_slice != 0:
                self.mi_write(self.SLICE_ADDR, 0)
                self.last_slice = 0
            return self.mi_read(self.VALUE_ADDR)

        if stat == self.CTRLO_ID:
            width = self.config["CTRLO_WIDTH"]
        elif stat == self.CTRLI_ID:
            width = self.config["CTRLI_WIDTH"]
        elif stat == self.CNTER_ID:
            width = self.config["CNTER_WIDTH"]
        elif stat in (self.VALUE_MIN_ID, self.VALUE_MAX_ID):
            width = self.config["VALUE_WIDTH"][index]
        elif stat == self.VALUE_SUM_ID:
            width = self.config["VALUE_WIDTH"][index] + self.config["SUM_EXTRA_WIDTH"][index]
        elif stat == self.VALUE_HIST_ID:
            width = self.config["HIST_BOX_WIDTH"][index]
        else:
            width = self.config["MI_DATA_WIDTH"]

        return self.load_slices(width)
    
    def hist_read(self, index, addr):
        if self.last_stat != self.VALUE_HIST_ID:
            self.mi_write(self.STATS_ADDR, self.VALUE_HIST_ID)
            self.last_stat = self.VALUE_HIST_ID
        if self.last_index != index:
            self.mi_write(self.INDEX_ADDR, index)
            self.last_index = index
        if self.last_hist_addr != addr:
            self.mi_write(self.HIST_ADDR, addr)
            self.last_hist_addr = addr

        width = self.config["HIST_BOX_WIDTH"][index]
        return self.load_slices(width)

    def load_config(self):
        config = { }
        config["CNTER_CNT"]         = self.stat_read(self.CNTER_CNT_ID    , en_slices=False)
        config["VALUE_CNT"]         = self.stat_read(self.VALUE_CNT_ID    , en_slices=False)
        config["MI_DATA_WIDTH"]     = self.stat_read(self.MI_DATA_WIDTH_ID, en_slices=False)
        config["CTRLO_WIDTH"]       = self.stat_read(self.CTRLO_WIDTH_ID  , en_slices=False)
        config["CTRLI_WIDTH"]       = self.stat_read(self.CTRLI_WIDTH_ID  , en_slices=False)
        config["CNTER_WIDTH"]       = self.stat_read(self.CNTER_WIDTH_ID  , en_slices=False)

        config["VALUE_WIDTH"]       = []
        config["VALUE_EN"]          = []
        config["SUM_EXTRA_WIDTH"]   = []
        config["HIST_BOX_CNT"]      = []
        config["HIST_BOX_WIDTH"]    = []

        for i in range(0, config["VALUE_CNT"]):
            en_parsed = { }
            en = self.stat_read(self.VALUE_EN_ID, i, en_slices=False)
            en_parsed["MIN"]  = ((en & 0b0001) > 0)
            en_parsed["MAX"]  = ((en & 0b0010) > 0)
            en_parsed["SUM"]  = ((en & 0b0100) > 0)
            en_parsed["HIST"] = ((en & 0b1000) > 0)

            config["VALUE_EN"       ].append(en_parsed)
            config["VALUE_WIDTH"    ].append(self.stat_read(self.VALUE_WIDTH_ID    , i, en_slices=False))
            config["SUM_EXTRA_WIDTH"].append(self.stat_read(self.SUM_EXTRA_WIDTH_ID, i, en_slices=False))
            config["HIST_BOX_CNT"   ].append(self.stat_read(self.HIST_BOX_CNT_ID   , i, en_slices=False))
            config["HIST_BOX_WIDTH" ].append(self.stat_read(self.HIST_BOX_WIDTH_ID , i, en_slices=False))

        return config
    
    def load_ctrl(self, out):
        id    = self.CTRLO_ID if out else self.CTRLI_ID
        return self.stat_read(id, 0)
    
    def set_ctrlo(self, val):
        mi_width = self.config["MI_DATA_WIDTH"]

        if self.last_stat != self.CTRLO_ID:
            self.mi_write(self.STATS_ADDR, self.CTRLO_ID)
            self.last_stat = self.CTRLO_ID
        if self.last_index != 0:
            self.mi_write(self.INDEX_ADDR, 0)
            self.last_index = 0
        
        slices = math.ceil(self.config["CTRLO_WIDTH"] / mi_width)
        for i in range(0, slices):
            if self.last_slice != 0:
                self.mi_write(self.SLICE_ADDR, i)
                self.last_slice = i

            slice = self.get_bits(val, mi_width, i * mi_width)
            self.mi_write(self.VALUE_ADDR, slice)

    def load_cnter(self, index):
        return self.stat_read(self.CNTER_ID, index)
    
    def load_value(self, index):
        val = {}
        if self.config["VALUE_EN"][index]["MIN"]:
            val["min"] = self.stat_read(self.VALUE_MIN_ID, index)
        if self.config["VALUE_EN"][index]["MAX"]:
            val["max"] = self.stat_read(self.VALUE_MAX_ID, index)
        if self.config["VALUE_EN"][index]["SUM"]:
            val["sum"] = self.stat_read(self.VALUE_SUM_ID, index)
        val["cnt"]     = self.stat_read(self.CNTER_ID, index + self.config["CNTER_CNT"])
        if self.config["VALUE_EN"][index]["HIST"]:
            val["hist"] = []
            for b in range(0, self.config["HIST_BOX_CNT"][index]):
                val["hist"].append(self.hist_read(index, b))

        return val
    
    def get_bits(self, val, width, pos):
        binary = bin(val)[2:]
        end   = - pos
        start = end - width
        if end == 0:
            end = None
        cut = binary[start:end]
        if len(cut) == 0:
            return 0 
        else:
            return int(cut, 2)
    

if __name__ == '__main__':
    logger = DataLogger()
    print(logger.config)
