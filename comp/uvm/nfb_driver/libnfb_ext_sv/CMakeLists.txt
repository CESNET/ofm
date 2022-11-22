# SPDX-License-Identifier: BSD-3-Clause
#
# CMake build file for NFB debug tools
#
# Copyright (C) 2022 CESNET
# Author(s):
#  Radek Iša <isa@cesnet.cz>
#

cmake_minimum_required(VERSION 3.5.1)

project(libnfb-ext-sv C)

include(GNUInstallDirs)

add_library(nfb-ext-sv SHARED nfb_sv.c)

target_link_libraries(nfb-ext-sv nfb rt)

install(TARGETS nfb-ext-sv
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

set(CPACK_PACKAGE_VERSION 0.1.0)
set(CPACK_GENERATOR "RPM")
include(CPack)
