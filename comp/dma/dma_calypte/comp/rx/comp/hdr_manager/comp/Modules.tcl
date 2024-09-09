# Modules.tcl: Components include script
# Copyright (C) 2022 CESNET
# Author(s): Radek Iša <isa@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause


lappend COMPONENTS [ list "COMP" "$ENTITY_BASE/comp"             "FULL" ]
lappend COMPONENTS [ list "PIPE" "$OFM_PATH/comp/base/misc/pipe" "FULL" ]

lappend MOD "$ENTITY_BASE/pcie_addr_gen.vhd"
