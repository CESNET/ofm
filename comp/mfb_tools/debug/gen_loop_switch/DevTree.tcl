# 1. no   - numero sign of dts_gen_loop_switch (order number of dts_gen_loop_switch in design)
# 2. base - base address of dts_gen_loop_switch for access
proc dts_gen_loop_switch {no base} {
    set   size 0x80
    set    ret ""
    append ret "dbg_gls$no {"
    append ret "compatible = \"netcope,gen_loop_switch\";"
    append ret "reg = <$base $size>;"
    append ret "};"
    return $ret
}
