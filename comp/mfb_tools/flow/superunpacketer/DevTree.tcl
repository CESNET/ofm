proc dts_frameunpacker {} {
	set    ret ""
	append ret "frameunpacker {"
	append ret "compatible = \"cesnet,ofm,frameunpacker\";"
	append ret "version = <0x00000001>;"
	append ret "hdr_size = <16>;"
	append ret "};"
	return $ret
}
