# dts_dma_calypte_ctrl parameters:
# 1. strtype    - name of the DMA (Medusa or Calypte)
# 2. dmatype    - index deciding if current DMA is Medusa or Calypte
# 3. id         - channel ID
# 4. base       - base address of channel
# 5. pcie       - index(es) of PCIe endpoint(s) which DMA controller uses.
proc dts_dma_calypte_ctrl {strtype dmatype dir id base pcie} {
    set    ret ""
    append ret "dma_ctrl_$strtype" "_$dir$id {"
    append ret "compatible = \"netcope,dma_ctrl_" $strtype "_" $dir "\";"
    append ret "reg = <$base 0x80>;"
    if {$dmatype == 2 || $dmatype == 3} {
        append ret "version = <0x00020000>;"
    } else {
        append ret "version = <0x00010002>;"
    }
    append ret "pcie = <$pcie>;"
    append ret "};"
    return $ret
}
