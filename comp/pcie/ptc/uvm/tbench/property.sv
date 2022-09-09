//-- property.sv: Properties for mfb bus 
//-- Copyright (C) 2022 CESNET z. s. p. o.
//-- Author(s): Daniel Kriz <xkrizd01@vutbr.cz>

//-- SPDX-License-Identifier: BSD-3-Clause 


module ptc_property #(DMA_MFB_UP_REGIONS, MFB_UP_REG_SIZE, MFB_UP_BLOCK_SIZE, MFB_UP_ITEM_WIDTH,
                      DMA_MVB_UP_ITEMS, MFB_UP_REGIONS, PCIE_UPHDR_WIDTH, 
                      MFB_DOWN_REGIONS, MFB_DOWN_REG_SIZE, MFB_DOWN_BLOCK_SIZE, MFB_DOWN_ITEM_WIDTH,
                      PCIE_DOWNHDR_WIDTH, DMA_MFB_DOWN_REGIONS, DMA_MVB_DOWN_ITEMS, META_WIDTH, DMA_PORTS) 
    (
        input RESET,
        input RESET_DMA,
        mfb_if up_mfb_vif [DMA_PORTS],
        mfb_if rq_mfb_vif,
        mfb_if down_mfb_vif [DMA_PORTS],
        mfb_if rc_mfb_vif,
        mvb_if up_mvb_vif [DMA_PORTS],
        mvb_if rq_mvb_vif,
        mvb_if down_mvb_vif [DMA_PORTS],
        mvb_if rc_mvb_vif
    );
    for (genvar dma_port = 0; dma_port < DMA_PORTS; dma_port++) begin
        mfb_property #(
            .REGIONS      (DMA_MFB_UP_REGIONS),
            .REGION_SIZE  (MFB_UP_REG_SIZE),
            .BLOCK_SIZE   (MFB_UP_BLOCK_SIZE),
            .ITEM_WIDTH   (MFB_UP_ITEM_WIDTH),
            .META_WIDTH   (META_WIDTH)
        )
        up_mfb_prop (
            .RESET (RESET_DMA),
            .vif   (up_mfb_vif[dma_port])
        );

        mvb_property #(
            .ITEMS      (DMA_MVB_UP_ITEMS),
            .ITEM_WIDTH (sv_dma_bus_pack::DMA_UPHDR_WIDTH)
        )
        up_mvb_prop (
            .RESET (RESET_DMA),
            .vif   (up_mvb_vif[dma_port])
        );

        mfb_property #(
            .REGIONS      (DMA_MFB_DOWN_REGIONS),
            .REGION_SIZE  (MFB_DOWN_REG_SIZE),
            .BLOCK_SIZE   (MFB_DOWN_BLOCK_SIZE),
            .ITEM_WIDTH   (MFB_DOWN_ITEM_WIDTH),
            .META_WIDTH   (sv_dma_bus_pack::DMA_DOWNHDR_WIDTH)
        )
        down_mfb_prop (
            .RESET (RESET_DMA),
            .vif   (down_mfb_vif[dma_port])
        );

        mvb_property #(
            .ITEMS      (DMA_MVB_DOWN_ITEMS),
            .ITEM_WIDTH (sv_dma_bus_pack::DMA_DOWNHDR_WIDTH)
        )
        down_mvb_prop (
            .RESET (RESET_DMA),
            .vif   (down_mvb_vif[dma_port])
        );
    end

    mfb_property #(
        .REGIONS      (MFB_UP_REGIONS),
        .REGION_SIZE  (MFB_UP_REG_SIZE),
        .BLOCK_SIZE   (MFB_UP_BLOCK_SIZE),
        .ITEM_WIDTH   (MFB_UP_ITEM_WIDTH),
        .META_WIDTH   (META_WIDTH)
    )
    rq_mfb_prop (
        .RESET (RESET),
        .vif   (rq_mfb_vif)
    );

    mvb_property #(
        .ITEMS      (MFB_UP_REGIONS),
        .ITEM_WIDTH (PCIE_UPHDR_WIDTH)
    )
    rq_mvb_prop (
        .RESET (RESET),
        .vif   (rq_mvb_vif)
    );

    mfb_property #(
        .REGIONS      (MFB_DOWN_REGIONS),
        .REGION_SIZE  (MFB_DOWN_REG_SIZE),
        .BLOCK_SIZE   (MFB_DOWN_BLOCK_SIZE),
        .ITEM_WIDTH   (MFB_DOWN_ITEM_WIDTH),
        .META_WIDTH   (META_WIDTH)
    )
    rc_mfb_prop (
        .RESET (RESET),
        .vif   (rc_mfb_vif)
    );

    mvb_property #(
        .ITEMS      (MFB_DOWN_REGIONS),
        .ITEM_WIDTH (PCIE_DOWNHDR_WIDTH)
    )
    rc_mvb_prop (
        .RESET (RESET),
        .vif   (rc_mvb_vif)
    );

endmodule
