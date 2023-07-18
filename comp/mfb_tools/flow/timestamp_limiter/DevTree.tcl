proc dts_timestamp_limiter {ts_format} {
	set    ret ""
	append ret "timestamp_limiter {"
	append ret "compatible = \"cesnet,ofm,timestamp_limiter\";"
	append ret "version = <0x00000001>;"
	append ret "timestamp_format = <$ts_format>;"
	append ret "};"
	return $ret
}
