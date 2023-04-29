# load.tcl: load and define user DRC procedures
# Copyright (C) 2014 CESNET
# Author: Jan Kucera <xkucer73@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause
#
# $Id$
#


# define USER_DRC_BASE variable
set USER_DRC_BASE [file dirname [info script]]


# load DRC procedures
#source $USER_DRC_BASE/latch_drc.tcl
source $USER_DRC_BASE/asreg_drc.tcl
source $USER_DRC_BASE/datarst_drc.tcl
