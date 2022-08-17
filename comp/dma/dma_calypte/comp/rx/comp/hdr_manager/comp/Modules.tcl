# Modules.tcl: Components include script
# Copyright (C) 2022 CESNET
# Author(s): Vladislav Valek <xvalek14@vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause


lappend COMPONENTS [ list "COMP"  "$ENTITY_BASE/comp"                "FULL" ]


lappend MOD "$ENTITY_BASE/pcie_addr_gen_ent.vhd"
lappend MOD "$ENTITY_BASE/pcie_addr_gen_arch.vhd"

