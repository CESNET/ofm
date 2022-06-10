#!/usr/bin/env python3
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>

from ast import Str
import os
import sys
import argparse
from unittest import TestProgram, result

from py_base.mem_tester_parser import MemTestParams, MemTesterParser
from py_base.data_manager      import DataLoader, DataSaver
from py_base.graph_gen         import GraphGen
from py_base.pdf_gen           import PDFGen

burst_step      = 3
# Causes problems with spectrogram
#burst_prec_lim  = 10    # All bursts will be sampled in range <1,this threshold>
burst_prec_lim  = 1    # All bursts will be sampled in range <1,this threshold>
test_cnt        = 2
test_scale      = .001    # How many % of memory will be tested
# To overcome the refresh:
#test_scale      = 0.0000006  # How many % of memory will be tested

fig_path        = "fig/"
raw_file        = "raw.xml"
raw_json_file   = "raw_json.json"
card_info_file  = "info.txt"
result_report   = 'mem_tester_report.pdf'

iterCnt         = 0
currIter        = 0
prevIter        = 0

#####################
# Support functions #
#####################

def err(code, txt):
    print(txt, file = sys.stderr)
    sys.exit(code)

def argparse_float_range(min, max):
    def float_range_checker(arg):
        try:
            f = float(arg)
        except ValueError:    
            raise argparse.ArgumentTypeError("must be a floating point number")
        if f < min or f > max:
            raise argparse.ArgumentTypeError("must be in range [" + str(min) + " .. " + str(max) + "]")
        return f

    return float_range_checker

def parseParams():
    parser = argparse.ArgumentParser(description =
        """This program runs multiple memory tests using mem_tester component
        and creates PDF report of measured results using amm_probe component 
        inside mem_tester.""")
    parser.add_argument('--infoFile', metavar='file', type=argparse.FileType('r'),
                        help = """File with additional info about performed tests.""")
    parser.add_argument('-i', '--info', action='store_true',
                        help = """User input with additional info about performed tests.""")
    parser.add_argument('-k', '--scale', type = argparse_float_range(0.0, 1.0),
                        help = 
                            "Size of the memory address space that will be tested [0.0 - 1.0]. "
                            "Can be used to reduce test duration. "
                            "Default value is " + str(test_scale))

    args = parser.parse_args()
    return args

# https://stackoverflow.com/questions/3173320/text-progress-bar-in-terminal-with-block-characters
def printProgressBar (iteration, total, prefix = 'Progress', suffix = 'Complete', decimals = 1, length = 30, fill = '█', printEnd = "\r"):
    """
    Call in a loop to create terminal progress bar
    @params:
        iteration   - Required  : current iteration (Int)
        total       - Required  : total iterations (Int)
        prefix      - Optional  : prefix string (Str)
        suffix      - Optional  : suffix string (Str)
        decimals    - Optional  : positive number of decimals in percent complete (Int)
        length      - Optional  : character length of bar (Int)
        fill        - Optional  : bar fill character (Str)
        printEnd    - Optional  : end character (e.g. "\r", "\r\n") (Str)
    """
    global prevIter
    if prevIter >= total:
        return

    prevIter = iteration

    if iteration > total:
        iteration = total

    percent = ("{0:." + str(decimals) + "f}").format(100 * (iteration / float(total)))
    filledLength = int(length * iteration // total)
    bar = fill * filledLength + '-' * (length - filledLength)
    print(f'\r{prefix} |{bar}| {percent}% {suffix}', end = printEnd)
    # Print New Line on Complete
    if iteration == total: 
        print()

def progressUpdate():
    global currIter
    currIter = currIter + 1
    printProgressBar(currIter, iterCnt)

def burst_seq(maxBurst, burstPrecLim, burstStep):
    precBursts = list(range(1, burstPrecLim))
    restBursts = list(range(burstPrecLim, maxBurst + 1, burstStep))
    return [*precBursts, *restBursts]

########
# MAIN #
########

if __name__ == '__main__':
    args = parseParams()

    testInfo = None
    if args.info:
        testInfo = sys.stdin.read()
    elif args.infoFile:
        testInfo = args.infoFile.read()

    if args.scale:
        test_scale = args.scale

    if not os.path.isdir(fig_path):
        os.makedirs(fig_path)

    with open(raw_file, 'w') as f:
        f.write(
            "Memory tester (burst_step = {0}, test_cnt = {1}, seq_flow, seq_lat, rand_flow, rand_lat)\n".format(
                burst_step, test_cnt
            ))

    compCnt     = DataLoader.get_comp_cnt()
    pdfGen      = PDFGen(result_report, test_scale, testInfo)
    dataSaver   = DataSaver()
    dataSaver.add_value("comp_cnt", compCnt)

    for i in range(0, compCnt):
        dataLoader  = DataLoader(i, progressUpdate, dataSaver=dataSaver)

        max_burst   = dataLoader.maxBurst
        burst_size  = dataLoader.devConfig["AMM_DATA_WIDTH"]
        freq        = dataLoader.devConfig["AMM_FREQ"]
        burstSeq    = burst_seq(max_burst, burst_prec_lim, burst_step)

        graphGen    = GraphGen(fig_path, test_cnt, burstSeq, max_burst, burst_size, freq)

        print ("Resetting tester {0} ...".format(i))
        MemTesterParser.rst_tester(i)
        print ("Testing memory iterace {0} ...".format(i))
        iterCnt = int(6 * test_cnt * len(burstSeq) + 1)
        currIter = 0
        prevIter = 0
        printProgressBar(currIter, iterCnt)

        all_data = { }
        testParams  = MemTestParams(testScale=test_scale)
        testParams.burst = 1
        testParams.refreshPeriod = dataLoader.devConfig["DEF_REFRESH_PERIOD"]

        # test on the whole memory to check for errors
        testParams.testScale = 1.0
        tree = dataSaver.create_sub_tree("seq_long_test")
        all_data["seq_long"] = dataLoader.get_test_res(testParams, tree) 
        testParams.testScale = test_scale

        tree = dataSaver.create_sub_tree("seq_test")
        all_data["seq"] = dataLoader.test_multiple(testParams, test_cnt, burstSeq, tree)
        graphGen.plot_all_data(all_data["seq"], "{0}_seq".format(i), "Sequential indexing")

        tree = dataSaver.create_sub_tree("rand_test")
        testParams.randOn = True
        all_data["rand"] = dataLoader.test_multiple(testParams, test_cnt, burstSeq, tree)
        graphGen.plot_all_data(all_data["rand"], "{0}_rand".format(i), "Random indexing")

        # only one simultanous read transaction
        tree = dataSaver.create_sub_tree("seq_o_test")
        testParams.randOn = False
        testParams.oneSimult = True
        all_data["seq_o"] = dataLoader.test_multiple(testParams, test_cnt, burstSeq, tree)
        graphGen.plot_all_data(all_data["seq_o"], "{0}_seq_o".format(i), "Sequential indexing (only 1 simult)")

        tree = dataSaver.create_sub_tree("rand_o_test")
        testParams.randOn = True
        testParams.oneSimult = True
        all_data["rand_o"] = dataLoader.test_multiple(testParams, test_cnt, burstSeq, tree)
        graphGen.plot_all_data(all_data["rand_o"], "{0}_rand_o".format(i), "Random indexing (only 1 simult)")

        # without refresh #
        testParams.randOn = False
        testParams.oneSimult = True
        testParams.refreshPeriod = 2 ** 32 - 1  # set max refresh period

        # first test whole memory to see how much errors occurs with disabled refreshing
        testParams.testScale = 1.0
        testParams.burst = 1
        testParams.oneSimult = False
        tree = dataSaver.create_sub_tree("seq_o_no_refr_long_test")
        all_data["seq_o_no_refr_long"] = dataLoader.get_test_res(testParams, tree) 
        testParams.testScale = test_scale
        testParams.oneSimult = True

        tree = dataSaver.create_sub_tree("seq_o_no_refr_test")
        testParams.randOn = False
        all_data["seq_o_no_refr"] = dataLoader.test_multiple(testParams, test_cnt, burstSeq, tree)
        graphGen.plot_all_data(all_data["seq_o_no_refr"], "{0}_seq_o_no_refr".format(i), "Sequential indexing (only 1 simult) with no refresh")

        tree = dataSaver.create_sub_tree("rand_o_no_refr_test")
        testParams.randOn = True
        all_data["rand_o_no_refr"] = dataLoader.test_multiple(testParams, test_cnt, burstSeq, tree)
        graphGen.plot_all_data(all_data["rand_o_no_refr"], "{0}_rand_o_no_refr".format(i), "Random indexing (only 1 simult) with no refresh")

        #print("Tests done on interface {0}".format(i))
        pdfGen.report(fig_path, i, dataLoader.devConfig, all_data)
        print()
        print ("Resetting tester {0} again (to clear ECC flags, ...)".format(i))
        MemTesterParser.rst_tester(i)

    print("Generating PDF report to '{0}' ...".format(result_report))
    pdfGen.fin()
    print("Saving raw data to '{0}' ...".format(raw_file))
    dataSaver.save(raw_file)

