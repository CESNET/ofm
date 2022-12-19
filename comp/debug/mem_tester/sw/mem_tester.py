#!/usr/bin/env python3
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>

from py_base.mem_tester_parser import MemTesterParser, MemTestParams

# Run: python3 -m pytest -sv mem_tester.py 
# -s ... to show measured data

#########
# TESTS #
#########

def test_comp_cnt():
    compCnt = MemTesterParser.get_comp_cnt()
    assert compCnt > 0, "No DDR4 testers found!"

def test_dev_info():
    compCnt = MemTesterParser.get_comp_cnt()

    for i in range (0, compCnt):
        devInfo = MemTesterParser.get_dev_config(i)

        assert devInfo["AMM_DATA_WIDTH"] > 0,    "Wrong DATA_WIDTH on tester {0}".format(i)
        assert devInfo["AMM_ADDR_WIDTH"] > 0,    "Wrong ADDR_WIDTH on tester {0}".format(i)
        assert devInfo["AMM_BURST_WIDTH"] > 0,   "Wrong BURST_WIDTH on tester {0}".format(i)
        assert devInfo["AMM_FREQ"] > 0,          "Wrong FREQ on tester {0}".format(i)

def test_dev_status():
    compCnt = MemTesterParser.get_comp_cnt()

    for i in range (0, compCnt):
        devStatus = MemTesterParser.get_dev_status(i)
        err_msg = " (tester {0}) ".format(i)

        assert devStatus["amm_ready"] == True, \
            "AMM_READY = 0" + err_msg
        assert devStatus["calib_success"] or devStatus["calib_fail"], \
            "DDR4 interface calibration not finished" + err_msg
        assert devStatus["calib_success"] == True, \
            "DDR4 interface calibration filed" + err_msg
        assert not (devStatus["calib_success"] and devStatus["calib_fail"]), \
            "Internal error on calibration status signals" + err_msg

def test_seq():
    print()
    compCnt = MemTesterParser.get_comp_cnt()

    for i in range (0, compCnt):
        print("------------------------------")
        print("Memory interface {0}".format(i))

        devInfo = MemTesterParser.get_dev_config(i)
        err_msg = " (tester {0}) ".format(i)

        maxBurst = int(2 ** devInfo["AMM_BURST_WIDTH"]) - 1
        for burst in (1, int(maxBurst / 2), maxBurst):
            print("Burst count = {0}".format(burst))

            err_msg = " (tester {0}, burst {1}) ".format(i, burst)
            testParams = MemTestParams(index=i, burst=burst)
            testRes = MemTesterParser.get_test_res(testParams)

            assert testRes["err_cnt"] == 0, \
               "There were {0} wrong written / read words during the test".format(testRes["err_cnt"]) \
                + err_msg
            assert testRes["req_cnt"] * burst == testRes["read_words"], \
                "Requested words do not match received words" + err_msg

            for b in ( \
                "wr_ticks_ovf"       , \
                "rd_ticks_ovf"       , \
                "rw_ticks_ovf"       , \
                "wr_words_ovf"       , \
                "rd_words_ovf"       , \
                "req_cnt_ovf"        , \
                "latency_ticks_ovf"  , \
                "latency_cnters_ovf" , \
                "latency_sum_ovf"    , \
                "hist_cnt_ovf"       ):
                assert testRes[b] == False, \
                    "Overflow bit '{0}' was set after the test".format(b) + err_msg

            devStatus = MemTesterParser.get_dev_status(i)

            assert devStatus["test_done"] == True, \
                "Test was not finished" + err_msg
            assert devStatus["amm_ready"] == True, \
                "AMM_READY = 0 after the test" + err_msg
            assert devStatus["test_success"] == True, \
                "Test failed" + err_msg
            assert devStatus["ecc_err_occ"] == False, \
                "ECC error found during the test" + err_msg

            print("Write data flow          = {0} Gb/s".format(round(testRes["write_flow"], 2)))
            print("Read data flow           = {0} Gb/s".format(round(testRes["read_flow"], 2)))
            print("Min / avg / max latency  = {0} / {1} / {2} ns".format(
                round(testRes["min_latency"], 2),
                round(testRes["avg_latency"], 2),
                round(testRes["max_latency"], 2),
                ))
            print()
