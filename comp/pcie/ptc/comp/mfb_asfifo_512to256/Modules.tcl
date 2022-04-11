# Modules.tcl: Components include script
# Copyright (C) 2016 CESNET z. s. p. o.
# Author(s): Lukas Kekely <kekely@cesnet.cz> 
#
# SPDX-License-Identifier: BSD-3-Clause



set COMPONENTS [ list \
    [ list "FIFO" "$OFM_PATH/comp/mfb_tools/storage/asfifox" "FULL" ] \
    [ list "AUX"  "$OFM_PATH/comp/mfb_tools/logic/auxiliary_signals" "FULL" ] \
]

set MOD "$MOD $ENTITY_BASE/mfb_asfifo_512to256.vhd"
