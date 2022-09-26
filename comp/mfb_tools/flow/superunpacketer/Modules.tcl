# Modules.tcl: Components include script
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Daniel Kondys <kondys@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

# Paths to components
set MFB_GET_ITEMS_BASE       "$OFM_PATH/comp/mfb_tools/logic/get_items"
set MFB_CUTTER_SIMPLE_BASE   "$OFM_PATH/comp/mfb_tools/flow/cutter_simple"
set META_INSERTOR_BASE       "$OFM_PATH/comp/mfb_tools/flow/metadata_insertor"
set MFB_PIPE_BASE            "$OFM_PATH/comp/mfb_tools/flow/pipe"
# set SUPKT_HDR_EXTRACTOR_BASE "$OFM_PATH/comp/mfb_tools/flow/superunpacketer/comp/supkt_hdr_extractor"

# Packages
lappend PACKAGES "$OFM_PATH/comp/base/pkg/math_pack.vhd"
lappend PACKAGES "$OFM_PATH/comp/base/pkg/type_pack.vhd"

lappend COMPONENTS [ list "MFB_GET_ITEMS"     $MFB_GET_ITEMS_BASE     "FULL" ]
lappend COMPONENTS [ list "MFB_CUTTER_SIMPLE" $MFB_CUTTER_SIMPLE_BASE "FULL" ]
lappend COMPONENTS [ list "META_INSERTOR"     $META_INSERTOR_BASE     "FULL" ]
lappend COMPONENTS [ list "MFB_PIPE"          $MFB_PIPE_BASE          "FULL" ]
# lappend COMPONENTS [ list "SUPKT_HDR_EXTRACTOR" $SUPKT_HDR_EXTRACTOR_BASE "FULL" ]

# Source files for implemented component
lappend MOD "$ENTITY_BASE/supkt_hdr_extractor.vhd"
lappend MOD "$ENTITY_BASE/superunpacketer.vhd"
lappend MOD "$ENTITY_BASE/DevTree.tcl"

