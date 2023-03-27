# Modules.tcl: Components include script
# Copyright (C) 2021 CESNET z. s. p. o.
# Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause


# Paths to components
set DATA_LOGGER_BASE    "$OFM_PATH/comp/debug/data_logger"
set LATENCY_METER_BASE  "$OFM_PATH/comp/debug/latency_meter"
set FIFOX_BASE          "$OFM_PATH/comp/base/fifo/fifox"

# Packages
lappend PACKAGES "$OFM_PATH/comp/base/pkg/math_pack.vhd"
lappend PACKAGES "$OFM_PATH/comp/base/pkg/type_pack.vhd"

lappend COMPONENTS [ list "DATA_LOGGER"        $DATA_LOGGER_BASE       "FULL" ]
lappend COMPONENTS [ list "LATENCY_METER"      $LATENCY_METER_BASE     "FULL" ]
lappend COMPONENTS [ list "FIFOX"              $FIFOX_BASE             "FULL" ]

# Source files for implemented component
lappend MOD "$ENTITY_BASE/mem_logger.vhd"

