# Modules.tcl: Components include script
# Copyright (C) 2023 CESNET z. s. p. o.
# Author(s): Yaroslav Marushchenko <xmarus09@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

set MFB_PIPE_BASE   "$OFM_PATH/comp/mfb_tools/flow/pipe"

# Packages
lappend PACKAGES "$OFM_PATH/comp/base/pkg/math_pack.vhd"
lappend PACKAGES "$OFM_PATH/comp/base/pkg/type_pack.vhd"

lappend COMPONENTS [ list "MFB_PIPE"      $MFB_PIPE_BASE      "FULL" ]

# Source files for implemented component
lappend MOD "$ENTITY_BASE/mfb_frame_masker.vhd"

