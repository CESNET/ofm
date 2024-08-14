# ver_settings.py
# Copyright (C) 2020 CESNET z. s. p. o.
# Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

SETTINGS = {
    "default" : { # The default setting of verification
        "REGIONS"            : "1",
        "REGION_SIZE"        : "8",
        "BLOCK_SIZE"         : "8",
        "ITEM_WIDTH"         : "8",
        "OUTPUT_REG"         : "1",
        "CNT_WIDTH"          : "32",
        "AUTO_RESET"         : "1",
        "IMPLEMENTATION"     : "\\\"serial\\\"",
        "FRAME_SIZE_MAX"     : "512",
        "FRAME_SIZE_MIN"     : "60",
        "TRANSACTION_COUNT"  : "2000",
    },
    "pcie" : {
        "REGIONS"            : "2",
        "REGION_SIZE"        : "1",
        "BLOCK_SIZE"         : "8",
        "ITEM_WIDTH"         : "32",
    },
    "region_comb_1" : {
        "REGIONS"            : "4",
        "REGION_SIZE"        : "8",
        "BLOCK_SIZE"         : "8",
        "ITEM_WIDTH"         : "8",
    },
    "region_comb_2" : {
        "REGIONS"            : "2",
        "REGION_SIZE"        : "8",
        "BLOCK_SIZE"         : "8",
        "ITEM_WIDTH"         : "8",
    },
    "region_comb_3" : {
        "REGIONS"            : "1",
        "REGION_SIZE"        : "1",
        "BLOCK_SIZE"         : "8",
        "ITEM_WIDTH"         : "8",
    },
    "region_comb_4" : {
        "REGIONS"            : "1",
        "REGION_SIZE"        : "2",
        "BLOCK_SIZE"         : "4",
        "ITEM_WIDTH"         : "8",
    },
    "region_comb_5" : {
        "REGIONS"            : "1",
        "REGION_SIZE"        : "2",
        "BLOCK_SIZE"         : "8",
        "ITEM_WIDTH"         : "8",
    },
    "region_comb_6" : {
        "REGIONS"            : "1",
        "REGION_SIZE"        : "4",
        "BLOCK_SIZE"         : "8",
        "ITEM_WIDTH"         : "8",
    },
    "auto_reset_dis" : {
        "AUTO_RESET"         : "0",
    },
    "out_reg_dis" : {
        "OUTPUT_REG"         : "0",
    },
    "implementation_par" : {
        "IMPLEMENTATION"     : "\\\"parallel\\\"",
    },
    "cnt_width_less" : {
        "CNT_WIDTH"          : "3",
    },
    "cnt_width_eq_trans_cnt" : {
        "CNT_WIDTH"          : "8",
        "TRANSACTION_COUNT"  : "255",
    },
    "cnt_width_larger" : {
        "CNT_WIDTH"          : "16",
    },
    "_combinations_" : (
    (), # Works the same as '("default",),' as the "default" is applied in every combination
    ("region_comb_1",),
    ("region_comb_2",),
    ("region_comb_3",),
    ("region_comb_4",),
    ("region_comb_5",),
    ("region_comb_6",),
    ("pcie",),
    ("implementation_par",),
    ("implementation_par", "auto_reset_dis"),
    ("cnt_width_less",),
    ("cnt_width_eq_trans_cnt",),
    ("cnt_width_larger",),
    ("cnt_width_less", "auto_reset_dis"),
    ("cnt_width_eq_trans_cnt", "auto_reset_dis",),
    ("out_reg_dis",),
    ("out_reg_dis", "auto_reset_dis",),
    ("pcie", "auto_reset_dis", "cnt_width_less", "implementation_par",),
    ("pcie", "cnt_width_larger",),
    ("pcie", "auto_reset_dis", "cnt_width_larger", "implementation_par",),
    ("pcie", "cnt_width_larger", "implementation_par",),
    ("pcie", "auto_reset_dis", "cnt_width_larger",),
    ("pcie", "auto_reset_dis", "cnt_width_eq_trans_cnt",),
    ("pcie", "auto_reset_dis", "cnt_width_eq_trans_cnt", "implementation_par"),
    ("pcie", "cnt_width_eq_trans_cnt", "implementation_par"),
    ("pcie", "auto_reset_dis", "cnt_width_eq_trans_cnt",),
    ("pcie", "cnt_width_less", "implementation_par",),
    ("region_comb_1", "auto_reset_dis", "cnt_width_less", "implementation_par",),
    ("region_comb_1", "cnt_width_larger",),
    ("region_comb_1", "auto_reset_dis", "cnt_width_larger", "implementation_par",),
    ("region_comb_1", "cnt_width_larger", "implementation_par",),
    ("region_comb_1", "auto_reset_dis", "cnt_width_larger",),
    ("region_comb_1", "auto_reset_dis", "cnt_width_eq_trans_cnt",),
    ("region_comb_1", "auto_reset_dis", "cnt_width_eq_trans_cnt", "implementation_par"),
    ("region_comb_1", "cnt_width_eq_trans_cnt", "implementation_par"),
    ("region_comb_1", "auto_reset_dis", "cnt_width_eq_trans_cnt",),
    ("region_comb_1", "cnt_width_less", "implementation_par",),
    ("region_comb_2", "auto_reset_dis", "cnt_width_less", "implementation_par",),
    ("region_comb_2", "cnt_width_larger",),
    ("region_comb_2", "auto_reset_dis", "cnt_width_larger", "implementation_par",),
    ("region_comb_2", "cnt_width_larger", "implementation_par",),
    ("region_comb_2", "auto_reset_dis", "cnt_width_larger",),
    ("region_comb_2", "auto_reset_dis", "cnt_width_eq_trans_cnt",),
    ("region_comb_2", "auto_reset_dis", "cnt_width_eq_trans_cnt", "implementation_par"),
    ("region_comb_2", "cnt_width_eq_trans_cnt", "implementation_par"),
    ("region_comb_2", "auto_reset_dis", "cnt_width_eq_trans_cnt",),
    ("region_comb_2", "cnt_width_less", "implementation_par",),
    ("region_comb_3", "auto_reset_dis", "cnt_width_less", "implementation_par",),
    ("region_comb_3", "cnt_width_larger",),
    ("region_comb_3", "auto_reset_dis", "cnt_width_larger", "implementation_par",),
    ("region_comb_3", "cnt_width_larger", "implementation_par",),
    ("region_comb_3", "auto_reset_dis", "cnt_width_larger",),
    ("region_comb_3", "auto_reset_dis", "cnt_width_eq_trans_cnt",),
    ("region_comb_3", "auto_reset_dis", "cnt_width_eq_trans_cnt", "implementation_par"),
    ("region_comb_3", "cnt_width_eq_trans_cnt", "implementation_par"),
    ("region_comb_3", "auto_reset_dis", "cnt_width_eq_trans_cnt",),
    ("region_comb_3", "cnt_width_less", "implementation_par",),
    ("region_comb_4", "auto_reset_dis", "cnt_width_less", "implementation_par",),
    ("region_comb_4", "cnt_width_larger",),
    ("region_comb_4", "auto_reset_dis", "cnt_width_larger", "implementation_par",),
    ("region_comb_4", "cnt_width_larger", "implementation_par",),
    ("region_comb_4", "auto_reset_dis", "cnt_width_larger",),
    ("region_comb_4", "auto_reset_dis", "cnt_width_eq_trans_cnt",),
    ("region_comb_4", "auto_reset_dis", "cnt_width_eq_trans_cnt", "implementation_par"),
    ("region_comb_4", "cnt_width_eq_trans_cnt", "implementation_par"),
    ("region_comb_4", "auto_reset_dis", "cnt_width_eq_trans_cnt",),
    ("region_comb_4", "cnt_width_less", "implementation_par",),
    ("region_comb_5", "auto_reset_dis", "cnt_width_less", "implementation_par",),
    ("region_comb_5", "cnt_width_larger",),
    ("region_comb_5", "auto_reset_dis", "cnt_width_larger", "implementation_par",),
    ("region_comb_5", "cnt_width_larger", "implementation_par",),
    ("region_comb_5", "auto_reset_dis", "cnt_width_larger",),
    ("region_comb_5", "auto_reset_dis", "cnt_width_eq_trans_cnt",),
    ("region_comb_5", "auto_reset_dis", "cnt_width_eq_trans_cnt", "implementation_par"),
    ("region_comb_5", "cnt_width_eq_trans_cnt", "implementation_par"),
    ("region_comb_5", "auto_reset_dis", "cnt_width_eq_trans_cnt",),
    ("region_comb_5", "cnt_width_less", "implementation_par",),
    ("region_comb_6", "auto_reset_dis", "cnt_width_less", "implementation_par",),
    ("region_comb_6", "cnt_width_larger",),
    ("region_comb_6", "auto_reset_dis", "cnt_width_larger", "implementation_par",),
    ("region_comb_6", "cnt_width_larger", "implementation_par",),
    ("region_comb_6", "auto_reset_dis", "cnt_width_larger",),
    ("region_comb_6", "auto_reset_dis", "cnt_width_eq_trans_cnt",),
    ("region_comb_6", "auto_reset_dis", "cnt_width_eq_trans_cnt", "implementation_par"),
    ("region_comb_6", "cnt_width_eq_trans_cnt", "implementation_par"),
    ("region_comb_6", "auto_reset_dis", "cnt_width_eq_trans_cnt",),
    ("region_comb_6", "cnt_width_less", "implementation_par",),
    ),
}