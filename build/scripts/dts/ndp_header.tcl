proc dts_ndp_header {dir id items} {
    return "ndp_header_${dir}${id} {
        compatible = \"cesnet,ofm,ndp-header-${dir}\", \"cesnet,ofm,packed-item\";
        header_id = <$id>;
[dts_packed_item $items]
    };"
}
