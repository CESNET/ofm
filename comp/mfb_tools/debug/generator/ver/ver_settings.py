# ver_settings.py
# Copyright (C) 2020 CESNET z. s. p. o.
# Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

SETTINGS = {
    "default" : { # The default setting of verification
        "MFB_REGIONS"            : "4",
        "MFB_REGION_SIZE"        : "8",
        "MFB_BLOCK_SIZE"         : "8",
        "MFB_ITEM_WIDTH"         : "8",
    },
    "pcie" : {
        "MFB_REGIONS"            : "2",
        "MFB_REGION_SIZE"        : "1",
        "MFB_BLOCK_SIZE"         : "8",
        "MFB_ITEM_WIDTH"         : "32",
    },
    "region_comb_1" : {
        "MFB_REGIONS"            : "1",
        "MFB_REGION_SIZE"        : "8",
        "MFB_BLOCK_SIZE"         : "8",
        "MFB_ITEM_WIDTH"         : "8",
    },
    "region_comb_2" : {
        "MFB_REGIONS"            : "2",
        "MFB_REGION_SIZE"        : "8",
        "MFB_BLOCK_SIZE"         : "8",
        "MFB_ITEM_WIDTH"         : "8",
    },
    "region_comb_3" : {
        "MFB_REGIONS"            : "1",
        "MFB_REGION_SIZE"        : "4",
        "MFB_BLOCK_SIZE"         : "8",
        "MFB_ITEM_WIDTH"         : "8",
    },
    "_combinations_" : (  
    (), # Works the same as '("default",),' as the "default" is applied in every combination
    ("region_comb_1",),
    ("region_comb_2",),
    ("region_comb_3",),
    ("pcie",),
    ),
}