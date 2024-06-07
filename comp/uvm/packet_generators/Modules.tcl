# Modules.tcl: Components include script
# Copyright (C) 2024 CESNET z. s. p. o.
# Author(s): Yaroslav Marushchenko <xmarus09@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

# Set paths
set SV_UVM_BASE         "$OFM_PATH/comp/uvm"

lappend COMPONENTS \
        [ list "SV_LOGIC_VECTOR_ARRAY_UVM_BASE" "$SV_UVM_BASE/logic_vector_array" "FULL"] \
        [ list "SV_SEQUENCE_FLOWTEST_BASE"      "$ENTITY_BASE/ft_gen_sequence"    "FULL"] \

lappend MOD "$ENTITY_BASE/pkg.sv"
