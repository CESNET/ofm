# Modules.tcl: Components include script
# Copyright (C) 2023 CESNET z. s. p. o.
# Author(s): Daniel Kondys <kondys@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

# Paths to components
set BASE_BASE                "$OFM_PATH/comp/base"
set MFB_FIFOX_BASE           "$OFM_PATH/comp/mfb_tools/storage/fifox"
set MVB_LAST_VLD_BASE        "$OFM_PATH/comp/mvb_tools/aggregate/last_vld"

# Packages
lappend PACKAGES "$OFM_PATH/comp/base/pkg/math_pack.vhd"
lappend PACKAGES "$OFM_PATH/comp/base/pkg/type_pack.vhd"

lappend COMPONENTS [ list "FIFOX_MULTI"       "$BASE_BASE/fifo/fifox_multi"   "FULL" ]
lappend COMPONENTS [ list "GEN_ENC"           "$BASE_BASE/logic/enc"          "FULL" ]
lappend COMPONENTS [ list "DSP_COUNTER"       "$BASE_BASE/dsp/dsp_counter"    "FULL" ]
lappend COMPONENTS [ list "MVB_LAST_VLD"      $MVB_LAST_VLD_BASE              "FULL" ]
lappend COMPONENTS [ list "MFB_FIFOX"         $MFB_FIFOX_BASE                 "FULL" ]

# Source files for implemented component
lappend MOD "$ENTITY_BASE/mfb_packet_delayer.vhd"

