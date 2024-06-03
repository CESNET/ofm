# utils.py: MVB utils
# Copyright (C) 2024 CESNET z. s. p. o.
# Author(s): Ondřej Schwarz <Ondrej.Schwarz@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

import random

def get_mvb_params(items, params_dic):
    cDelays = dict()
    
    mode = params_dic.get("mode", 1)
        
    #parameters for whole invalid words
    wordDelayEnable_wt = params_dic.get("wordDelayEnable_wt", 10) 
    wordDelayDisable_wt= params_dic.get("wordDelayDisable_wt", 90)
    wordDelayLow = params_dic.get("wordDelayLow", 0)
    wordDelayHigh = params_dic.get("wordDelayHigh", 50)

    #parameters for whole invalid items        
    ivgEnable_wt = params_dic.get("ivgEnable_wt", 3)
    ivgDisable_wt = params_dic.get("ivgDisable_wt", 1)
    ivgLow = params_dic.get("ivgLow", 0)
    ivgHigh = params_dic.get("ivgHigh", 2*items-1)
    
    cDelays["wordDelayEn_wt"] = (wordDelayDisable_wt, wordDelayEnable_wt)
    cDelays["wordDelay"] = range(wordDelayLow, wordDelayHigh)
    cDelays["ivgEn_wt"] = (ivgDisable_wt, ivgEnable_wt)
    cDelays["ivg"] = range(ivgLow, ivgHigh)

    if mode == 0:
        delays_fill = None
    elif mode == 1:
        delays_fill = 0
    elif mode == 2:
        delays_fill = random.randrange(0,256)
    elif mode == 3:
        delays_fill = 88 #88=X in ascii

    return cDelays, mode, delays_fill
