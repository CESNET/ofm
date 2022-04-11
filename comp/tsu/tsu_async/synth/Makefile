# Makefile: Makefile to synthesize a single component in Vivado
# Copyright (C) 2016 CESNET
# Author: Jiri Matousek <matousek@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause
#
# $Id$
#


# ##### Definition of variables ###############################################

# Basic paths
FIRMWARE_BASE = ../../../../..

# Tcl file with NetCOPE values for generic parameters
# (if defined, uses the value from top level Makefile)
NETCOPE_CONST ?=

# Tcl file with user-defined values for generic parameters
# (if defined, uses the value from top level Makefile)
USER_CONST ?=

# Definition of export command for selected variables used by build system
# (variable used in $(FIRMWARE_BASE)/build/Makefile.Vivado.inc)
USER_ENV = FIRMWARE_BASE=$(FIRMWARE_BASE) \
	NETCOPE_CONST=$(NETCOPE_CONST) \
	USER_CONST=$(USER_CONST)

# Module name
# (variable used also in $(FIRMWARE_BASE)/build/Makefile.Vivado.inc)
MODULE = tsu_async


# ##### Definition of targets #################################################

.PHONY: build_module

build_module : $(MODULE).dcp


# ##### Including another Makefiles ###########################################

# General Makefile for builds using Vivado
# * defines target for building *.dcp file
# * defines 'clean' target depending also on CLEAN_DEPENDS variable
include $(FIRMWARE_BASE)/build/Makefile.Vivado.inc
