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

        "FIFO_DEPTH"              : "512",
        "CHANNELS"                : "2",
        "CNTRS_WIDTH"             : "64",
        "HDR_META_WIDTH"          : "24",
        "PKT_SIZE_MAX"            : "2**11",
        "CHANNEL_ARBITER_EN"      : "0",

        "PCIE_LEN_MIN"            : "1",
        "PCIE_LEN_MAX"            : "256",
    },
    "4_channels" : {
        "CHANNELS"                : "4",
    },
    "8_channels" : {
        "CHANNELS"                : "8",
    },
    "channel_arb_en" : {
        "CHANNEL_ARBITER_EN"      : "1",
    },
    "fifo_depth_comb_small" : {
        "FIFO_DEPTH"              : "64",
    },
    "fifo_depth_comb_large" : {
        "FIFO_DEPTH"              : "512",
    },
    "small_dma_frames" : {
        "PKT_SIZE_MAX"            : "2**11",
    },
    "large_dma_frames" : {
        "PKT_SIZE_MAX"            : "2**11",
    },
    "min_pcie_frames" : {
        "PCIE_LEN_MIN"            : "1",
        "PCIE_LEN_MAX"            : "2",
    },
    "medium_pcie_frames" : {
        "PCIE_LEN_MIN"            : "2",
        "PCIE_LEN_MAX"            : "128",
    },
    "large_pcie_frames" : {
        "PCIE_LEN_MIN"            : "128",
        "PCIE_LEN_MAX"            : "256",
    },
    "_combinations_" : (
    # (                                                                  ), # default
    # (             "4_channels",                                        ),
    (             "8_channels",                                        ),
    (                           "channel_arb_en",                      ),
    # (             "4_channels", "channel_arb_en",                      ),
    # (             "8_channels", "channel_arb_en",                      ),
    # (                                             "min_pcie_frames"   ,),
    # (                                             "medium_pcie_frames",),
    # (                                             "large_pcie_frames" ,),
    # (             "4_channels"                  , "medium_pcie_frames",),
    # (             "4_channels"                  , "min_pcie_frames"   ,),
    # (             "4_channels"                  , "large_pcie_frames" ,),
    # (             "8_channels"                  , "min_pcie_frames"   ,),
    # (             "8_channels"                  , "medium_pcie_frames",),
    # (             "8_channels"                  , "large_pcie_frames" ,),
    # (             "4_channels", "channel_arb_en", "min_pcie_frames"   ,),
    # (             "4_channels", "channel_arb_en", "medium_pcie_frames",),
    # (             "4_channels", "channel_arb_en", "large_pcie_frames" ,),
    # (             "8_channels", "channel_arb_en", "min_pcie_frames"   ,),
    # (             "8_channels", "channel_arb_en", "medium_pcie_frames",),
    # (             "8_channels", "channel_arb_en", "large_pcie_frames" ,),
    # (                           "channel_arb_en", "min_pcie_frames"   ,),
    # (                           "channel_arb_en", "medium_pcie_frames",),
    # (                           "channel_arb_en", "large_pcie_frames" ,),
    # (             "4_channels", "channel_arb_en", "large_pcie_frames" ,),
    # (             "4_channels", "channel_arb_en", "medium_pcie_frames",),
    # (             "4_channels", "channel_arb_en", "min_pcie_frames"   ,),
    # (             "8_channels", "channel_arb_en", "large_pcie_frames" ,),
    # (             "8_channels", "channel_arb_en", "medium_pcie_frames",),
    # (                                                                 "fifo_depth_comb_small",),
    (             "4_channels",                                       "fifo_depth_comb_small",),
    # (                                             "min_pcie_frames",  "fifo_depth_comb_small",),
    # (             "8_channels",                   "min_pcie_frames",  "fifo_depth_comb_small",),
    # (             "8_channels",                                       "fifo_depth_comb_small",),
    # (             "8_channels", "channel_arb_en",                     "fifo_depth_comb_small",),
    # (             "8_channels", "channel_arb_en", "min_pcie_frames",  "fifo_depth_comb_small",),
    ),
}
