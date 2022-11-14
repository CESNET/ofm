# Makefile:
# Copyright (C) 2022 CESNET
# Author(s): Radek Isa <isa@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

include ../../../build/paths.mk

libnfb_driver.so:nfb_driver.c
	gcc -std=gnu11 -I$(MODELSIM_PATH)/include -fPIC nfb_driver.c -o nfb_driver.o -c
	ld -shared -o libnfb_driver.so nfb_driver.o -lrt

#libnfb-ext-sv.so:nfb-ext-sv.c
#	gcc -std=gnu11 -I$(MODELSIM_PATH)/include -fPIC nfb-ext-sv.c -o nfb-ext-sv.o -c
#	ld -shared -o libnfb-ext-sv.so nfb-ext-sv.o -lpcap


