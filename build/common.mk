# Makefile: Common make script for firmware targets
# Copyright (C) 2019 CESNET z. s. p. o.
# Author(s): Martin Spinler <spinler@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

# Some basic tools
RM ?= rm -f
TCLSH ?= tclsh

MAKE_REC = $(MAKE) -f $(firstword $(MAKEFILE_LIST)) --no-print-directory $(NETCOPE_ENV)

define print_label
	@echo '*****************************************************************************'
	@echo '* $(1)'
	@echo '*****************************************************************************'
endef

GEN_MK_NAME ?= $(OUTPUT_NAME).$(SYNTH).mk

# The generated .mk file $(GEN_MK_NAME) contains the $(MOD) variable
# (a list of all source filenames) and some dynamically TCL generated targets.
#
# All targets, which depends on $(MOD) variable, must be called in two phases:
# 1. Main run of make:
# 		- target depends on $(GEN_MK_NAME) only (this will generate the file)
# 		- target executes recursion of make
# 2. Recursive run of make:
# 		- already generated file $(GEN_MK_NAME) is included
# 		- $(MOD) variable can be used to determine dependencies
#		- real target is executed
#
# Rule for $(GEN_MK_NAME) is better than previous approach (in which the file
# was generated always, in the parse phase of the main Makefile):
# - it reflects target-specific assignments
# - output of the process of generation $(GEN_MK_NAME) can be printed to user
# - allows user to include this Makefile system even some Modules.tcl not yet exists

# a) In the recursive run of make include the generated file $(GEN_MK_NAME)
# 	- all real rules must be specified in main Makefile and wrapped in similar condition
# b) In the main run of make create a rule for the $(GEN_MK_NAME) and rule for all targets, which needs $(GEN_MK_NAME)
#   - user must specify all those targets in the $(GEN_MK_TARGETS) variable within main Makefile
ifneq ($(GEN_MK_TARGET),)
include $(GEN_MK_NAME)
else
.PHONY: $(GEN_MK_NAME)
$(GEN_MK_NAME):
	$(call print_label,Generate Makefile "$(GEN_MK_NAME)" with prerequisites)
	@$(NETCOPE_ENV) $(TCLSH) $(SYNTHFILES) -t makefile -p $(GEN_MK_NAME)

$(GEN_MK_TARGETS): $(GEN_MK_NAME)
	@$(MAKE_REC) $(GEN_MK_ENV) GEN_MK_TARGET=1 $@
endif
