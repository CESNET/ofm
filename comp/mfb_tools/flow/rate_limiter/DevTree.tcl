proc dts_rate_limiter {base} {
    set ret ""
    append ret "rate_limiter {"
    append ret "compatible = \"cesnet,ofm,rate_limiter\";"
    append ret "version = <0x00000001>;"
    append ret "reg = <$base 0x100>;"
    append ret "};"
    return $ret
}
