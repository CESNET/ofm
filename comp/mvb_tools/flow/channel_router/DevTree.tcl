# 1. name     - instantion name inside device tree hierarchy
# 2. base     - base address on MI bus
# 3. src_chan - number of source channels ($reg_size = $src_chan*0x4)
proc dts_mvb_channel_router {name base src_chan} {
    set size [expr $src_chan*0x4]
    set    ret ""
    append ret "$name {"
    append ret "compatible = \"cesnet,ofm,mvb_channel_router\";"
    append ret "reg = <$base $size>;"
    append ret "};"
    return $ret
}
