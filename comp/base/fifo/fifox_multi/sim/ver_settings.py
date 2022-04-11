# ver_settings.py
# Copyright (C) 2019 CESNET z. s. p. o.
# Author(s): Jan Kubalek <xkubal11@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

SETTINGS = {
    "default" : { # The default setting of verification
        "s_WRITE_PORTS"          : "1"     ,
        "s_READ_PORTS"           : "1"     ,
        "s_SAFE_READ_MODE"       : "false" ,
        "USE_SHAKEDOWN_ARCH"     : "false" ,
    },
    "3_wr_ports" : {
        "s_WRITE_PORTS"          : "3"     ,
    },
    "3_rd_ports" : {
        "s_READ_PORTS"           : "3"     ,
    },
    "safe_read_mode" : {
        "s_SAFE_READ_MODE"       : "true"  ,
    },
    "shakedown" : {
        "USE_SHAKEDOWN_ARCH"     : "true"  ,
    },
    "_combinations_" : (
    (), # Works the same as '("default",),' as the "default" as applied in every combination
    ("3_wr_ports",                                          ),
    (             "3_rd_ports",                             ),
    ("3_wr_ports","3_rd_ports",                             ),
    (                          "safe_read_mode",            ),
    ("3_wr_ports",             "safe_read_mode",            ),
    (             "3_rd_ports","safe_read_mode",            ),
    ("3_wr_ports","3_rd_ports","safe_read_mode",            ),
    (                                           "shakedown",),
    ("3_wr_ports",                              "shakedown",),
    (             "3_rd_ports",                 "shakedown",),
    ("3_wr_ports","3_rd_ports",                 "shakedown",),
    (                          "safe_read_mode","shakedown",),
    ("3_wr_ports",             "safe_read_mode","shakedown",),
    (             "3_rd_ports","safe_read_mode","shakedown",),
    ("3_wr_ports","3_rd_ports","safe_read_mode","shakedown",),
    ),
#    "" : { # 
#    },
}
