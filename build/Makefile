# Makefile: Common make script for firmware targets
# Copyright (C) 2019 CESNET z. s. p. o.
# Author(s): Martin Spinler <spinler@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

SYNTH ?= vivado

MAKEFILE_BASE ?= $(dir $(lastword $(MAKEFILE_LIST)))
FIRMWARE_BASE ?= $(MAKEFILE_BASE)../
OFM_PATH ?= $(MAKEFILE_BASE)../

# Select main Makefile with SYNTH tool variable
ifeq ($(SYNTH),vivado)
	SYNTH_MAKEFILE := build/Makefile.Vivado.inc
else ifeq ($(findstring quartus,$(SYNTH)),quartus)
	SYNTH_MAKEFILE := build/Makefile.Quartus.inc
else
	$(error "Unknown synth tool '$(SYNTH)', please update common Makefile")
endif

include $(OFM_PATH)$(SYNTH_MAKEFILE)

# For lazy users
.PHONY: vivado quartus
vivado quartus:
	@$(MAKE) SYNTH=$@
