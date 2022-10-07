-- dma_calypte.vhd: encapsulates RX and TX of the Calypte DMA controller
-- Copyright (c) 2022 CESNET z.s.p.o.
-- Author(s): Vladislav Valek  <xvalek14@vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-CLause

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.math_pack.all;
use work.type_pack.all;

entity DMA_CALYPTE is
    generic(

        -- ==========================================================================================
        -- Global settings
        --
        -- Settings affecting both RX and TX or the top level entity itself
        -- ==========================================================================================
        -- Name of target device, the supported are:
        -- "ULTRASCALE"
        DEVICE : string := "ULTRASCALE";

        -- USER MFB data bus configuration
        -- Defines the total width of User data stream.
        USR_MFB_REGIONS     : natural := 1;
        USR_MFB_REGION_SIZE : natural := 8;
        USR_MFB_BLOCK_SIZE  : natural := 8;
        USR_MFB_ITEM_WIDTH  : natural := 8;

        -- Maximum size of a User packet (in bytes)
        -- Defines width of Packet length signals.
        -- the maximum is 2**16 - 1
        PKT_SIZE_MAX : natural := 2**12;

        -- ==========================================================================================
        -- PCIe-side bus settings
        -- ==========================================================================================
        -- Upstream MFB interface configration, allowed configurations are:
        -- (1,1,8,32)
        PCIE_UP_MFB_REGIONS     : natural := 2;
        PCIE_UP_MFB_REGION_SIZE : natural := 1;
        PCIE_UP_MFB_BLOCK_SIZE  : natural := 8;
        PCIE_UP_MFB_ITEM_WIDTH  : natural := 32;

        -- Downstream MFB interface configration, allowed configurations are:
        -- NONE
        PCIE_DOWN_MFB_REGIONS     : natural := 2;
        PCIE_DOWN_MFB_REGION_SIZE : natural := 1;
        PCIE_DOWN_MFB_BLOCK_SIZE  : natural := 8;
        PCIE_DOWN_MFB_ITEM_WIDTH  : natural := 32;

        -- Width of User Header Metadata information
        -- on RX: added to header sent to header Buffer in RAM
        -- on TX: extracted from descriptor and propagated to output
        HDR_META_WIDTH : natural := 24;

        -- ==========================================================================================
        -- RX DMA settings
        --
        -- Settings for RX direction of DMA Module
        -- ==========================================================================================
        -- Total number of RX DMA Channels (multiples of 2 at best)
        -- Minimum: 4
        RX_CHANNELS : natural := 8;
        -- Width of Software and Hardware Descriptor Pointer
        -- Defines width of signals used for these values in DMA Module
        -- Affects logic complexity
        -- Maximum value: 32 (restricted by size of SDP and HDP MI register)
        RX_PTR_WIDTH : natural := 16;

        -- =====================================================================
        -- TX DMA settings
        --
        -- Settings for TX direction of DMA Module
        -- =====================================================================
        -- Total number of TX DMA Channels
        -- Minimum value: TX_SEL_CHANNELS*DMA_ENDPOINTS
        TX_CHANNELS : natural := 8;
        -- Width of Software and Hardware Descriptor Pointer
        -- Defines width of signals used for these values in DMA Module
        -- Affects logic complexity
        -- Maximum value: 32 (restricted by size of SDP and HDP MI register)
        TX_PTR_WIDTH : natural := 16;

        -- =====================================================================
        -- Optional settings
        --
        -- Settings for testing and debugging, settings usually left unchanged
        -- and entity-area constants.
        -- =====================================================================
        -- Width of DSP packet and byte statistics counters
        DSP_CNT_WIDTH : natural := 64;
        -- Enable generation of RX/TX side of DMA Module
        RX_GEN_EN : boolean := TRUE;
        TX_GEN_EN : boolean := FALSE;
        -- Width of MI bus
        MI_WIDTH : natural := 32
        );
    port (
        CLK   : in std_logic;
        RESET : in std_logic;

        -- =====================================================================
        -- RX DMA User-side MFB
        -- =====================================================================
        USR_RX_MFB_META_PKT_SIZE : in  std_logic_vector(log2(PKT_SIZE_MAX + 1) -1 downto 0);
        USR_RX_MFB_META_CHAN     : in  std_logic_vector(log2(RX_CHANNELS) -1 downto 0);
        USR_RX_MFB_META_HDR_META : in  std_logic_vector(HDR_META_WIDTH -1 downto 0);

        USR_RX_MFB_DATA    : in  std_logic_vector(USR_MFB_REGIONS*USR_MFB_REGION_SIZE*USR_MFB_BLOCK_SIZE*USR_MFB_ITEM_WIDTH-1 downto 0);
        USR_RX_MFB_SOF     : in  std_logic_vector(USR_MFB_REGIONS -1 downto 0);
        USR_RX_MFB_EOF     : in  std_logic_vector(USR_MFB_REGIONS -1 downto 0);
        USR_RX_MFB_SOF_POS : in  std_logic_vector(USR_MFB_REGIONS*max(1, log2(USR_MFB_REGION_SIZE)) -1 downto 0);
        USR_RX_MFB_EOF_POS : in  std_logic_vector(USR_MFB_REGIONS*max(1, log2(USR_MFB_REGION_SIZE*USR_MFB_BLOCK_SIZE)) -1 downto 0);
        USR_RX_MFB_SRC_RDY : in  std_logic;
        USR_RX_MFB_DST_RDY : out std_logic := '1';

        -- =====================================================================
        -- TX DMA User-side MFB
        -- =====================================================================
        USR_TX_MFB_META_PKT_SIZE : out  std_logic_vector(log2(PKT_SIZE_MAX + 1) -1 downto 0)    := (others => '0');
        USR_TX_MFB_META_CHAN     : out  std_logic_vector(log2(TX_CHANNELS) -1 downto 0)         := (others => '0');
        USR_TX_MFB_META_HDR_META : out  std_logic_vector(HDR_META_WIDTH -1 downto 0)            := (others => '0');

        USR_TX_MFB_DATA    : out std_logic_vector(USR_MFB_REGIONS*USR_MFB_REGION_SIZE*USR_MFB_BLOCK_SIZE*USR_MFB_ITEM_WIDTH-1 downto 0) := (others => '0');
        USR_TX_MFB_SOF     : out std_logic_vector(USR_MFB_REGIONS -1 downto 0)                                                          := (others => '0');
        USR_TX_MFB_EOF     : out std_logic_vector(USR_MFB_REGIONS -1 downto 0)                                                          := (others => '0');
        USR_TX_MFB_SOF_POS : out std_logic_vector(USR_MFB_REGIONS*max(1, log2(USR_MFB_REGION_SIZE)) -1 downto 0)                        := (others => '0');
        USR_TX_MFB_EOF_POS : out std_logic_vector(USR_MFB_REGIONS*max(1, log2(USR_MFB_REGION_SIZE*USR_MFB_BLOCK_SIZE)) -1 downto 0)     := (others => '0');
        USR_TX_MFB_SRC_RDY : out std_logic                                                                                              := '0';
        USR_TX_MFB_DST_RDY : in  std_logic;

        -- =====================================================================
        -- PCIe-side interfaces (DMA_CLK)
        -- =====================================================================
        -- Upstream MFB interface (for sending data to PCIe Endpoints)
        PCIE_UP_MFB_DATA    : out std_logic_vector (PCIE_UP_MFB_REGIONS*PCIE_UP_MFB_REGION_SIZE*PCIE_UP_MFB_BLOCK_SIZE*PCIE_UP_MFB_ITEM_WIDTH-1 downto 0);
        PCIE_UP_MFB_SOF     : out std_logic_vector (PCIE_UP_MFB_REGIONS -1 downto 0);
        PCIE_UP_MFB_EOF     : out std_logic_vector (PCIE_UP_MFB_REGIONS -1 downto 0);
        PCIE_UP_MFB_SOF_POS : out std_logic_vector (PCIE_UP_MFB_REGIONS*max(1, log2(PCIE_UP_MFB_REGION_SIZE)) -1 downto 0);
        PCIE_UP_MFB_EOF_POS : out std_logic_vector (PCIE_UP_MFB_REGIONS*max(1, log2(PCIE_UP_MFB_REGION_SIZE*PCIE_UP_MFB_BLOCK_SIZE)) -1 downto 0);
        PCIE_UP_MFB_SRC_RDY : out std_logic;
        PCIE_UP_MFB_DST_RDY : in  std_logic;

        -- Downstream MFB interface (for sending data from PCIe Endpoints)
        PCIE_DOWN_MFB_DATA    : in  std_logic_vector (PCIE_DOWN_MFB_REGIONS*PCIE_DOWN_MFB_REGION_SIZE*PCIE_DOWN_MFB_BLOCK_SIZE*PCIE_DOWN_MFB_ITEM_WIDTH-1 downto 0);
        PCIE_DOWN_MFB_SOF     : in  std_logic_vector (PCIE_DOWN_MFB_REGIONS -1 downto 0);
        PCIE_DOWN_MFB_EOF     : in  std_logic_vector (PCIE_DOWN_MFB_REGIONS -1 downto 0);
        PCIE_DOWN_MFB_SOF_POS : in  std_logic_vector (PCIE_DOWN_MFB_REGIONS*max(1, log2(PCIE_DOWN_MFB_REGION_SIZE)) -1 downto 0);
        PCIE_DOWN_MFB_EOF_POS : in  std_logic_vector (PCIE_DOWN_MFB_REGIONS*max(1, log2(PCIE_DOWN_MFB_REGION_SIZE*PCIE_DOWN_MFB_BLOCK_SIZE)) -1 downto 0);
        PCIE_DOWN_MFB_SRC_RDY : in  std_logic;
        PCIE_DOWN_MFB_DST_RDY : out std_logic := '1';

        -- ==========================================================================================
        -- MI interface for SW access
        -- ==========================================================================================
        MI_ADDR : in  std_logic_vector (MI_WIDTH -1 downto 0);
        MI_DWR  : in  std_logic_vector (MI_WIDTH -1 downto 0);
        MI_BE   : in  std_logic_vector (MI_WIDTH/8-1 downto 0);
        MI_RD   : in  std_logic;
        MI_WR   : in  std_logic;
        MI_DRD  : out std_logic_vector (MI_WIDTH -1 downto 0);
        MI_ARDY : out std_logic;
        MI_DRDY : out std_logic
        );
end entity;

architecture FULL of DMA_CALYPTE is

begin

    rx_dma_calypte_g : if (RX_GEN_EN) generate

        rx_dma_calypte_i : entity work.RX_DMA_CALYPTE
            generic map (
                DEVICE   => DEVICE,
                MI_WIDTH => MI_WIDTH,

                USER_RX_MFB_REGIONS     => USR_MFB_REGIONS,
                USER_RX_MFB_REGION_SIZE => USR_MFB_REGION_SIZE,
                USER_RX_MFB_BLOCK_SIZE  => USR_MFB_BLOCK_SIZE,
                USER_RX_MFB_ITEM_WIDTH  => USR_MFB_ITEM_WIDTH,

                PCIE_UP_MFB_REGIONS     => PCIE_UP_MFB_REGIONS,
                PCIE_UP_MFB_REGION_SIZE => PCIE_UP_MFB_REGION_SIZE,
                PCIE_UP_MFB_BLOCK_SIZE  => PCIE_UP_MFB_BLOCK_SIZE,
                PCIE_UP_MFB_ITEM_WIDTH  => PCIE_UP_MFB_ITEM_WIDTH,

                CHANNELS            => RX_CHANNELS,
                POINTER_WIDTH       => RX_PTR_WIDTH,
                SW_ADDR_WIDTH       => 64,
                CNTRS_WIDTH         => DSP_CNT_WIDTH,
                HDR_META_WIDTH      => HDR_META_WIDTH,
                PKT_SIZE_MAX        => PKT_SIZE_MAX,
                TRBUF_FIFO_EN       => FALSE)

            port map (
                CLK   => CLK,
                RESET => RESET,

                MI_ADDR => MI_ADDR,
                MI_DWR  => MI_DWR,
                MI_BE   => MI_BE,
                MI_RD   => MI_RD,
                MI_WR   => MI_WR,
                MI_DRD  => MI_DRD,
                MI_ARDY => MI_ARDY,
                MI_DRDY => MI_DRDY,

                USER_RX_MFB_META_HDR_META => USR_RX_MFB_META_HDR_META,
                USER_RX_MFB_META_CHAN     => USR_RX_MFB_META_CHAN,
                USER_RX_MFB_META_PKT_SIZE => USR_RX_MFB_META_PKT_SIZE,

                USER_RX_MFB_DATA    => USR_RX_MFB_DATA,
                USER_RX_MFB_SOF     => USR_RX_MFB_SOF,
                USER_RX_MFB_EOF     => USR_RX_MFB_EOF,
                USER_RX_MFB_SOF_POS => USR_RX_MFB_SOF_POS,
                USER_RX_MFB_EOF_POS => USR_RX_MFB_EOF_POS,
                USER_RX_MFB_SRC_RDY => USR_RX_MFB_SRC_RDY,
                USER_RX_MFB_DST_RDY => USR_RX_MFB_DST_RDY,

                PCIE_UP_MFB_DATA    => PCIE_UP_MFB_DATA,
                PCIE_UP_MFB_SOF     => PCIE_UP_MFB_SOF,
                PCIE_UP_MFB_EOF     => PCIE_UP_MFB_EOF,
                PCIE_UP_MFB_SOF_POS => PCIE_UP_MFB_SOF_POS,
                PCIE_UP_MFB_EOF_POS => PCIE_UP_MFB_EOF_POS,
                PCIE_UP_MFB_SRC_RDY => PCIE_UP_MFB_SRC_RDY,
                PCIE_UP_MFB_DST_RDY => PCIE_UP_MFB_DST_RDY);

    end generate;

end architecture;
