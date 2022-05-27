#!/usr/bin/env python3
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>

import os
import sys

from data_manager       import DataLoader, DataSaver
from mem_tester_parser  import MemTestParams
from graph_gen          import GraphGen
from pdf_gen            import PDFGen

burst_step      = 3
#burst_prec_lim  = 10    # All bursts will be sampled in range <1,this threshold>
# Causes problems with spectrogram
burst_prec_lim  = 1    # All bursts will be sampled in range <1,this threshold>
test_cnt        = 2
test_scale      = .001    # How many % of memory will be tested
# To overcome the refresh
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
    if not os.path.isdir(fig_path):
        os.makedirs(fig_path)

    with open(raw_file, 'w') as f:
        f.write(
            "Memory tester (burst_step = {0}, test_cnt = {1}, seq_flow, seq_lat, rand_flow, rand_lat)\n".format(
                burst_step, test_cnt
            ))

    compCnt     = DataLoader.get_comp_cnt()
    pdfGen      = PDFGen(card_info_file, result_report)
    dataSaver   = DataSaver()
    dataSaver.add_value("comp_cnt", compCnt)

    for i in range(0, compCnt):
        dataLoader  = DataLoader(i, progressUpdate, dataSaver=dataSaver)

        max_burst   = dataLoader.maxBurst
        burst_size  = dataLoader.devConfig["AMM_DATA_WIDTH"]
        freq        = dataLoader.devConfig["AMM_FREQ"]
        burstSeq    = burst_seq(max_burst, burst_prec_lim, burst_step)

        graphGen    = GraphGen(fig_path, test_cnt, burstSeq, max_burst, burst_size, freq)

        print ("Testing memory: {0}".format(i))
        iterCnt = int(test_cnt * (max_burst / burst_step) * 4 + 1)
        currIter = 0
        prevIter = 0
        printProgressBar(currIter, iterCnt)

        testParams  = MemTestParams(testScale=test_scale)

        tree = dataSaver.create_sub_tree("seq_test")
        all_data_seq = dataLoader.test_multiple(testParams, test_cnt, burstSeq, tree)
        graphGen.plot_all_data(all_data_seq, "{0}_seq".format(i), "Sequential indexing")

        tree = dataSaver.create_sub_tree("rand_test")
        testParams.randOn = True
        all_data_rand = dataLoader.test_multiple(testParams, test_cnt, burstSeq, tree)
        graphGen.plot_all_data(all_data_rand, "{0}_rand".format(i), "Random indexing")

        # only one simultanous read transaction
        tree = dataSaver.create_sub_tree("seq_o_test")
        testParams.randOn = False
        testParams.oneSimult = True
        all_data_seq_o = dataLoader.test_multiple(testParams, test_cnt, burstSeq, tree)
        graphGen.plot_all_data(all_data_seq_o, "{0}_seq_o".format(i), "Sequential indexing (only 1 simult)")

        tree = dataSaver.create_sub_tree("rand_o_test")
        testParams.randOn = True
        testParams.oneSimult = True
        all_data_rand_o = dataLoader.test_multiple(testParams, test_cnt, burstSeq, tree)
        graphGen.plot_all_data(all_data_rand_o, "{0}_rand_o".format(i), "Random indexing (only 1 simult)")

        pdfGen.report(fig_path, i, dataLoader.devConfig, all_data_seq, all_data_rand, all_data_seq_o, all_data_rand_o)

    pdfGen.fin()
    dataSaver.save(raw_file)

