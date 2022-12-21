# synth_settings.py
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Vladislav Valek <valekv@cesnet.cz>

SETTINGS = {
    "default" : { # The default setting of verification
        "DEVICE"                    : "\\\"ULTRASCALE\\\"",
        "MI_WIDTH"                  : "32",
        "USR_TX_MFB_REGIONS"        : "1",
        "USR_TX_MFB_REGION_SIZE"    : "4",
        "USR_TX_MFB_BLOCK_SIZE"     : "8",
        "USR_TX_MFB_ITEM_WIDTH"     : "8",
        "PCIE_CQ_MFB_REGIONS"       : "1",
        "PCIE_CQ_MFB_REGION_SIZE"   : "1",
        "PCIE_CQ_MFB_BLOCK_SIZE"    : "8",
        "PCIE_CQ_MFB_ITEM_WIDTH"    : "32",
        "PCIE_CC_MFB_REGIONS"       : "1",
        "PCIE_CC_MFB_REGION_SIZE"   : "1",
        "PCIE_CC_MFB_BLOCK_SIZE"    : "8",
        "PCIE_CC_MFB_ITEM_WIDTH"    : "32",
        "FIFO_DEPTH"                : "512",
        "CHANNELS"                  : "8",
        "CNTRS_WIDTH"               : "64",
        "HDR_META_WIDTH"            : "24",
        "PKT_SIZE_MAX"              : "2**11",
        "CHANNEL_ARBITER_EN"        : "FALSE",
    },
    "vivado" : {
        "DEVICE" : "\\\"ULTRASCALE\\\"",
    },
    "minimal_fifo" : {
        "FIFO_DEPTH" : "64",
    },
    "largest_fifo" : {
        "FIFO_DEPTH" : "2048",
    },
    "minimal_pkt_size" : {
        "PKT_SIZE_MAX" : "2**2",
    },
    "largest_pkt_size" : {
        "PKT_SIZE_MAX" : "2**16 - 1",
    },
    "4_channels" : {
        "CHANNELS" : "4",
    },
    "32_channels" : {
        "CHANNELS" : "32",
    },
    "chan_arb_en" : {
        "CHANNEL_ARBITER_EN" : "TRUE",
    },
    "_combinations_" : (
        (), # Works the same as '("default",),' as the "default" is applied in every combination

        (                              "largest_fifo",),
        (               "chan_arb_en", "largest_fifo",),

        (                              "minimal_fifo",),
        (               "chan_arb_en", "minimal_fifo",),

        ("4_channels",                                ),

        ("32_channels",                               ),
        (               "chan_arb_en",                ),
        ("32_channels", "chan_arb_en",                ),
        ("32_channels", "chan_arb_en", "minimal_fifo" ),
    ),
}
