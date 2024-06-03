# ver_settings.py : Setting for MultiVer script
# Copyright (C) 2020 CESNET z. s. p. o.
# Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

SETTINGS = {
    "default" : { # The default setting of verification
        "MAX_NUMBER_OF_PACKETS_TO_BE_REMOVED"   : "1" ,
        "NUMBER_OF_STREAMS"                     : "4" ,
        "NUMBER_OF_PACKETS"                     : "4" ,
        "META_WIDTH"                            : "1" ,
        "PACKET_SIZE"                           : "64" ,
        "SPACE_SIZE"                            : "2**14" ,
        "GAP_SIZE"                              : "12" ,
        "MINIMAL_GAP_SIZE"                      : "GAP_SIZE-4" ,
        "ADRESS_ALIGNMENT"                      : "8" ,                                         
        "FIFO_ITEMS"                            : "16" ,
        "FIFO_AFULL"                            : "FIFO_ITEMS\/2" ,
        "STREAM_OUTPUT_EN"                      : "1" ,
        "GLOBAL_OUTPUT_EN"                      : "1" ,
        "STREAM_OUTPUT_AFULL"                   : "0" ,
        "GLOBAL_OUTPUT_AFULL"                   : "0" ,   
    },
    "STREAM_EN" : {
        "STREAM_OUTPUT_EN"                      : "1" ,
        "GLOBAL_OUTPUT_EN"                      : "0" ,
    },
    "GLOBAL_EN" : {
        "STREAM_OUTPUT_EN"                      : "0" ,
        "GLOBAL_OUTPUT_EN"                      : "1" ,
    },
    "STREAM_AFULL" :{
        "STREAM_OUTPUT_AFULL"                   : "1" ,
    },
    "GLOBAL_AFULL" : {
        "GLOBAL_OUTPUT_AFULL"                   : "1" ,   
    },
    "SMALL_PACKETS" : {
        "PACKET_SIZE"                           : "32" ,
    },
    "BIG_PACKETS"   : {
        "PACKET_SIZE"                           : "128" ,
    },
    "BIG_METADATA"  : {
        "META_WIDTH"                            : "16" ,
    },
    "_combinations_" : (
    (),
        ('STREAM_EN',                                                                                               ),
        (               'GLOBAL_EN',                                                                                ),
        (                           'STREAM_AFULL',                                                                 ),
        (                                           'GLOBAL_AFULL',                                                 ),
        (                                                           'SMALL_PACKETS',                                ),
        (                                                                           'BIG_PACKETS',                  ),
        (                                                                                           'BIG_METADATA', ),
        ('STREAM_EN',               'STREAM_AFULL',                                                                 ),
        ('STREAM_EN',                                               'SMALL_PACKETS',                                ),
        ('STREAM_EN',                                                               'BIG_PACKETS',                  ),
        ('STREAM_EN',                                                                               'BIG_METADATA', ),
        (               'GLOBAL_EN',                'GLOBAL_AFULL',                                                 ),
        (               'GLOBAL_EN',                                'SMALL_PACKETS',                                ),
        (               'GLOBAL_EN',                                                'BIG_PACKETS',                  ),
        (               'GLOBAL_EN',                                                                'BIG_METADATA', ),
        (                           'STREAM_AFULL', 'GLOBAL_AFULL',                                                 ),
        (                           'STREAM_AFULL',                 'SMALL_PACKETS',                                ),
        (                           'STREAM_AFULL',                                 'BIG_PACKETS',                  ),
        (                           'STREAM_AFULL',                                                 'BIG_METADATA', ),
        (                                           'GLOBAL_AFULL', 'SMALL_PACKETS',                                ),
        (                                           'GLOBAL_AFULL',                 'BIG_PACKETS',                  ),
        (                                           'GLOBAL_AFULL',                                 'BIG_METADATA', ),
        (                                                           'SMALL_PACKETS',                'BIG_METADATA', ),
        (                                                                           'BIG_PACKETS',  'BIG_METADATA', ),
        ('STREAM_EN',               'STREAM_AFULL',                 'SMALL_PACKETS',                                ),
        ('STREAM_EN',               'STREAM_AFULL',                                 'BIG_PACKETS',                  ),
        ('STREAM_EN',               'STREAM_AFULL',                                                 'BIG_METADATA', ),
        ('STREAM_EN',                                               'SMALL_PACKETS',                'BIG_METADATA', ),
        ('STREAM_EN',                                                               'BIG_PACKETS',  'BIG_METADATA', ),
        (               'GLOBAL_EN',                'GLOBAL_AFULL', 'SMALL_PACKETS',                                ),
        (               'GLOBAL_EN',                'GLOBAL_AFULL',                 'BIG_PACKETS',                  ),
        (               'GLOBAL_EN',                'GLOBAL_AFULL',                                 'BIG_METADATA', ),
        (               'GLOBAL_EN',                                'SMALL_PACKETS',                'BIG_METADATA', ),
        (               'GLOBAL_EN',                                                'BIG_PACKETS',  'BIG_METADATA', ),
        (                           'STREAM_AFULL', 'GLOBAL_AFULL', 'SMALL_PACKETS',                                ),
        (                           'STREAM_AFULL', 'GLOBAL_AFULL',                 'BIG_PACKETS',                  ),
        (                           'STREAM_AFULL', 'GLOBAL_AFULL',                                 'BIG_METADATA', ),
        (                           'STREAM_AFULL',                 'SMALL_PACKETS',                'BIG_METADATA', ),
        (                           'STREAM_AFULL',                                 'BIG_PACKETS',  'BIG_METADATA', ),
        (                                           'GLOBAL_AFULL', 'SMALL_PACKETS','BIG_PACKETS',                  ),
        (                                           'GLOBAL_AFULL', 'SMALL_PACKETS',                'BIG_METADATA', ),
        (                                           'GLOBAL_AFULL',                 'BIG_PACKETS',  'BIG_METADATA', ),
        ('STREAM_EN',               'STREAM_AFULL',                 'SMALL_PACKETS',                'BIG_METADATA', ),
        ('STREAM_EN',               'STREAM_AFULL',                                 'BIG_PACKETS',  'BIG_METADATA', ),
        (               'GLOBAL_EN',                'GLOBAL_AFULL', 'SMALL_PACKETS','BIG_PACKETS',                  ),
        (               'GLOBAL_EN',                'GLOBAL_AFULL', 'SMALL_PACKETS',                'BIG_METADATA', ),
        (               'GLOBAL_EN',                'GLOBAL_AFULL',                 'BIG_PACKETS',  'BIG_METADATA', ),
        (                           'STREAM_AFULL', 'GLOBAL_AFULL', 'SMALL_PACKETS',                'BIG_METADATA', ),
        (                           'STREAM_AFULL', 'GLOBAL_AFULL',                 'BIG_PACKETS',  'BIG_METADATA', ),
        (                           'STREAM_AFULL',                 'SMALL_PACKETS','BIG_PACKETS',  'BIG_METADATA', ),
        (                                           'GLOBAL_AFULL', 'SMALL_PACKETS','BIG_PACKETS',  'BIG_METADATA', ),
    ),
}