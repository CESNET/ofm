# 1. base - base address on MI bus
proc dts_tsugen {base} {
	set    ret ""
	append ret "tsu {"
	append ret "compatible = \"netcope,tsu\";"
	append ret "reg = <$base 0x00001000>;"
	# in past type [1,2] (1 was used by ComboV2 - no longer supported)
	# therefore type 1 used now
	append ret "type = <1>;"
	append ret "version = <0x00000001>;"
	append ret "};"
	return $ret
}
