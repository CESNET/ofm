# Modules.tcl: Components include script
# Copyright (C) 2021 CESNET z. s. p. o.
# Author(s): Radek Iša <isa@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

# Set paths
set UVM_PATH "$OFM_PATH/comp/uvm" 

lappend COMPONENTS \
      [ list "SV_COMMON"                 "$UVM_PATH/common"                   "FULL"] \
      [ list "SV_RESET"                  "$UVM_PATH/reset"                    "FULL"] \
      [ list "SV_BYTE_ARRAY_MFB"         "$UVM_PATH/byte_array_mfb"           "FULL"] \
      [ list "SV_LOGIC_VECTOR_ARRAY_MFB" "$UVM_PATH/logic_vector_array_mfb"   "FULL"] \
      [ list "SV_MVB"                    "$UVM_PATH/mvb"                      "FULL"] \
      [ list "SV_MI"                     "$UVM_PATH/mi"                       "FULL"] \

lappend MOD "$OFM_PATH/comp/base/pkg/pcie_meta_pack.sv"

lappend MOD "$ENTITY_BASE/tbench/info/pkg.sv"
lappend MOD "$ENTITY_BASE/tbench/rx_env/pkg.sv"
lappend MOD "$ENTITY_BASE/tbench/env/pkg.sv"
lappend MOD "$ENTITY_BASE/tbench/tests/pkg.sv"

lappend MOD "$ENTITY_BASE/tbench/dut.sv"
lappend MOD "$ENTITY_BASE/tbench/property.sv"
lappend MOD "$ENTITY_BASE/tbench/testbench.sv"
