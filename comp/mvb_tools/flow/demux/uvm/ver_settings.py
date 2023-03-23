# ver_settings.py
# Copyright (C) 2023 CESNET z. s. p. o.
# Author(s): Oliver Gurka <xgurka00@stud.fit.vutbr.cz>

SETTINGS = {
    "default" : { # The default setting of verification
        "ITEMS"             : "4",
        "ITEM_WIDTH"        : "8",
        "RX_MVB_CNT"        : "4",
        "DATA_DEMUX"        : "1",
    },
    "bus_comb_1" : {
        "RX_MVB_CNT"        : "16",
        "ITEM_WIDTH"        : "64",
    },
    "bus_comb_2" : {
        "RX_MVB_CNT"        : "8",
        "ITEM_WIDTH"        : "32",
        "DATA_DEMUX"        : "0"
    },
    "bus_comb_3" : {
        "RX_MVB_CNT"        : "4",
        "ITEM_WIDTH"        : "77"
    },
    "items_comb_1" : {
        "ITEMS"             : "8"
    },
    "items_comb_2" : {
        "ITEMS"             : "16"
    },
    "_combinations_" : (
    (), # Works the same as '("default",),' as the "default" is applied in every combination

    ("bus_comb_1", "items_comb_1",),
    ("bus_comb_1", "items_comb_2"),
    ("bus_comb_2",),
    ("bus_comb_2", "items_comb_1"),
    ("bus_comb_2", "items_comb_2"),

    ),
}
