#!/usr/bin/env python3
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>

import sys
import numpy as np
import xml.etree.ElementTree as ET
from mem_tester_parser import MemTesterParser, MemTestParams

#####################
# Support functions #
#####################

def err(code, txt):
    print(txt, file = sys.stderr)
    sys.exit(code)

# Transform data (list of dicts => dict of lists)
def pull_up_dict(raw_data):
    for i, d in enumerate(raw_data):
        if (i == 0):
            data = {k: np.array([v]) for (k,v) in d.items()}
        else:
            data = {k: np.array([*v, d[k]]) for (k,v) in data.items()}

    return data

###############
# Data Loader #
###############

class DataLoader:
    def __init__(self, index, progressUpdate, dataSaver = None):
        self.index          = index
        self.progressUpdate = progressUpdate
        self.devConfig, rawDevConfig = MemTesterParser.get_dev_config_raw(index)
        self.maxBurst       = int(2 ** int(self.devConfig["AMM_BURST_WIDTH"]) - 1)
        self.dataSaver      = dataSaver

        if self.dataSaver is not None:
            dataSaver.add_sub_tree(rawDevConfig)

    @classmethod
    def get_comp_cnt(cls):
        return MemTesterParser.get_comp_cnt()

    def get_test_res(self, testParams, tree):
        root, raw = MemTesterParser.get_test_res_raw(testParams)

        if self.dataSaver is not None and tree is not None:
            self.dataSaver.connect_tree(tree, raw)
    
        self.progressUpdate()
        return root

    def test_multiple_bursts(self, testParams, burstSeq, tree):
        raw_data = []
        for b in burstSeq:
            testParams.burst = b
            new_data = self.get_test_res(testParams, tree)
            raw_data.append(new_data) 

        return pull_up_dict(raw_data)

    def test_multiple(self, testParams, cnt, burstSeq, tree = None):
        raw_data = []
        testParams.index = self.index
        for i in range(0, cnt):
            new_data = self.test_multiple_bursts(testParams, burstSeq, tree)
            raw_data.append(new_data)

        return pull_up_dict(raw_data)

##############
# Data Saver #
##############

class DataSaver:
    def __init__(self):
        self.root = ET.Element("MemoryTest")
        self.tree = ET.ElementTree(self.root)

    def connect_tree(self, tree, subTree, name = None):
        el = tree
        if name is not None:
            el = ET.SubElement(tree, name)
        el.append(subTree)
        return el

    def create_sub_tree(self, name, root = None):
        if root is None:
            root = self.root 
        el = ET.SubElement(root, name)
        return el

    def add_sub_tree(self, subTree, name = None):
        return self.connect_tree(self.root, subTree, name)

    def add_value(self, name, value):
        self.root.attrib[name] = str(value)

    def save(self, fileName):
        with open(fileName, 'wb') as f:
            self.tree.write(f)

