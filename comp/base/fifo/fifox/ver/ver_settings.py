# ver_settings.py : Setting for MultiVer script
# Copyright (C) 2021 CESNET z. s. p. o.
# Author(s): Tomáš Beneš <xbenes55@stud.fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

SETTINGS = {
    "default" : { # The default setting of verification
        "ITEMS"                                 : "1",
        "ITEM_WIDTH"                            : "16",
        "FIFO_ITEMS"                            : "16",
        "RAM_TYPE"                              : "\\\"AUTO\\\"",
        "DEVICE"                                : "\\\"ULTRASCALE\\\"",
        "ALMOST_FULL_OFFSET"                    : "1",
        "ALMOST_EMPTY_OFFSET"                   : "1",
        "FAKE_FIFO"                             : "0",
    },
    "WRONG_DEVICE":{
        "DEVICE"                                : "\\\"RANDOM_DEVICE\\\"",
    },
    "WRONG_RAM_TYPE":{
        "RAM_TYPE"                              : "\\\"RANDOM_RAM_TYPE\\\"",
    },
    "8_ITEMS":{
        "FIFO_ITEMS"                            : "8",
    },
    "64_ITEMS":{
        "FIFO_ITEMS"                            : "64",
    },
    "128_ITEMS":{
        "FIFO_ITEMS"                            : "128",
    },
    "1024_ITEMS":{
        "FIFO_ITEMS"                            : "1024",
    },
    "512_WIDTH"   :{
        "ITEM_WIDTH"                             : "512",
    },
    "LUT_TYPE"   :{
        "RAM_TYPE"                              : "\\\"LUT\\\"",
    },
    "BRAM_TYPE"  :{
        "RAM_TYPE"                              : "\\\"BRAM\\\"",
    },
    "URAM_TYPE"  :{
        "RAM_TYPE"                              : "\\\"URAM\\\"",
    },
    "SHIFT_TYPE" :{
        "RAM_TYPE"                              : "\\\"SHIFT\\\"",
    },
    "ALMOST_FULL_HALF"  :{
        "ALMOST_FULL_OFFSET"                    : "8",
    },
    "ALMOST_EMPTY_HALF"  :{
        "ALMOST_EMPTY_OFFSET"                   : "8",
    },  
    "INTEL"  : {
        "DEVICE"                                : "\\\"STRATIX10\\\"" ,
    },
    "FAKE_FIFO_EN"  : {
        "FAKE_FIFO"                             : "1" ,
    },
    "_combinations_" : (
    (),
        ('WRONG_DEVICE',                                                                                                             ),
        ('WRONG_RAM_TYPE',                                                                                                           ),
        ('8_ITEMS',                                                                                                                  ),
        ('64_ITEMS',                                                                                                                 ),
        ('128_ITEMS',                                                                                                                ),
        ('1024_ITEMS',  '512_WIDTH',                                                                                                 ),
        ('INTEL',                                                                                                                    ),
        ('INTEL',       '64_ITEMS',                                                                                                  ),
        (               'FAKE_FIFO_EN',                                                                                              ),
        (                               'ALMOST_EMPTY_HALF',                                                                         ),
        (                                                       'ALMOST_FULL_HALF',                                                  ),
        (                               'ALMOST_EMPTY_HALF',    'ALMOST_FULL_HALF',                                                  ),
        (               'FAKE_FIFO_EN', 'ALMOST_EMPTY_HALF',    'ALMOST_FULL_HALF',                                                  ),
        ('INTEL',       'FAKE_FIFO_EN', 'ALMOST_EMPTY_HALF',    'ALMOST_FULL_HALF',                                                  ),
        (                                                                           'LUT_TYPE',                                      ),
        ('INTEL',                                                                   'LUT_TYPE',                                      ),
        (               'FAKE_FIFO_EN',                                             'LUT_TYPE',                                      ),
        (                               'ALMOST_EMPTY_HALF',                        'LUT_TYPE',                                      ),
        (                                                       'ALMOST_FULL_HALF', 'LUT_TYPE',                                      ),
        ('INTEL',       'FAKE_FIFO_EN', 'ALMOST_EMPTY_HALF',    'ALMOST_FULL_HALF', 'LUT_TYPE',                                      ),
        (                                                                                       'BRAM_TYPE',                         ),
        ('INTEL',                                                                               'BRAM_TYPE',                         ),
        (               'FAKE_FIFO_EN',                                                         'BRAM_TYPE',                         ),
        (                               'ALMOST_EMPTY_HALF',                                    'BRAM_TYPE',                         ),
        (                                                       'ALMOST_FULL_HALF',             'BRAM_TYPE',                         ),
        ('INTEL',       'FAKE_FIFO_EN', 'ALMOST_EMPTY_HALF',    'ALMOST_FULL_HALF',             'BRAM_TYPE',                         ),
        (                                                                                                   'URAM_TYPE',             ),
        ('INTEL',                                                                                           'URAM_TYPE',             ),
        (               'FAKE_FIFO_EN',                                                                     'URAM_TYPE',             ),
        (                               'ALMOST_EMPTY_HALF',                                                'URAM_TYPE',             ),
        (                                                       'ALMOST_FULL_HALF',                         'URAM_TYPE',             ),
        ('INTEL',       'FAKE_FIFO_EN', 'ALMOST_EMPTY_HALF',    'ALMOST_FULL_HALF',                         'URAM_TYPE',             ),
        (                                                                                                               'SHIFT_TYPE',),
        ('INTEL',                                                                                                       'SHIFT_TYPE',),
        (               'FAKE_FIFO_EN',                                                                                 'SHIFT_TYPE',),
        (                               'ALMOST_EMPTY_HALF',                                                            'SHIFT_TYPE',),
        (                                                       'ALMOST_FULL_HALF',                                     'SHIFT_TYPE',),
        ('INTEL',       'FAKE_FIFO_EN', 'ALMOST_EMPTY_HALF',    'ALMOST_FULL_HALF',                                     'SHIFT_TYPE',),
    ),
}
