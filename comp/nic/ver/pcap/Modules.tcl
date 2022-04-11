# Modules.tcl: Local include tcl script
# Copyright (C) 2016 CESNET
# Author: Lukas Kekely <kekely@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

set SV_MII_BASE "$OFM_PATH/comp/nic/ver"
set SV_PCAP_BASE "$OFM_PATH/comp/ver/pcap"
set SV_COMMON_BASE "$OFM_PATH/comp/ver"

set COMPONENTS [list \
    [list "SV_PCAP" $SV_PCAP_BASE "FULL"] \
    [list "SV_COMMON" $SV_COMMON_BASE "FULL"] \
]

set MOD "$MOD $ENTITY_BASE/mii_pcap_reader.sv"
