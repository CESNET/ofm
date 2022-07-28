# top.do: tcl script for functional verification
# Copyright (C) 2020 CESNET
# Author: Radek Iša <isa@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

set FIRMWARE_BASE "../../../../../.."
set MAKEFILE_GEN "true"
set ENTYTY_BASE  ".."

set TB_FILE "./tbench/tbench.sv"

set COMPONENTS [ list \
    [list "DUT"     "$ENTYTY_BASE"      "FULL"]\
    [list "TB"      "$ENTYTY_BASE/ver"  "FULL"]\
]

set SIM_FLAGS(EXTRA_VFLAGS) "+UVM_TESTNAME=test::ex_test -uvmcontrol=all"

source "$FIRMWARE_BASE/build/Modelsim.inc.fdo"
set NumericStdNoWarnings 1

exec make
restart -f
run -all
