# ver_run.py
# Copyright (C) 2019 CESNET z. s. p. o.
# Author(s): Jan Kubalek <xkubal11@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

import argparse
import os
from os import system, popen
from importlib.machinery import SourceFileLoader
from random import randint

FAIL = False

# RANDOMLY reduce number of combination to a certain percentage
def reduce_combinations(combinations, reduction_perc = 100):
    if (reduction_perc >= 100):
        return combinations

    comb = list(combinations)
    items = len(comb)
    new_items = items * reduction_perc // 100
    if (new_items < 1):
        new_items = 1

    new_comb = []
    for i in range(new_items):
        new_comb.append(comb.pop(randint(0,len(comb)-1)))

    return tuple(new_comb)

# Modify setting variable
def create_setting_from_combination(settings,combination):
    global FAIL
    s = settings["default"].copy()
    for c in combination:
        if (c not in settings.keys()):
            print("ERROR: Combination \"{}\" contains unknown setting name \"{}\"!".format(combination,c))
            FAIL = True
            continue
        for i in settings[c].keys(): # load modified values
            if (i not in s.keys()):
                print("ERROR: Parameter \"{}\" is present in setting \"{}\" but not in setting \"default\". This might cause unexpected behaviour in the following runs!".format(i,c))
                FAIL = True
            s[i] = settings[c][i]
    return s

# Modify package file according to setting
def apply_setting(pkg_file,setting,sed_str):
    env = {}
    for i in setting.keys():
        if i == '__archgrp__':
            env['ARCHGRP'] = " ".join([f'{k}={v}' for k,v in setting[i].items()])
        elif i == '__core_params__':
            env['CORE_PARAMS'] = " ".join([f'{k}={v}' for k,v in setting[i].items()])
        else:
            #print(sed_str.format(i,setting[i],pkg_file))
            system(sed_str.format(i,setting[i],pkg_file))
    return env

# Run Modelsim with the current test_pkg file
def run_modelsim(fdo_file,manual=False,gui=False, env={}):
    global FAIL
    c = "\"" if (gui) else "; quit -f\" -c"
    for k, v in env.items():
        os.environ[k] = v

    if (manual):
        system("vsim -do \"do "+fdo_file+c)
        result = system("grep -E \"(Verification finished successfully)|(VERIFICATION SUCCESS)\" transcript >/dev/null")
    else:
        result = system("vsim -do \"do "+fdo_file+c+" | grep -E \"(Verification finished successfully)|(VERIFICATION SUCCESS)\" >/dev/null")

    for k in env:
        del os.environ[k]
    return result

##########
# Parsing script arguments
##########

parser = argparse.ArgumentParser()

parser.add_argument("fdo_file", help="Name of verification \".fdo\" file to run in Modelsim")
parser.add_argument("test_pkg_file", help="Name of verification \".sv\" or \".vhd\" package file modify when applying settings")
parser.add_argument("settings_file", help="Name of verification settings \".py\" file containing \"SETTINGS\" dictionary variable")
parser.add_argument("-s","--setting", nargs="+", help="Name of a specific setting or a sequence of settings from the \"SETTINGS\" dictionary to apply and run")
parser.add_argument("-d","--dry-run", action="store_true", help="(Used together with '-s') Only sets the requested setting to test package without starting the verification")
parser.add_argument("-c","--command-line", action="store_true", help="(Used together with '-s') Starts ModelSim with parameter '-c' for command line run")
parser.add_argument("-r","--run-percantage", action="store", help="(Used without '-s') Randomly reduces number of performed combination to the given percantage ('100' for running all combinations)")

args = parser.parse_args()

# Detect package type
PKG_MOD_SED = "sed -i \"s/\\(\<parameter\>\s\s*\<{}\W*\\)=..*;/\\1= {};/g\" {}" # SystemVerilog format
if (len(args.test_pkg_file)>4):
    if (args.test_pkg_file[-4:]==".vhd"):
        PKG_MOD_SED = "sed -i \"s/\\(\<constant\>\s\s*\<{}\W*:.*\\):=..*;/\\1:= {};/g\" {}" # VHDL format

##########

##########
# Import Settings
##########

# import using relative path from execution directory
SETTINGS = SourceFileLoader(args.settings_file,"./"+args.settings_file).load_module().SETTINGS

if ("default" not in SETTINGS.keys()):
    print("ERROR: The settings file \"{}\" does not contain the obligatory \"default\" setting!".format(args.settings_file))
    exit(-2)

SETTING = {}

##########

##########
# Define settings combinations
##########

COMBINATIONS = ()

if ("_combinations_" in SETTINGS.keys()):
    # User defined combinations
    COMBINATIONS = SETTINGS["_combinations_"]
    del SETTINGS["_combinations_"]
else:
    # Default combinations
    COMBINATIONS = tuple([(x,) for x in SETTINGS.keys()])

if (args.run_percantage):
    # Randomly reduce number of combinations based on command argument
    COMBINATIONS = reduce_combinations(COMBINATIONS,int(args.run_percantage))
    del SETTINGS["_combinations_run_percentage_"]
elif ("_combinations_run_percentage_" in SETTINGS.keys()):
    # Randomly reduce number of combinations based on SETTINGS
    COMBINATIONS = reduce_combinations(COMBINATIONS,SETTINGS["_combinations_run_percentage_"])
    del SETTINGS["_combinations_run_percentage_"]

#print(COMBINATIONS)

##########

#Print current directory where verification is running
print(os.getcwd())

if (args.setting==None):
    ##########
    # Run all settings
    ##########

    for c in COMBINATIONS:
        SETTING = create_setting_from_combination(SETTINGS,c)

        env = apply_setting(args.test_pkg_file,SETTING,PKG_MOD_SED)

        print("Running combination: "+" ".join(c))
        result = run_modelsim(args.fdo_file,env=env)
        if (result == 0): # detect failure
            print("Run SUCCEEDED ("+" ".join(c)+")")
        else:
            print("Run FAILED ("+" ".join(c)+")")
            FAIL = True

        # backup transcript
        system("cp transcript transcript_"+"_".join(c))
        # backup test_pkg
        #system("cp {} {}_".format(args.test_pkg_file,args.test_pkg_file)+"_".join(c))
    
    ##########
else:
    ##########
    # Run selected setting
    ##########

    SETTING = create_setting_from_combination(SETTINGS,args.setting)

    env = apply_setting(args.test_pkg_file,SETTING,PKG_MOD_SED)

    if (not args.dry_run):
        print("Running combination: "+" ".join(args.setting))
        result = run_modelsim(args.fdo_file,True,(not args.command_line),env=env)
        if (result == 0): # detect failure
            print("Run SUCCEEDED ("+" ".join(args.setting)+")")
        else:
            print("Run FAILED ("+" ".join(args.setting)+")")
            FAIL = True

    print("Done")
    ##########

if (FAIL):
    exit(-1)
