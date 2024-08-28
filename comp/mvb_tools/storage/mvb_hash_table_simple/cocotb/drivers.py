from cocotbext.ofm.mvb.drivers import MVBDriver


class MVB_HASH_TABLE_SIMPLE_Driver(MVBDriver):
    _signals = {"data": "key", "vld": "vld", "src_rdy": "src_rdy", "dst_rdy": "dst_rdy"}
