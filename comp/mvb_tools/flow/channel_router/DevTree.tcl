# 1. name         - instantion name inside device tree hierarchy
# 2. base         - base address on MI bus
# 3. src_chan     - number of source channels ($reg_size = $src_chan*0x4)
# 4. default_mode - number of default mode (optional)
# 5. opt_mode     - number of opt_mode (optional)
proc dts_mvb_channel_router {name base src_chan {default_mode -1} {opt_mode -1}} {
    set size [expr $src_chan*0x4]
    set    ret ""
    append ret "$name {"
    append ret "compatible = \"cesnet,ofm,mvb_channel_router\";"
    append ret "reg = <$base $size>;"
    if {$default_mode != -1} {append ret "default_mode = <$default_mode>;"}
    if {$opt_mode != -1} {append ret "opt_mode = <$opt_mode>;"}
    append ret "};"
    return $ret
}
