# demux.vhd: General width MVB DEMUX
# Copyright (C) 2023 CESNET z. s. p. o.
# Author(s): Oliver Gurka <xgurka00@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause


set MUX_BASE            "$OFM_PATH/comp/base/logic/mux"
set DEMUX_BASE          "$OFM_PATH/comp/base/logic/demux"
set MVB_DEC1FN_BASE     "$OFM_PATH/comp/base/logic/dec1fn"
set MVB_FORK_BASE       "$OFM_PATH/comp/mvb_tools/flow/fork"
set MVB_PIPE_BASE       "$OFM_PATH/comp/mvb_tools/flow/pipe"


# Packages
lappend PACKAGES "$OFM_PATH/comp/base/pkg/math_pack.vhd"
lappend PACKAGES "$OFM_PATH/comp/base/pkg/type_pack.vhd"

# Components
lappend COMPONENTS [ list "MUX"         $MUX_BASE           "FULL" ]
lappend COMPONENTS [ list "DEMUX"       $DEMUX_BASE         "FULL" ]
lappend COMPONENTS [ list "MVB_DEC1FN"  $MVB_DEC1FN_BASE    "FULL" ]
lappend COMPONENTS [ list "MVB_FORK"    $MVB_FORK_BASE      "FULL" ]
lappend COMPONENTS [ list "MVB_PIPE"    $MVB_PIPE_BASE      "FULL" ]

# Source files for implemented component
lappend MOD "$ENTITY_BASE/demux.vhd"
lappend MOD "$ENTITY_BASE/demux2.vhd"
