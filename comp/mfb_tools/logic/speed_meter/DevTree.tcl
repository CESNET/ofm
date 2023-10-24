proc dts_speed_meter {base} {
    set ret ""
    append ret "speed_meter {"
    append ret "compatible = \"cesnet,ofm,speed_meter\";"
    append ret "version = <0x00000001>;"
    append ret "reg = <$base 0x18>;"
    append ret "};"
    return $ret
}
