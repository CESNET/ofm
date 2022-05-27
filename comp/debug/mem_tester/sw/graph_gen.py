#!/usr/bin/env python3
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>

import enum
from multiprocessing.spawn import prepare
import os
import sys
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.colors as colors

raw_file        = "raw.txt"

#####################
# Support functions #
#####################

class GraphGen:
    maxXTicks = 15

    def __init__(self, figPath, testCnt, burstSeq, maxBurst, burstSize, freq):
        self.figPath    = figPath
        self.testCnt    = testCnt
        self.burstSeq   = burstSeq
        self.maxBurst   = maxBurst
        self.burstSize  = burstSize
        self.freq       = freq    

    @classmethod
    def dropShrink(cls, arr, reqLen):
        return arr[:: max(1, int(len(arr) / reqLen))]

    def plot_config(self, xlabel, ylabel, title, figsize = (10, 4)):
        plt.figure(figsize=figsize, tight_layout = True)
        plt.xlabel(xlabel)
        plt.ylabel(ylabel)
        plt.title(title, fontsize = 15)

    def plot_add_ax(self, old_lim, ax2_scale, ax2_label):
        ax2 = plt.gca().twinx()
        #mn, mx = plt.gca().get_ylim()
        mn, mx = old_lim
        ax2.set_ylim(mn*ax2_scale, mx*ax2_scale)
        ax2.set_ylabel(ax2_label)

    def plot_save(self, file_name):
        plt.savefig(self.figPath + file_name + ".pdf")
        plt.savefig(self.figPath + file_name + ".png")
        plt.close()

    def plot(self, x, y, color, label):
        for i in range(0, len(y)):
            if i == 0:
                plt.plot(x, y[i], color=color, label=label)
            else:
                plt.plot(x, y[i], color=color)
            plt.scatter(x, y[i], color=color)

        plt.legend()

    def plot_range(self, x, min, max, color, label):
        plt.fill_between(x, max, min, color = color, alpha = 0.4, label = label)

    def plot_hist(self, x, y, color, label):
        plt.yscale("log")
        newX = range(0, len(y))
        plt.bar(newX, y, width=-1.0, align='edge', color = color, label = label)
        plt.xticks(
            GraphGen.dropShrink(newX, self.maxXTicks), 
            GraphGen.dropShrink(['{0:.0f}'.format(i) for i in x], self.maxXTicks), 
            rotation='vertical')

    def prepare_hist_spectrogram(self, all_data):
        x = [ a + (b - a) / 2 for (a,b) in 
            zip(all_data["latency_hist_from"][0][0], all_data["latency_hist_to"][0][0])]
        x = np.array(x)
        y = np.asarray(all_data["latency_hist_val"])
        y = np.stack(y, axis=1)
        y = np.concatenate(y, axis=0)
        y = np.transpose(y)

        # tmp = np. np.hsplit(y,2)[1]
        # s = tmp.shape
        # np.reshape(np.repeat(tmp[2:],2), (s[0], s[1]*2))        

        return x,y

    def plot_hist_spectrogram(self, bursts, all_data, label):
        x, y = self.prepare_hist_spectrogram(all_data)

        cmap = plt.get_cmap('jet', 64)
        cmap.set_under('white', 1.0)

        plt.imshow(y, cmap = cmap,
            norm=colors.LogNorm(vmin=max(1, np.min(y)), vmax=np.max(y)),
            origin='lower', aspect='auto', label = label)
        cb = plt.colorbar()
        cb.set_label(label='transaction count')

        plt.xticks(
            GraphGen.dropShrink(range(self.testCnt - 1, len(bursts) * self.testCnt, self.testCnt), self.maxXTicks), 
            GraphGen.dropShrink(['{0:.0f}'.format(i) for i in bursts], self.maxXTicks), 
            rotation='vertical')
        plt.yticks(
            GraphGen.dropShrink(range(0, len(x)), self.maxXTicks), 
            GraphGen.dropShrink(['{0:.0f}'.format(i) for i in x], self.maxXTicks))

    def prepare_hist_data(self, data):
        first = 0
        last = 0

        for v0 in data["latency_hist_val"]:
            foundFirst = False
            for v1 in v0:
                for i, val in enumerate(v1):
                    if val > 0:
                        if not foundFirst:
                            first = min(first, i)
                            foundFirst = True 
                        last = max(last, i)

        for i in ("latency_hist_val", "latency_hist_from", "latency_hist_to"):
            data[i] = np.delete(data[i], np.s_[:first], 2)
            data[i] = np.delete(data[i], np.s_[last:],   2)


    def plot_all_data(self, all_data, test_type, test_str):
        burst_size_B = self.burstSize / 8
        x_words = np.array(self.burstSeq)
        x = x_words * burst_size_B

        # plot flow #
        self.plot_config("burst size [B]", "data flow [Gb/s]", "{0} - read / write data flow".format(test_str))
        self.plot(x,
            all_data["write_flow"],
            'blue', "write")
        self.plot(x,
            all_data["read_flow"],
            'red', "read")
        self.plot_add_ax(plt.gca().get_ylim(), 
            1 / (self.burstSize * self.freq) * 10 ** 9 * 100, "efficiency [%]")
        self.plot_save(test_type + '_flow')

        # plot latency #
        self.plot_config("burst size [B]", "latency [ns]", "{0} - latency ranges".format(test_str))
        self.plot_range(x,
            np.amin(all_data["min_latency"], axis = 0), 
            np.amax(all_data["max_latency"], axis = 0),
            'royalblue', 'min, max')
        self.plot(x,
            all_data["avg_latency"],
            'red', "average")
        self.plot_save(test_type + '_lat')

        # plot zoomed latency #
        self.plot_config("burst size [B]", "latency [ns]", "{0} - zoom to average latency".format(test_str))
        self.plot_range(x,
            np.amin(all_data["min_latency"], axis = 0), 
            np.amax(all_data["max_latency"], axis = 0),
            'royalblue', 'min, max')
        self.plot(x,
            all_data["avg_latency"],
            'red', "average")
        min = all_data["avg_latency"].min()
        max = all_data["avg_latency"].max()
        range = max - min
        plt.gca().set_ylim([min - 0.1 * range, max + 0.1 * range])
        self.plot_save(test_type + '_lat_avg')

        self.prepare_hist_data(all_data)

        # plot latency histogram #
        self.plot_config("latency ranges [ns]", "transaction count", 
            "{0} - latency histogram for burst = {1:.0f} B".format(test_str, x[0]),
            (10, 3))
        self.plot_hist(np.array(all_data["latency_hist_to"][0][0]),
            np.array(all_data["latency_hist_val"][0][0]),
            'blue', "count")
        self.plot_save(test_type + '_hist')

        # plot latency spectrogram #
        self.plot_config("burst size [B]", "latency ranges [ns]", 
            "{0} - latency spectrogram".format(test_str))
        self.plot_hist_spectrogram(x, all_data, 'todo')
        self.plot_save(test_type + '_spectrogram')

        # plot err cnt #
        self.plot_config("burst size [words]", "error cnt", "Error count during tests")
        self.plot(x_words, all_data["err_cnt"], 'red', "error count")
        self.plot_save(test_type + '_errs')
