# dts_dma_calypte_ctrl parameters:
# 1. strtype    - name of the DMA (Medusa or Calypte)
# 2. id         - channel ID
# 3. base       - base address of channel
# 4. pcie       - index(es) of PCIe endpoint(s) which DMA controller uses.
proc dts_dma_calypte_ctrl {strtype dir id base pcie} {
    set    ret ""
    append ret "dma_ctrl_$strtype" "_$dir$id {"
    append ret "compatible = \"netcope,dma_ctrl_" $strtype "_" $dir "\";"
    append ret "reg = <$base 0x80>;"
    append ret "version = <0x00010000>;"
    append ret "pcie = <$pcie>;"
    append ret "};"
    return $ret
}
