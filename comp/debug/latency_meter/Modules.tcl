# Modules.tcl: Components include script
# Copyright (C) 2021 CESNET
# Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

set FIFOX_BASE     "$OFM_PATH/comp/base/fifo/fifox"

# Packages
set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/math_pack.vhd"
set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/type_pack.vhd"


set COMPONENTS [concat $COMPONENTS [list \
    [ list "FIFOX"       $FIFOX_BASE      "FULL" ] \
]]



set MOD "$MOD $ENTITY_BASE/latency_meter.vhd"
    