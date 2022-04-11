# Modules.tcl: Components include script
# Copyright (C) 2019 CESNET z. s. p. o.
# Author(s): Jakub Cabal <cabal@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

# Set paths

# Paths to components
set PKG_BASE                 "$OFM_PATH/comp/base/pkg"
set SDP_BRAM_BASE            "$OFM_PATH/comp/base/mem/sdp_bram"
set GEN_LUTRAM_BASE          "$OFM_PATH/comp/base/mem/gen_lutram"
set ASYNC_OPEN_LOOP_SMD_BASE "$OFM_PATH/comp/base/async/open_loop_smd"

# Packages
set PACKAGES "$PACKAGES $PKG_BASE/math_pack.vhd"

# Components
set COMPONENTS [concat $COMPONENTS [list \
   [ list "SDP_BRAM_BEHAV"      $SDP_BRAM_BASE            "FULL"      ] \
   [ list "GEN_LUTRAM"          $GEN_LUTRAM_BASE          "FULL"      ] \
   [ list "ASYNC_OPEN_LOOP_SMD" $ASYNC_OPEN_LOOP_SMD_BASE "FULL"      ]
]]

# Source files for implemented component
set MOD "$MOD $ENTITY_BASE/asfifox.vhd"
