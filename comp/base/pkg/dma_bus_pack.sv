/*
 * dma_bus_pack.sv: Package with DMA bus constatns
 * Copyright (C) 2019 CESNET
 * Author: Martin Spinler <spinler@cesnet.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

// ----------------------------------------------------------------------------
//                        Package declaration
// ----------------------------------------------------------------------------
package sv_dma_bus_pack;

    import math_pkg::*;//log2, max

    /* For item description see dma_bus_pack.vhd */
    /* Synchronize with dma_bus_pack.vhd! */

    parameter DMA_REQUEST_LENGTH_W          = 11;
    parameter DMA_REQUEST_TYPE_W            = 1;
    parameter DMA_REQUEST_FIRSTIB_W         = 2;
    parameter DMA_REQUEST_LASTIB_W          = 2;
    parameter DMA_REQUEST_TAG_W             = 8;
    parameter DMA_REQUEST_UNITID_W          = 8;
    parameter DMA_REQUEST_GLOBAL_W          = 64;
    parameter DMA_REQUEST_VFID_W            = 8;
    parameter DMA_REQUEST_PASID_W           = 0;
    parameter DMA_REQUEST_PASIDVLD_W        = 0;
    parameter DMA_REQUEST_RELAXED_W         = 1;

    parameter DMA_COMPLETION_LENGTH_W       = 11;
    parameter DMA_COMPLETION_COMPLETED_W    = 1;
    parameter DMA_COMPLETION_TAG_W          = 8;
    parameter DMA_COMPLETION_UNITID_W       = 8;

    parameter DMA_REQUEST_LENGTH_O          = 0;
    parameter DMA_REQUEST_TYPE_O            = DMA_REQUEST_LENGTH_O          + DMA_REQUEST_LENGTH_W;
    parameter DMA_REQUEST_FIRSTIB_O         = DMA_REQUEST_TYPE_O            + DMA_REQUEST_TYPE_W;
    parameter DMA_REQUEST_LASTIB_O          = DMA_REQUEST_FIRSTIB_O         + DMA_REQUEST_FIRSTIB_W;
    parameter DMA_REQUEST_TAG_O             = DMA_REQUEST_LASTIB_O          + DMA_REQUEST_LASTIB_W;
    parameter DMA_REQUEST_UNITID_O          = DMA_REQUEST_TAG_O             + DMA_REQUEST_TAG_W;
    parameter DMA_REQUEST_GLOBAL_O          = DMA_REQUEST_UNITID_O          + DMA_REQUEST_UNITID_W;
    parameter DMA_REQUEST_VFID_O            = DMA_REQUEST_GLOBAL_O          + DMA_REQUEST_GLOBAL_W;
    parameter DMA_REQUEST_PASID_O           = DMA_REQUEST_VFID_O            + DMA_REQUEST_VFID_W;
    parameter DMA_REQUEST_PASIDVLD_O        = DMA_REQUEST_PASID_O           + DMA_REQUEST_PASID_W;
    parameter DMA_REQUEST_RELAXED_O         = DMA_REQUEST_PASIDVLD_O        + DMA_REQUEST_PASIDVLD_W;

    parameter DMA_COMPLETION_LENGTH_O       = 0;
    parameter DMA_COMPLETION_COMPLETED_O    = DMA_COMPLETION_LENGTH_O       + DMA_COMPLETION_LENGTH_W;
    parameter DMA_COMPLETION_TAG_O          = DMA_COMPLETION_COMPLETED_O    + DMA_COMPLETION_COMPLETED_W + 4;
    parameter DMA_COMPLETION_UNITID_O       = DMA_COMPLETION_TAG_O          + DMA_COMPLETION_TAG_W;

    parameter DMA_REQUEST_W                 = DMA_REQUEST_RELAXED_O         + DMA_REQUEST_RELAXED_W;
    parameter DMA_COMPLETION_W              = DMA_COMPLETION_UNITID_O       + DMA_COMPLETION_UNITID_W;

    parameter DMA_REQUEST_TYPE_WRITE        = 1;
    parameter DMA_REQUEST_TYPE_READ         = 0;

    /* For compatibility */
    parameter DMA_UPHDR_WIDTH               = DMA_REQUEST_W;
    parameter DMA_DOWNHDR_WIDTH             = DMA_COMPLETION_W;

endpackage
