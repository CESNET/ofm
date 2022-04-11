# Modules.tcl: Components include script
# Copyright (C) 2019 CESNET z. s. p. o.
# Author(s): Jan Kubalek <xkubal11@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

# Set paths
global FIRMWARE_BASE

set COMP_BASE                "$FIRMWARE_BASE/comp"
set PKG_BASE                 "$OFM_PATH/comp/base/pkg"

# Packages
set PACKAGES "$PACKAGES $PKG_BASE/math_pack.vhd"
set PACKAGES "$PACKAGES $PKG_BASE/type_pack.vhd"

# Source files for implemented component
set MOD "$MOD $ENTITY_BASE/n_to_m_handshake.vhd"
