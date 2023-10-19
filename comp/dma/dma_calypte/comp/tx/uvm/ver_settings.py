# ver_settings.py
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

SETTINGS = {
    "default" : { # The default setting of verification
        "DEVICE"                  : "\\\"ULTRASCALE\\\"",

        "MI_WIDTH"                : "32",

        "USER_TX_MFB_REGIONS"     : "1",
        "USER_TX_MFB_REGION_SIZE" : "4",
        "USER_TX_MFB_BLOCK_SIZE"  : "8",
        "USER_TX_MFB_ITEM_WIDTH"  : "8",

        "PCIE_CQ_MFB_REGIONS"     : "1",
        "PCIE_CQ_MFB_REGION_SIZE" : "1",
        "PCIE_CQ_MFB_BLOCK_SIZE"  : "8",
        "PCIE_CQ_MFB_ITEM_WIDTH"  : "32",

        "PCIE_CC_MFB_REGIONS"     : "1",
        "PCIE_CC_MFB_REGION_SIZE" : "1",
        "PCIE_CC_MFB_BLOCK_SIZE"  : "8",
        "PCIE_CC_MFB_ITEM_WIDTH"  : "32",

        "CHANNELS"                : "2",
        "CNTRS_WIDTH"             : "64",
        "HDR_META_WIDTH"          : "24",
        "PKT_SIZE_MAX"            : "2**11",

        "DATA_POINTER_WIDTH"      : "14",
        "DMA_HDR_POINTER_WIDTH"   : "11",

        "PCIE_LEN_MIN"            : "1",
        "PCIE_LEN_MAX"            : "256",
    },
    "4_channels" : {
        "CHANNELS"                : "4",
    },
    "8_channels" : {
        "CHANNELS"                : "8",
    },
    "buff_size_comb_small" : {
        "DATA_POINTER_WIDTH"      : "13",
        "DMA_HDR_POINTER_WIDTH"   : "10",
    },
    "buff_size_comb_large" : {
        "DATA_POINTER_WIDTH"      : "16",
        "DMA_HDR_POINTER_WIDTH"   : "13",
    },
    "min_pcie_frames" : {
        "PCIE_LEN_MIN"            : "1",
        "PCIE_LEN_MAX"            : "32",
    },
    "medium_pcie_frames" : {
        "PCIE_LEN_MIN"            : "32",
        "PCIE_LEN_MAX"            : "128",
    },
    "large_pcie_frames" : {
        "PCIE_LEN_MIN"            : "128",
        "PCIE_LEN_MAX"            : "256",
    },
    "_combinations_" : (
    # (                                                                  ), # default
    # (             "4_channels",                                        ),
    (             "4_channels",                                        ),
    # (                                             "min_pcie_frames"   ,),
    # (                                             "medium_pcie_frames",),
    # (                                             "large_pcie_frames" ,),
    # (             "4_channels"                  , "medium_pcie_frames",),
    # (             "4_channels"                  , "min_pcie_frames"   ,),
    # (             "4_channels"                  , "large_pcie_frames" ,),
    (             "8_channels"                  , "min_pcie_frames"   ,),
    # (             "8_channels"                  , "medium_pcie_frames",),
    # (             "8_channels"                  , "large_pcie_frames" ,),
    (                                                                 "buff_size_comb_small",),
    (                                                                 "buff_size_comb_large",),
    # (             "4_channels",                                       "buff_size_comb_small",),
    # (                                             "min_pcie_frames",  "buff_size_comb_small",),
    # (             "8_channels",                   "min_pcie_frames",  "buff_size_comb_small",),
    # (             "8_channels",                                       "buff_size_comb_small",),
    ),
}
