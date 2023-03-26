#!/usr/bin/env python3
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>

import nfb
import time
import sys
import math
import argparse

from mem_logger.mem_logger import MemLogger

class MemTester():

    # Mem_tester registers
    CTRL_IN_REG             = 0x000000
    CTRL_OUT_REG            = 0x000004
    ERR_CNT_REG             = 0x000008
    BURST_CNT_REG           = 0x00000C
    ADDR_LIM_REG            = 0x000010
    REFRESH_PERIOD_REG      = 0x000014
    DEF_REFRESH_PERIOD_REG  = 0x000018

    # CTRL OUT BITS
    TEST_DONE_BIT           = 0
    TEST_SUCCESS_BIT        = 1
    ECC_ERR_BIT             = 2
    CALIB_SUCCESS_BIT       = 3
    CALIB_FAIL_BIT          = 4
    MAIN_AMM_READY_BIT      = 5

    # CTRL IN BITS
    RESET_BIT               = 0
    RESET_EMIF_BIT          = 1
    RUN_TEST_BIT            = 2
    AMM_GEN_EN_BIT          = 3
    RANDOM_ADDR_EN_BIT      = 4
    ONLY_ONE_SIMULT_READ_BIT= 5
    AUTO_PRECHARGE_REQ_BIT  = 6

    # AMM_GEN registers
    AMM_GEN_BASE            = 0x00040
    AMM_GEN_CTRL_REG        = AMM_GEN_BASE + 0x000000
    AMM_GEN_ADDR_REG        = AMM_GEN_BASE + 0x000004
    AMM_GEN_SLICE_REG       = AMM_GEN_BASE + 0x000008
    AMM_GEN_DATA_REG        = AMM_GEN_BASE + 0x00000C
    AMM_GEN_BURST_REG       = AMM_GEN_BASE + 0x000010

    # AMM_GEN CTRL REG bits
    MEM_WR_BIT              = 0
    MEM_RD_BIT              = 1
    BUFF_VLD_BIT            = 2
    AMM_READY_BIT           = 3

    def __init__(self):
        self.dev = None

    def compatible_cnt(self, dev="/dev/nfb0", compatible="netcope,mem_tester"):
        if self.dev is None:
            self.dev = nfb.open(dev)
        nodes = self.dev.fdt_get_compatible(compatible)
        return len(nodes)

    def open(self, dev="/dev/nfb0", compatible="netcope,mem_tester", index=0, mem_logger=None):
        if mem_logger is None:
            mem_logger = MemLogger(index=index)

        if self.dev is None:
            self.dev = nfb.open(dev)
        self.comp = self.dev.comp_open(compatible, index)

        self.mem_logger = mem_logger
        self.last_test_config = None

    def mi_read(self, addr):
        return self.comp.read32(addr)
    
    def mi_write(self, addr, data):
        return self.comp.write32(addr, data)
    
    def mi_set_bit(self, addr, bit):
        old = self.mi_read(addr)
        self.mi_write(addr, old | (1 << bit))

    def mi_clear_bit(self, addr, bit):
        old = self.mi_read(addr)
        self.mi_write(addr, old & (~(1 << bit)))
   
    def mi_toggle(self, addr, bit):
        self.mi_set_bit(addr, bit)
        self.mi_clear_bit(addr, bit)

    def mi_wait_bit(self, addr, bit, timeout=5, delay=0.01):
        t = 0
        while t < timeout:
            data = self.mi_read(addr)
            if (data >> bit) & 1:
                return True
            else:
                t += delay
                time.sleep(delay)

        return False
    
    def load_status(self):
        status = { }

        ctrlo = self.mi_read(self.CTRL_OUT_REG)
        status["test_done"]             = (ctrlo >> self.TEST_DONE_BIT)       & 1
        status["test_succ"]             = (ctrlo >> self.TEST_SUCCESS_BIT)    & 1
        status["ecc_err_occ"]           = (ctrlo >> self.ECC_ERR_BIT)         & 1
        status["calib_succ"]            = (ctrlo >> self.CALIB_SUCCESS_BIT)   & 1
        status["calib_fail"]            = (ctrlo >> self.CALIB_FAIL_BIT)      & 1
        status["amm_ready"]             = (ctrlo >> self.MAIN_AMM_READY_BIT)  & 1

        ctrli = self.mi_read(self.CTRL_IN_REG)
        status["rst"]                   = (ctrli >> self.RESET_BIT)                 & 1
        status["rst_emif"]              = (ctrli >> self.RESET_EMIF_BIT)            & 1
        status["run_test"]              = (ctrli >> self.RUN_TEST_BIT)              & 1
        status["amm_gen_en"]            = (ctrli >> self.AMM_GEN_EN_BIT)            & 1
        status["random_addr_en"]        = (ctrli >> self.RANDOM_ADDR_EN_BIT)        & 1
        status["one_simult_read"]       = (ctrli >> self.ONLY_ONE_SIMULT_READ_BIT)  & 1
        status["auto_precharge"]        = (ctrli >> self.AUTO_PRECHARGE_REQ_BIT)    & 1

        status["err_cnt"]               = self.mi_read(self.ERR_CNT_REG)
        status["burst_cnt"]             = self.mi_read(self.BURST_CNT_REG)
        status["addr_lim"]              = self.mi_read(self.ADDR_LIM_REG)
        status["refr_period_ticks"]     = self.mi_read(self.REFRESH_PERIOD_REG)
        status["def_refr_period_ticks"] = self.mi_read(self.DEF_REFRESH_PERIOD_REG)
        
        return status
    
    def status_to_str(self, status):
        res = ""
        res += f"Mem_tester status:\n"
        res += f"------------------\n"
        res += f"control register:\n"
        res += f"  -- output flags --\n"
        res += f"  test done                    {status['test_done']}\n"
        res += f"  test success                 {status['test_succ']}\n"
        res += f"  ecc error occurred           {status['ecc_err_occ']}\n"
        res += f"  calibration successful       {status['calib_succ']}\n"
        res += f"  calibration failed           {status['calib_fail']}\n"
        res += f"  memory ready                 {status['amm_ready']}\n"
        res += f"  -- input flags --\n"
        res += f"  reset                        {status['rst']}\n"
        res += f"  reset memory controller      {status['rst_emif']}\n"
        res += f"  run test                     {status['run_test']}\n"
        res += f"  manual access                {status['amm_gen_en']}\n"
        res += f"  random addressing            {status['random_addr_en']}\n"
        res += f"  only one simultaneous read   {status['one_simult_read']}\n"
        res += f"  auto precharge               {status['auto_precharge']}\n"
        res += f"error count                    {status['err_cnt']}\n"
        res += f"burst count                    {status['burst_cnt']}\n"
        res += f"address limit                  {status['addr_lim']}\n"
        res += f"refresh period [ticks]         {status['refr_period_ticks']}\n"
        res += f"default refresh period [ticks] {status['def_refr_period_ticks']}\n"
        return res
    
    def rst(self, emif=True):
        self.mi_toggle(self.CTRL_IN_REG, self.RESET_BIT)
        if emif:
            self.mi_toggle(self.CTRL_IN_REG, self.RESET_EMIF_BIT)

        if not self.mi_wait_bit(self.CTRL_OUT_REG, self.MAIN_AMM_READY_BIT):
            print("Reset failed (MEM_READY was not set)", file=sys.stderr)
            return False
        return True

    def execute_test(self):
        self.mi_toggle(self.CTRL_IN_REG, self.RUN_TEST_BIT)
        if not self.mi_wait_bit(self.CTRL_OUT_REG, self.TEST_DONE_BIT, timeout=60):
            print("Test timeout (TEST_DONE was not set)", file=sys.stderr)

    def config_test(self, 
        rand_addr           = False,
        burst_cnt           = 4,
        addr_lim_scale      = 1.0,
        only_one_simult_read= False,
        latency_to_first    = False,
        auto_precharge      = False,
        refresh_period      = None,
    ):
        if burst_cnt > 2 ** self.mem_logger.config["MEM_BURST_WIDTH"] - 1:
            print(f"Burst count {burst_cnt} is too large", file=sys.stderr)
            return

        self.rst(False)
        self.mem_logger.rst()
        self.mi_write(self.BURST_CNT_REG, burst_cnt)

        ctrli = 0
        if rand_addr:
            ctrli += (1 << self.RANDOM_ADDR_EN_BIT)
        if only_one_simult_read:
            ctrli += (1 << self.ONLY_ONE_SIMULT_READ_BIT)
        if auto_precharge:
            ctrli += (1 << self.AUTO_PRECHARGE_REQ_BIT)
        self.mi_write(self.CTRL_IN_REG, ctrli)

        addr_lim = 0
        max_addr = 2 ** self.mem_logger.config["MEM_ADDR_WIDTH"] * addr_lim_scale
        if addr_lim_scale >= 1.0:
            max_addr -= 2 * burst_cnt
        addr_lim = int((max_addr // burst_cnt) * burst_cnt)
        self.mi_write(self.ADDR_LIM_REG, addr_lim)

        if latency_to_first:
            self.mem_logger.set_config(latency_to_first=True)

        if refresh_period is None:
            refresh_period = self.load_status()["def_refr_period_ticks"]
        self.mi_write(self.REFRESH_PERIOD_REG, refresh_period)

        self.last_test_config = {
            "rand_addr":            rand_addr,
            "burst_cnt":            burst_cnt,
            "addr_lim_scale":       addr_lim_scale,
            "only_one_simult_read": only_one_simult_read,
            "latency_to_first":     latency_to_first,
            "auto_precharge":       auto_precharge,
            "refresh_period":       refresh_period,
        }

    def check_test_result(self, config, status, stats):
        errs = ""
        if status["err_cnt"] != 0 and not config["rand_addr"]:
            errs += f"{status['err_cnt']} words were wrong\n"
        if status["ecc_err_occ"]:
            errs += f"ECC error occurred\n"
        if stats["rd_req_words"] != stats["rd_resp_words"]:
            errs += f"{stats['rd_req_words'] - stats['rd_resp_words']} words were not received\n"
        if not status["test_succ"] and errs == "" and not config["rand_addr"]:
            errs += f"Unknown error occurred\n"
        return errs

    def get_test_result(self):
        config = self.last_test_config
        status = self.load_status()
        stats = self.mem_logger.load_stats()
        errs = self.check_test_result(config, status, stats)
        return config, status, stats, errs
   
    def test_result_to_str(self, config, status, stats, errs):
        res = ""
        if errs == "":
            res += "|| ------------------- ||\n" 
            res += "|| TEST WAS SUCCESSFUL ||\n" 
            res += "|| ------------------- ||\n" 
        else:
            res += "|| ----------- ||\n" 
            res += "|| TEST FAILED ||\n" 
            res += "|| ----------- ||\n" 
            res += "\nErrors:\n" 
            res += errs
        res += "\n" 
        res += self.mem_logger.stats_to_str(stats)
        return res

    def amm_gen_set_buff(self, burst, data):
        prev_addr = self.mi_read(self.AMM_GEN_ADDR_REG)
        mi_width  = self.mem_logger.config["MI_DATA_WIDTH"]
        slices    = math.ceil(self.mem_logger.config["MEM_DATA_WIDTH"] / mi_width)

        for s in range(0, slices):
            slice = self.mem_logger.get_bits(data, mi_width, mi_width * s)
            self.mi_write(self.AMM_GEN_ADDR_REG, burst)
            self.mi_write(self.AMM_GEN_SLICE_REG, s)
            self.mi_write(self.AMM_GEN_DATA_REG, slice)
        
        self.mi_write(self.AMM_GEN_ADDR_REG, prev_addr)

    def amm_gen_get_buff(self):
        mi_width  = self.mem_logger.config["MI_DATA_WIDTH"]
        slices    = math.ceil(self.mem_logger.config["MEM_DATA_WIDTH"] / mi_width)
        prev_addr = self.mi_read(self.AMM_GEN_ADDR_REG)
        burst     = self.mi_read(self.AMM_GEN_BURST_REG)

        data = []
        for b in range(0, burst):
            val = 0
            for s in range(0, slices):
                self.mi_write(self.AMM_GEN_ADDR_REG, b)
                self.mi_write(self.AMM_GEN_SLICE_REG, s)
                slice = self.mi_read(self.AMM_GEN_DATA_REG)
                val += slice << (s * mi_width)
            data.append(val)
        
        self.mi_write(self.AMM_GEN_ADDR_REG, prev_addr)
        return data

    def amm_gen_set_burst(self, burst):
        self.mi_write(self.AMM_GEN_BURST_REG, burst)

    def amm_gen_write(self, addr):
        self.mi_write(self.AMM_GEN_ADDR_REG, addr)
        self.mi_set_bit(self.CTRL_IN_REG, self.AMM_GEN_EN_BIT)
        self.mi_toggle(self.AMM_GEN_CTRL_REG, self.MEM_WR_BIT)
        self.mi_clear_bit(self.CTRL_IN_REG, self.AMM_GEN_EN_BIT)

    def amm_gen_read(self, addr):
        self.mi_write(self.AMM_GEN_ADDR_REG, addr)
        self.mi_set_bit(self.CTRL_IN_REG, self.AMM_GEN_EN_BIT)
        self.mi_toggle(self.AMM_GEN_CTRL_REG, self.MEM_RD_BIT)
        self.mi_clear_bit(self.CTRL_IN_REG, self.AMM_GEN_EN_BIT)

    def amm_gen_to_str(self):
        ctrl  = self.mi_read(self.AMM_GEN_CTRL_REG)
        addr  = self.mi_read(self.AMM_GEN_ADDR_REG)
        slice = self.mi_read(self.AMM_GEN_SLICE_REG)
        burst = self.mi_read(self.AMM_GEN_BURST_REG)
        data  = self.mi_read(self.AMM_GEN_DATA_REG)

        res =  f"Amm_gen status:\n"
        res += f"--------------\n"
        res += f"control register:\n"
        res += f"  memory write                 {(ctrl >> self.MEM_WR_BIT) & 1}\n"
        res += f"  memory read                  {(ctrl >> self.MEM_RD_BIT) & 1}\n"
        res += f"  buffer vld                   {(ctrl >> self.BUFF_VLD_BIT) & 1}\n"
        res += f"  memory ready                 {(ctrl >> self.AMM_READY_BIT) & 1}\n"
        res += f"address                        {addr}\n"
        res += f"slice                          {slice}\n"
        res += f"burst                          {burst}\n"
        res += f"data                           {data}\n"
        return res

def parseParams():
    parser = argparse.ArgumentParser(description = 
        """mem_tester control script""",
        #formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )

    access = parser.add_argument_group('card access arguments')
    access.add_argument('-d', '--device', default='/dev/nfb0', metavar='device', help = """device with target FPGA card.""")
    access.add_argument('-c', '--comp', metavar='compatible', default='netcope,mem_tester', help = """mem_tester compatible inside DevTree.""")
    access.add_argument('-C', '--logger-comp', metavar='compatible', default='netcope,mem_logger', help = """mem_logger compatible inside DevTree.""")
    access.add_argument('-i', '--index',        type=int, metavar='index', default=0, help = """mem_tester index inside DevTree.""")
    access.add_argument('-I', '--logger-index', type=int, metavar='index', default=None, help = """mem_logger index inside DevTree.""")

    common = parser.add_argument_group('common arguments')
    common.add_argument('-p', '--print', action='store_true', help = """print registers""")
    common.add_argument('--rst', action='store_true', help = """reset mem_tester and mem_logger""")
    common.add_argument('--rst-tester', action='store_true', help = """reset mem_tester""")
    common.add_argument('--rst-logger', action='store_true', help = """reset mem_logger""")
    common.add_argument('--rst-emif',   action='store_true', help = """reset memory driver""")

    test = parser.add_argument_group('test related arguments')
    #test.add_argument('-t', '--test', action='store_true', help = """run test""")
    test.add_argument('-r', '--rand', action='store_true', help = """use random indexing during test""")
    test.add_argument('-b', '--burst', default=4, type=int, help = """burst count during test""")
    test.add_argument('-s', '--scale', default=1.0, type=float, help = """tested address space (1.0 = whole)""")
    test.add_argument('-o', '--one-simult', action='store_true', help = """use only one simultaneous read during test""")
    test.add_argument('-f', '--to-first', action='store_true', help = """measure latency to the first received word""")
    test.add_argument('--auto-precharge',  action='store_true', help = """use auto precharge during test""")
    test.add_argument('--refresh', default=None, type=int, help = """set refresh period in ticks""")

    other = parser.add_argument_group('amm_gen control arguments')
    other.add_argument('--set-buff', metavar=('burst', 'data'), type=int, nargs=2, help = """set specific burst data in amm_gen buffer""")
    other.add_argument('--get-buff', action='store_true', help = """print amm_gen buffer""")
    other.add_argument('--gen-wr', metavar='addr', type=int, help = """writes amm_gen buffer to specific address""")
    other.add_argument('--gen-rd', metavar='addr', type=int, help = """reads memory data to amm_gen buffer""")
    other.add_argument('--gen-burst', type=int, help = """sets burst count for amm_gen""")

    args = parser.parse_args()
    return args

if __name__ == '__main__':
    args = parseParams()

    if args.logger_index is None:
        args.logger_index = args.index

    logger = MemLogger(args.device, args.logger_comp, args.logger_index)
    tester = MemTester()
    tester.open(args.device, args.comp, args.index, logger)

    if args.print:
        status = tester.load_status()
        print(tester.status_to_str(status))
        print(tester.mem_logger.config_to_str())
        stats = tester.mem_logger.load_stats()
        print(tester.mem_logger.stats_to_str(stats))
        print(tester.amm_gen_to_str())

    elif args.rst or args.rst_tester:
        tester.rst(False)
    elif args.rst or args.rst_logger:
        tester.mem_logger.rst()
    elif args.rst_emif:
        tester.rst(True)

    elif args.gen_burst is not None:
        tester.amm_gen_set_burst(args.gen_burst)
    elif args.gen_wr is not None:
        print(f"Writing to address {args.gen_wr}")
        tester.amm_gen_write(args.gen_wr)
    elif args.gen_rd is not None:
        print(f"Reading from address {args.gen_rd}")
        tester.amm_gen_read(args.gen_rd)
    elif args.set_buff is not None:
        tester.amm_gen_set_buff(args.set_buff[0], args.set_buff[1])
    elif args.get_buff or args.gen_rd is not None:
        buff = tester.amm_gen_get_buff()
        for i, b in enumerate(buff):
            print(f"{i:>4}: {b}")

    else:
        tester.config_test(
            args.rand,
            args.burst,
            args.scale,
            args.one_simult,
            args.to_first,
            args.auto_precharge,
            args.refresh,
        )
        tester.execute_test()
        config, status, stats, errs = tester.get_test_result()
        print(tester.test_result_to_str(config, status, stats, errs))

