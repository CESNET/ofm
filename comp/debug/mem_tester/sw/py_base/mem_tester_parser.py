#!/usr/bin/env python3
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>

import subprocess
import xml.etree.ElementTree as ET

#####################
# Support functions #
#####################

def run_cmd(cmd):
    return subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE).stdout.read().strip().decode("utf-8")

class MemTesterException(Exception):
    pass

#################
# XML functions #
#################

def convertXML(root):
    res = {  }
   
    if len(root) == 0:
        res = root.text
    else:
        isArr = False

        for i in root:
            newObj = convertXML(i)
            if isArr:
                res.append(newObj)
            elif newObj.keys() == res.keys():
                res = [ res, newObj ]
                isArr = True
            else:
                res.update(convertXML(i))
    
    return {root.tag : res}

def parseXML(txt):
    str = txt.rstrip()
    root = ET.fromstring(str)
    
    res = convertXML(root)
    return res, root

##################
# Main functions #
##################

class MemTestParams:
    def __init__(self, index = 0, randOn = False, burst = 1, testScale = 1.0, oneSimult = False,
        autoPrecharge = False, refreshPeriod = None):
        self.index          = index
        self.randOn         = randOn        
        self.burst          = burst         
        self.testScale      = testScale     
        self.oneSimult      = oneSimult     
        self.autoPrecharge  = autoPrecharge 
        self.refreshPeriod  = refreshPeriod 

class MemTesterParser:
    def __init__(self):
        pass

    @classmethod
    def errStr(cls, str):
        return "mem-tester.c send data ({0})".format(str)

    @classmethod
    def get_comp_cnt(cls):
        try:
            compCnt     = int(run_cmd("./mem_tester -i ?"))
        except (ValueError, KeyError):
            raise MemTesterException(cls.errStr("invalid comp-cnt"))
        return compCnt

    @classmethod
    def get_dev_config_raw(cls, index):
        str = run_cmd("./mem_tester -g -i {0} --xml".format(index))
        root, raw = parseXML(str)
        if "dev_config" not in root:
            raise MemTesterException(cls.errStr("expecting 'dev_config' XML element"))

        res = root["dev_config"]
        try:
            res["AMM_DATA_WIDTH"]   = int(res["AMM_DATA_WIDTH"] )
            res["AMM_ADDR_WIDTH"]   = int(res["AMM_ADDR_WIDTH"] )
            res["AMM_BURST_WIDTH"]  = int(res["AMM_BURST_WIDTH"])
            res["LAT_TICKS_WIDTH"]  = int(res["LAT_TICKS_WIDTH"])
            res["AMM_FREQ"]         = float(res["AMM_FREQ"]     ) * 10 ** 6
            res["DEF_REFRESH_PERIOD"] = float(res["DEF_REFRESH_PERIOD"])

            res["latency_hist_ranges"] = sorted(res["latency_hist_ranges"], key=lambda i: int(i["item"]["i"]))
            res["latency_hist_to"]  = [ float(i["item"]["to"])    for i in res["latency_hist_ranges"] ]
            res["latency_hist_from"]= [ float(i["item"]["from"])  for i in res["latency_hist_ranges"] ]
            res["latency_hist_ranges"] = None
        except (ValueError, KeyError):
            raise MemTesterException(cls.errStr("wrong 'dev-config' XML element"))
        return res, raw 

    @classmethod
    def get_dev_config(cls, index):
        res, _ = cls.get_dev_config_raw(index)
        return res

    @classmethod
    def get_dev_status_raw(cls, index):
        str = run_cmd("./mem_tester -u -i {0} --xml".format(index))
        root, raw = parseXML(str)
        if "dev_status" not in root:
            raise MemTesterException(cls.errStr("expecting 'dev_status' XML element"))

        res = root["dev_status"]
        try:
            res["test_done"]        = bool(int(res["test_done"]))
            res["test_success"]     = bool(int(res["test_success"]))
            res["ecc_err_occ"]      = bool(int(res["ecc_err_occ"]))
            res["calib_success"]    = bool(int(res["calib_success"]))
            res["calib_fail"]       = bool(int(res["calib_fail"]))
            res["amm_ready"]        = bool(int(res["amm_ready"]))

            res["err_cnt"]          = bool(int(res["err_cnt"]))
            res["burst_cnt"]        = bool(int(res["burst_cnt"]))
            res["addr_lim"]         = bool(int(res["addr_lim"]))
            res["refresh_period"]   = bool(int(res["refresh_period"]))
        except (ValueError, KeyError):
            raise MemTesterException(cls.errStr("wrong 'dev_status' XML element"))
        return res, raw

    @classmethod
    def get_dev_status(cls, index):
        res, _ = cls.get_dev_status_raw(index)
        return res

    @classmethod
    def get_test_res_raw(cls, testParams):
        testStr = "seq" if not testParams.randOn else "rand"
        cmd = "./mem_tester -t {0} -b {1} -i {2} -k {3} --xml".format(
            testStr, testParams.burst, testParams.index, testParams.testScale)
        str = run_cmd(cmd)
        root, raw = parseXML(str)
        if "probe_data" not in root:
            raise MemTesterException(cls.errStr("expecting 'probe_data' XML element"))

        res = root["probe_data"]
        try:
            res["err_occ"]              = bool(int(res["err_occ"    ]))
            res["ecc_err_occ"]          = bool(int(res["ecc_err_occ"]))
            res["wr_ticks_ovf"]         = bool(int(res["wr_ticks_ovf"]))
            res["rd_ticks_ovf"]         = bool(int(res["rd_ticks_ovf"]))
            res["rw_ticks_ovf"]         = bool(int(res["rw_ticks_ovf"]))
            res["wr_words_ovf"]         = bool(int(res["wr_words_ovf"]))
            res["rd_words_ovf"]         = bool(int(res["rd_words_ovf"]))
            res["req_cnt_ovf" ]         = bool(int(res["req_cnt_ovf" ]))
            res["latency_ticks_ovf"]    = bool(int(res["latency_ticks_ovf" ]))
            res["latency_cnters_ovf"]   = bool(int(res["latency_cnters_ovf" ]))
            res["latency_sum_ovf"]      = bool(int(res["latency_sum_ovf" ]))
            res["hist_cnt_ovf"]         = bool(int(res["hist_cnt_ovf" ]))

            res["burst"      ]          = int  (res["burst"      ])
            res["err_cnt"    ]          = int  (res["err_cnt"    ])
            res["write_flow" ]          = float(res["write_flow" ]) / 10 ** 9
            res["read_flow"  ]          = float(res["read_flow"  ]) / 10 ** 9
            res["total_flow" ]          = float(res["total_flow" ]) / 10 ** 9
            res["write_words"]          = int  (res["write_words"])
            res["read_words" ]          = int  (res["read_words" ])
            res["req_cnt"    ]          = int  (res["req_cnt"    ])
            res["min_latency"]          = float(res["min_latency"])
            res["max_latency"]          = float(res["max_latency"])
            res["avg_latency"]          = float(res["avg_latency"])

            devConfig = cls.get_dev_config(testParams.index)
            res["latency_hist_to"]      = devConfig["latency_hist_to"]
            res["latency_hist_from"]    = devConfig["latency_hist_from"]
            res["latency_hist_val"]     = [ 0.0 for i in devConfig["latency_hist_to"]]
            for i in res["latency_hist"]:
                res["latency_hist_val"][int(i["item"]["i"])] = int(i["item"]["value"])
            res["latency_hist"] = None

        except (ValueError, KeyError):
            raise MemTesterException(cls.errStr("wrong 'probe_data' XML element"))
        return res, raw

    @classmethod
    def get_test_res(cls, *args):
        res, _ = cls.get_test_res_raw(*args)
        return res
