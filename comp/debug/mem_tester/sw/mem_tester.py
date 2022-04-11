#!/usr/bin/env python3
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>

import os
from pickle import TRUE
import subprocess
import numpy as np
import json
import pytest
from random import randrange, uniform


# Run:  pytest -v -s mem_tester.py 
# -s ... to show measured data

DEBUG = False
csv_delim       = ','

def run_cmd(cmd):
    return subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE).stdout.read().strip().decode("utf-8")

def parse_csv(str):
    array = np.fromstring(str, sep=csv_delim)
    return array



def get_comp_cnt():
    if DEBUG:
        compCnt = 2
    else:
        compCnt     = int(run_cmd("./mem_tester -i g"))
    return compCnt

def get_dev_info(index):
    # AMM_DATA_WIDTH, AMM_ADDR_WIDTH, AMM_BURST_WIDTH, AMM_FREQ_KHZ
    if DEBUG == True:
        str = "512, 28, 7, 333332000"
    else:
        str = run_cmd("./mem_tester -gv -i {0}".format(index))

    arr = parse_csv(str)
    if len(arr) != 4:
        return False

    return {
        "AMM": {
            "DATA_WIDTH":       arr[0],
            "ADDR_WIDTH":       arr[1],
            "BURST_WIDTH":      arr[2],
            "FREQ":             arr[3] * 1000000.0,    # to Hz
        },
    }

def get_dev_status(index):
    # TEST_DONE, TEST_SUCCESS, ECC_ERR, CALIB_SUCC, CALIB_FAIL, AMM_READY
    if DEBUG == True:
        str = "1, 1, 0, 1, 0, 1"
    else:
        str = run_cmd("./mem_tester -uv -i {0}".format(index))

    arr = parse_csv(str)
    if len(arr) != 6:
        return False

    return {
        "TEST_DONE":        arr[0],
        "TEST_SUCCESS":     arr[1],
        "ECC_ERR":          arr[2],
        "CALIB_SUCC":       arr[3],
        "CALIB_FAIL":       arr[4],
        "AMM_READY":        arr[5],
    }

# err_cnt, 
# write_flow, read_flow, total_flow,    (b/s)
# write_words, read_words, req_words,
# min_lat, max_lat, avg_lat             (ns)
def get_test_res(index, test_type, burst):
    cmd = "./mem_tester -v -t {0} -n {1} -i {2}".format(test_type, burst, index)

    if DEBUG == True:
        str = "0, 128000000, 128000000, 128000000, 1, 2, 3, 10, 10, 10"
        str = "{0}, {1}, {2}, {3}, {4}, {5}, {6}, {7}, {8}, {9}".format(
            0,

            randrange(125000000000 + burst * 10000, 130000000000 + burst * 100000),
            randrange(125000000000 + burst * 10000, 130000000000 + burst * 100000),
            randrange(125000000000 + burst * 10000, 130000000000 + burst * 100000),

            randrange(100000, 120000),
            100000,
            100000 / burst,

            uniform(10.0, 20.0),
            uniform(50.0, 60.0),
            uniform(20.0, 50.0),
        )
    else:
        str = run_cmd(cmd)

    arr = parse_csv(str)

    if len(arr) != 10:
        return False

    return {
        "err_cnt"       :       arr[0],

        "write_flow"    :       arr[1]  / 10 ** 9,
        "read_flow"     :       arr[2]  / 10 ** 9,
        "total_flow"    :       arr[3]  / 10 ** 9,

        "write_words"   :       arr[4],
        "read_words"    :       arr[5],
        "req_words"     :       arr[6],

        "lat_min"       :       arr[7],
        "lat_max"       :       arr[8],
        "lat_avg"       :       arr[9],
    }




# TESTS #
def test_comp_cnt():
    compCnt = get_comp_cnt()
    assert compCnt > 0, "No DDR4 testers found!"

def test_dev_info():
    for i in range (0, get_comp_cnt()):
        devInfo = get_dev_info(i)
        assert devInfo != False, "Cant get device info from {0} tester".format(i)

        assert devInfo["AMM"]["DATA_WIDTH"] > 0,    "Wrong DATA_WIDTH on tester {0}".format(i)
        assert devInfo["AMM"]["ADDR_WIDTH"] > 0,    "Wrong ADDR_WIDTH on tester {0}".format(i)
        assert devInfo["AMM"]["BURST_WIDTH"] > 0,   "Wrong BURST_WIDTH on tester {0}".format(i)
        assert devInfo["AMM"]["FREQ"] > 0,          "Wrong FREQ on tester {0}".format(i)

def test_dev_status():
    for i in range (0, get_comp_cnt()):
        devStatus = get_dev_status(i)
        err_msg = " (tester {0}) ".format(i)

        assert devStatus != False, \
            "Cant get device status" + err_msg

        assert devStatus["AMM_READY"] == 1, \
            "AMM_READY = 0" + err_msg
        assert devStatus["CALIB_SUCC"] or devStatus["CALIB_FAIL"], \
            "DDR4 interface calibration not finished" + err_msg
        assert devStatus["CALIB_SUCC"] == 1, \
            "DDR4 interface calibration filed" + err_msg
        assert not (devStatus["CALIB_SUCC"] and devStatus["CALIB_FAIL"]), \
            "Internal error on calibration status signals" + err_msg

def test_seq():
    print()
    for i in range (0, get_comp_cnt()):
        print("------------------------------")
        print("Memory interface {0}".format(i))
        devInfo = get_dev_info(i)

        maxBurst = int(2 ** devInfo["AMM"]["BURST_WIDTH"]) - 1
        #for burst in range (1, maxBurst, int(maxBurst / test_cnt)):
        for burst in (1, int(maxBurst / 2), maxBurst):
            print("Burst count = {0}".format(burst))

            err_msg = " (tester {0}, burst {1}) ".format(i, burst)
            testRes = get_test_res(i, "seq", burst)
    
            assert testRes != False, "Test failed on" + err_msg

            assert testRes["err_cnt"] == 0, \
               "There were {0} wrong writen / readed words during the test".format(testRes["err_cnt"]) \
                + err_msg
            assert testRes["req_words"] * burst == testRes["read_words"], \
                "Requested words do not match received words" + err_msg

            devStatus = get_dev_status(i)
            assert devStatus["AMM_READY"] == 1, \
                "AMM_READY = 0 after the test" + err_msg
            assert devStatus["TEST_DONE"] == 1, \
                "Test was not finished" + err_msg
            assert devStatus["TEST_SUCCESS"] == 1, \
                "Test failed" + err_msg
            assert devStatus["ECC_ERR"] == 0, \
                "ECC error found during the test" + err_msg

            print("Write data flow          = {0} Gb/s".format(round(testRes["write_flow"], 2)))
            print("Read data flow           = {0} Gb/s".format(round(testRes["read_flow"], 2)))
            print("Min / avg / max latency  = {0} / {1} / {2} ns".format(
                round(testRes["lat_min"], 2),
                round(testRes["lat_avg"], 2),
                round(testRes["lat_max"], 2),
                ))
            print()



