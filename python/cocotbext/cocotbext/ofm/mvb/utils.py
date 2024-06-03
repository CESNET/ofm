# utils.py: MVB utils
# Copyright (C) 2024 CESNET z. s. p. o.
# Author(s): Ondřej Schwarz <Ondrej.Schwarz@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

import random

def get_mvb_params(items, params_dic):
    cDelays = dict()
    
    if params_dic is None:
        mode = 1
        
        #parameters for whole invalid words
        wordDelayEnable_wt = 10 
        wordDelayDisable_wt= 90
        wordDelayLow = 0
        wordDelayHigh = 50

        #parameters for whole invalid items        
        ivgEnable_wt = 3
        ivgDisable_wt = 1
        ivgLow = 0
        ivgHigh = 2*items-1
            
    else:
        #parameters for whole invalid words
        mode = params_dic["mode"]
        
        wordDelayEnable_wt = params_dic["wordDelayEnable_wt"]
        wordDelayDisable_wt= params_dic["wordDelayDisable_wt="]
        wordDelayLow = params_dic["wordDelayLow"]
        wordDelayHigh = params_dic["wordDelayHigh"]

        #parameters for whole invalid items        
        ivgEnable_wt = params_dic["ivgEnable_wt"]
        ivgDisable_wt = params_dic["ivgDisable_wt"]
        ivgLow = params_dic["ivgLow"]
        ivgHigh = params_dic["ivgHigh"]


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
