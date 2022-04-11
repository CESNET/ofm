# Modules.tcl: Local include Modules tcl script
# Copyright (C) 2017 CESNET
# Author: Luk� Kekely <kekely@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause


set PACKAGES "$PACKAGES $OFM_PATH/comp/base/pkg/math_pack.vhd"

set MOD "$MOD $ENTITY_BASE/shifter_one.vhd"
set MOD "$MOD $ENTITY_BASE/shifter.vhd"
