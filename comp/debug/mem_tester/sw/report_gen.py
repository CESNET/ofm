#!/usr/bin/env python3
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>

import os
import subprocess
import numpy as np
import matplotlib.pyplot as plt
import json
from random import randrange, uniform
from pdf_gen import *   # TODO

DEBUG           = False
csv_delim       = ','
burst_step      = 3
test_cnt        = 5
test_scale      = .0001    # How many % of memory will be tested

fig_path        = "fig/"
raw_file        = "raw.txt"
raw_json_file   = "raw_json.json"
card_info_file  = "info.txt"

iterCnt         = 0
currIter        = 0
prevIter        = 0

def run_cmd(cmd):
    return subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE).stdout.read().strip().decode("utf-8")

def parse_csv(str):
    array = np.fromstring(str, sep=csv_delim)
    return array

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


# AMM_DATA_WIDTH, AMM_ADDR_WIDTH, AMM_BURST_WIDTH, AMM_FREQ_KHZ
def get_dev_info(index):
    if DEBUG == True:
        str = "512, 28, 7, 333332000"
    else:
        str = run_cmd("./mem_tester -gv -i {0}".format(index))

    arr = parse_csv(str)
    return {
        "AMM": {
            "DATA_WIDTH":       arr[0],
            "ADDR_WIDTH":       arr[1],
            "BURST_WIDTH":      arr[2],
            "FREQ":             arr[3] * 1000000.0,    # to Hz
        },
    }

# err_cnt, 
# write_flow, read_flow, total_flow,    (b/s)
# write_words, read_words, req_words,
# min_lat, max_lat, avg_lat             (ns)
def get_test_res(index, test_type, burst):
    #print("b = {0}".format(burst))
    cmd = "./mem_tester -v -t {0} -n {1} -i {2} -k {3}".format(test_type, burst, index, test_scale)

    if DEBUG == True:
        str = "0, 128000000, 128000000, 128000000, 1, 2, 3, 10, 10, 10"
        str = "{0}, {1}, {2}, {3}, {4}, {5}, {6}, {7}, {8}, {9}".format(
            randrange(burst - 10, burst + 10),

            randrange(125000000000 + burst * 10000, 130000000000 + burst * 100000),
            randrange(125000000000 + burst * 10000, 130000000000 + burst * 100000),
            randrange(125000000000 + burst * 10000, 130000000000 + burst * 100000),

            randrange(100000, 120000),
            randrange(100000, 120000),
            randrange(100000, 120000),

            uniform(10.0, 20.0),
            uniform(50.0, 60.0),
            uniform(20.0, 50.0),
        )
    else:
         #print(cmd)
        str = run_cmd(cmd)

    global currIter
    currIter = currIter + 1
    printProgressBar(currIter, iterCnt)

    arr = parse_csv(str)
    str += '\n'

    if len(arr) < 9:
        print("Error with command: {0}\n   returned: {1}".format(cmd, str))

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
    }, str

def test_multiple_bursts(index, test_type, max_burst):
    data, str = get_test_res(index, test_type, 1)
    data = {k: np.array([v]) for (k,v) in data.items()}

    for b in range(1 + burst_step, max_burst + 1, burst_step):
        new_data, new_str = get_test_res(index, test_type, b)
        data = {k: np.array([*v, new_data[k]]) for (k,v) in data.items()}
        str += new_str

    return data, str

def test_multiple(index, test_type, max_burst):
    # run multiple measurements
    all_data, str = test_multiple_bursts(index, test_type, max_burst)
    all_data = {k: np.array([v]) for (k,v) in all_data.items()}

    for i in range(1, test_cnt):
        new_data, new_str = test_multiple_bursts(index, test_type, max_burst)
        all_data = {k: np.array([*v, new_data[k]]) for (k,v) in all_data.items()}
        str += new_str

    return all_data, str

def plot_config(xlabel, ylabel, title):
    plt.figure(figsize=(10, 4), tight_layout = True)
    plt.xlabel(xlabel)
    plt.ylabel(ylabel)
    plt.title(title, fontsize = 15)

def plot_add_ax(old_lim, ax2_scale, ax2_label):
    ax2 = plt.gca().twinx()
    #mn, mx = plt.gca().get_ylim()
    mn, mx = old_lim
    ax2.set_ylim(mn*ax2_scale, mx*ax2_scale)
    ax2.set_ylabel(ax2_label)

def plot_save(file_name):
    plt.savefig(fig_path + file_name + ".pdf")
    plt.savefig(fig_path + file_name + ".png")
    plt.close()

def plot(x, y, color, label):
    for i in range(0, len(y)):
        if i == 0:
            plt.plot(x, y[i], color=color, label=label)
        else:
            plt.plot(x, y[i], color=color)
        plt.scatter(x, y[i], color=color)

    plt.legend()

def plot_range(x, min, max, color, label):
    plt.fill_between(x, max, min, color = color, alpha = 0.4, label = label)


def plot_all_data(all_data, test_type, max_burst, burst_size, amm_freq, test_str):
    burst_size_B = burst_size / 8
    x_words = np.arange(1, max_burst + 1, burst_step)
    x = x_words * burst_size_B

    # plot flow #
    plot_config("burst size [B]", "data flow [Gb/s]", "{0} - read / write data flow".format(test_str))
    plot(x,
         all_data["write_flow"],
        'blue', "write")
    plot(x,
        all_data["read_flow"],
        'red', "read")
    plot_add_ax(plt.gca().get_ylim(), 
        1 / (burst_size * amm_freq) * 10 ** 9 * 100, "efficiency [%]")
    plot_save(test_type + '_flow')

    # plot latency #
    plot_config("burst size [B]", "latency [ns]", "{0} - latency ranges".format(test_str))
    plot_range(x,
        np.amin(all_data["lat_min"], axis = 0), 
        np.amax(all_data["lat_max"], axis = 0),
        'royalblue', 'min, max')
    plot(x,
        all_data["lat_avg"],
        'red', "average")
    plot_save(test_type + '_lat')

    # plot zoomed latency #
    plot_config("burst size [B]", "latency [ns]", "{0} - zoom to average latency".format(test_str))
    plot_range(x,
        np.amin(all_data["lat_min"], axis = 0), 
        np.amax(all_data["lat_max"], axis = 0),
        'royalblue', 'min, max')
    plot(x,
        all_data["lat_avg"],
        'red', "average")
    min = all_data["lat_avg"].min()
    max = all_data["lat_avg"].max()
    range = max - min
    plt.gca().set_ylim([min - 0.1 * range, max + 0.1 * range])
    plot_save(test_type + '_lat_avg')

    # plot err cnt #
    plot_config("burst size [words]", "error cnt", "Error count during tests")
    plot(x_words, all_data["err_cnt"], 'red', "error count")
    plot_save(test_type + '_errs')

def save_raw(raw_str, all_data):
    with open(raw_file, 'a') as f:
        f.write(raw_str)

    # todo group all data
    #all_data = {k: v.tolist() for (k,v) in all_data.items()}
    # 
    #with open(raw_json_file, 'a') as f:
    #    f.write(json.dumps(all_data, indent=4))

# MAIN #
if __name__ == '__main__':
    if not os.path.isdir(fig_path):
        os.makedirs(fig_path)

    with open(raw_file, 'w') as f:
        f.write(
            "Memory tester (burst_step = {0}, test_cnt = {1}, seq_flow, seq_lat, rand_flow, rand_lat)\n".format(
                burst_step, test_cnt
            ))

    if DEBUG == True:
        compCnt     = 2
    else:
        compCnt     = int(run_cmd("./mem_tester -i g"))

    pdf = pdf_init(card_info_file)

    for i in range(0, compCnt):
        dev_info    = get_dev_info(i)

        max_burst   = int(2 ** dev_info["AMM"]["BURST_WIDTH"] - 1)
        burst_size  = int(dev_info["AMM"]["DATA_WIDTH"])

        print ("Testing memory: {0}".format(i))
        iterCnt = int (test_cnt * (max_burst / burst_step) * 4 + 1)
        currIter = 0
        prevIter = 0
        printProgressBar(currIter, iterCnt)

        all_data_seq, raw = test_multiple(i, "seq", max_burst)
        plot_all_data(all_data_seq, "{0}_seq".format(i), max_burst, burst_size, dev_info["AMM"]["FREQ"], "Sequential indexing")
        save_raw(raw, all_data_seq)

        all_data_rand, raw = test_multiple(i, "rand", max_burst)
        plot_all_data(all_data_rand, "{0}_rand".format(i), max_burst, burst_size, dev_info["AMM"]["FREQ"], "Random indexing")
        save_raw(raw, all_data_rand)

        # only one simultanous read transaction
        bonus_params = "-o -k 0.1" # k = addr limit scale to reduce time!!
        all_data_seq_o, raw = test_multiple(i, "seq " + bonus_params, max_burst)
        plot_all_data(all_data_seq_o, "{0}_seq_o".format(i), max_burst, burst_size, dev_info["AMM"]["FREQ"], "Sequential indexing (only 1 simult)")
        save_raw(raw, all_data_seq_o)

        all_data_rand_o, raw = test_multiple(i, "rand " + bonus_params, max_burst)
        plot_all_data(all_data_rand_o, "{0}_rand_o".format(i), max_burst, burst_size, dev_info["AMM"]["FREQ"], "Random indexing (only 1 simult)")
        save_raw(raw, all_data_rand_o)

        pdf_report(pdf, fig_path, i, dev_info, all_data_seq, all_data_rand, all_data_seq_o, all_data_rand_o)

    pdf_fin(pdf, 'mem_tester_report.pdf')
    #print("\n")

