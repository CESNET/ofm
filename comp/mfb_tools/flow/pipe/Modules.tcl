# Modules.tcl: Components include script
# Copyright (C) 2016 CESNET z. s. p. o.
# Author(s): Lukas Kekely <kekely@cesnet.cz> 
#
# SPDX-License-Identifier: BSD-3-Clause



set PIPE_BASE   "$OFM_PATH/comp/base/misc/pipe"

set COMPONENTS [list \
    [list "PIPE"    $PIPE_BASE     "FULL"] \
]

set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/math_pack.vhd"

set MOD "$MOD $ENTITY_BASE/mfb_pipe.vhd"
