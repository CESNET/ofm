# ver_settings.py
# Copyright (C) 2023 CESNET z. s. p. o.
# Author(s): Yaroslav Marushchenko <xmarus09@stud.fit.vutbr.cz>

SETTINGS = {
    "default" : { # The default setting of verification
        "MFB_REGIONS"        : "2",
        "MFB_REGION_SIZE"    : "1",
        "MFB_BLOCK_SIZE"     : "8",
        "MFB_ITEM_WIDTH"     : "32",
        "MFB_META_WIDTH"     : "2",
        "USE_PIPE"           : "0",
        "FRAME_SIZE_MAX"     : "1500",
        "FRAME_SIZE_MIN"     : "60",
    },
    "pcie" : {
        "MFB_REGIONS"        : "2",
        "MFB_REGION_SIZE"    : "1",
        "MFB_BLOCK_SIZE"     : "8",
        "MFB_ITEM_WIDTH"     : "32",
    },
    "region_comb_1" : {
        "MFB_REGIONS"        : "8",
        "MFB_REGION_SIZE"    : "8",
        "MFB_BLOCK_SIZE"     : "8",
    },
    "region_comb_2" : {
        "MFB_REGIONS"        : "8",
        "MFB_REGION_SIZE"    : "8",
        "MFB_BLOCK_SIZE"     : "8",
    },
    "region_comb_3" : {
        "MFB_REGIONS"        : "8",
        "MFB_REGION_SIZE"    : "8",
        "MFB_BLOCK_SIZE"     : "8",
    },
    "region_comb_4" : {
        "MFB_REGIONS"        : "1",
        "MFB_REGION_SIZE"    : "8",
        "MFB_BLOCK_SIZE"     : "32",
    },
    "region_comb_5" : {
        "MFB_REGIONS"        : "1",
        "MFB_REGION_SIZE"    : "8",
        "MFB_BLOCK_SIZE"     : "2",
    },
    "region_comb_6" : {
        "MFB_REGIONS"        : "4",
    },
    "region_comb_7" : {
        "MFB_REGIONS"        : "16",
    },
    "region_comb_8" : {
        "MFB_REGIONS"        : "32",
    },
    "region_size_comb" : {
        "MFB_REGION_SIZE"    : "4",
    },
    "big_frames" : {
        "FRAME_SIZE_MIN"     : "4096",
        "FRAME_SIZE_MAX"     : "8192",
        "MFB_ITEM_WIDTH"     : "32",
        "MFB_META_WIDTH"     : "32",
    },
    "medium_frames" : {
        "FRAME_SIZE_MIN"     : "2048",
        "FRAME_SIZE_MAX"     : "4096",
        "MFB_ITEM_WIDTH"     : "16",
        "MFB_META_WIDTH"     : "16",
    },
    "small_frames" : {
        "FRAME_SIZE_MIN"     : "32",
        "FRAME_SIZE_MAX"     : "512",
        "MFB_ITEM_WIDTH"     : "8",
        "MFB_META_WIDTH"     : "8",
    },
    "pipe_enabled" : {
        "USE_PIPE"           : "1",
    },
    "_combinations_" : (  
    (), # Works the same as '("default",),' as the "default" is applied in every combination
    ("pipe_enabled",),
    ("region_comb_1",),
    ("region_comb_1", "pipe_enabled"),
    ("region_comb_2",),
    ("region_comb_2", "pipe_enabled"),
    ("region_comb_3",),
    ("region_comb_3", "pipe_enabled"),
    ("region_comb_4",),
    ("region_comb_4", "pipe_enabled"),
    ("region_comb_5",),
    ("region_comb_5", "pipe_enabled"),
    ("pcie",),
    ("pcie", "pipe_enabled"),
    ("big_frames",),
    ("big_frames", "pipe_enabled"),
    ("medium_frames",),
    ("medium_frames", "pipe_enabled"),
    ("small_frames",),
    ("small_frames", "pipe_enabled"),
    ("medium_frames", "region_comb_3"),
    ("medium_frames", "region_comb_3", "pipe_enabled"),
    ("small_frames",  "region_comb_2"),
    ("small_frames",  "region_comb_2", "pipe_enabled"),
    ("medium_frames", "region_comb_3"),
    ("medium_frames", "region_comb_3", "pipe_enabled"),
    ("small_frames",  "region_comb_6", "region_size_comb"),
    ("small_frames",  "region_comb_6", "region_size_comb", "pipe_enabled"),
    ("small_frames",  "region_comb_7", "region_size_comb"),
    ("small_frames",  "region_comb_7", "region_size_comb", "pipe_enabled"),
    ("small_frames",  "region_comb_8", "region_size_comb"),
    ("small_frames",  "region_comb_8", "region_size_comb", "pipe_enabled"),
    ),
}