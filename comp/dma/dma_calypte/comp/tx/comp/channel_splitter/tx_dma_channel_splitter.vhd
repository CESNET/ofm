-- tx_dma_channel_splitter.vhd:
-- Copyright (C) 2022 CESNET z.s.p.o.
-- Author(s): Vladislav Valek  <xvalek14@vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Note:

use work.math_pack.all;
use work.type_pack.all;
use work.pcie_meta_pack.all;

-- This component automatically splits incoming PCIe stream into one of the outputs to channels.
-- The decision of a channel number is made using PCIe header fields like `ADDRESS`, `BAR` and
-- `BAR_APERTURE`. The component also provides and indication on the output interfaces, if a current
-- transaction contains DMA header (this transactions use different address range than ordinary data
-- transactions).
entity TX_DMA_CHANNEL_SPLITTER is
    generic (
        DEVICE : string := "ULTRASCALE";

        -- for generating outputs and calculating the DMA buffers address space
        CHANNELS       : natural := 8;
        DMA_FIFO_DEPTH : natural := 512;

        PCIE_MFB_REGIONS     : natural := 1;
        PCIE_MFB_REGION_SIZE : natural := 1;
        PCIE_MFB_BLOCK_SIZE  : natural := 8;
        PCIE_MFB_ITEM_WIDTH  : natural := 32
        );
    port (
        CLK   : in std_logic;
        RESET : in std_logic;

        -- =========================================================================================
        -- PCIe MFB interface
        -- =========================================================================================
        PCIE_MFB_DATA    : in  std_logic_vector(PCIE_MFB_REGIONS*PCIE_MFB_REGION_SIZE*PCIE_MFB_BLOCK_SIZE*PCIE_MFB_ITEM_WIDTH-1 downto 0);
        PCIE_MFB_META    : in  std_logic_vector(PCIE_CQ_META_WIDTH -1 downto 0);
        PCIE_MFB_SOF     : in  std_logic_vector(PCIE_MFB_REGIONS -1 downto 0);
        PCIE_MFB_EOF     : in  std_logic_vector(PCIE_MFB_REGIONS -1 downto 0);
        PCIE_MFB_SOF_POS : in  std_logic_vector(PCIE_MFB_REGIONS*max(1, log2(PCIE_MFB_REGION_SIZE)) -1 downto 0);
        PCIE_MFB_EOF_POS : in  std_logic_vector(PCIE_MFB_REGIONS*max(1, log2(PCIE_MFB_REGION_SIZE*PCIE_MFB_BLOCK_SIZE)) -1 downto 0);
        PCIE_MFB_SRC_RDY : in  std_logic;
        PCIE_MFB_DST_RDY : out std_logic;

        -- =========================================================================================
        -- User MFB signals
        -- =========================================================================================
        USR_MFB_META_IS_DMA_HDR : out std_logic_vector(CHANNELS -1 downto 0);
        USR_MFB_META_FBE        : out slv_array_t(CHANNELS -1 downto 0)(4 -1 downto 0);
        USR_MFB_META_LBE        : out slv_array_t(CHANNELS -1 downto 0)(4 -1 downto 0);

        USR_MFB_DATA    : out slv_array_t(CHANNELS -1 downto 0)(PCIE_MFB_REGIONS*PCIE_MFB_REGION_SIZE*PCIE_MFB_BLOCK_SIZE*PCIE_MFB_ITEM_WIDTH-1 downto 0) := (others => (others => '0'));
        USR_MFB_SOF     : out slv_array_t(CHANNELS -1 downto 0)(PCIE_MFB_REGIONS -1 downto 0)                                                             := (others => (others => '0'));
        USR_MFB_EOF     : out slv_array_t(CHANNELS -1 downto 0)(PCIE_MFB_REGIONS -1 downto 0)                                                             := (others => (others => '0'));
        USR_MFB_SOF_POS : out slv_array_t(CHANNELS -1 downto 0)(PCIE_MFB_REGIONS*max(1, log2(PCIE_MFB_REGION_SIZE)) -1 downto 0)                          := (others => (others => '0'));
        USR_MFB_EOF_POS : out slv_array_t(CHANNELS -1 downto 0)(PCIE_MFB_REGIONS*max(1, log2(PCIE_MFB_REGION_SIZE*PCIE_MFB_BLOCK_SIZE)) -1 downto 0)      := (others => (others => '0'));
        USR_MFB_SRC_RDY : out std_logic_vector(CHANNELS -1 downto 0)                                                                                      := (others => '0');
        USR_MFB_DST_RDY : in  std_logic_vector(CHANNELS -1 downto 0)
        );
end entity;

architecture FULL of TX_DMA_CHANNEL_SPLITTER is

    constant MFB_LENGTH        : natural := PCIE_MFB_REGIONS*PCIE_MFB_REGION_SIZE*PCIE_MFB_BLOCK_SIZE*PCIE_MFB_ITEM_WIDTH;
    -- the amount of bytes stored in FIFO
    constant FIFO_BYTES_STORED : natural := DMA_FIFO_DEPTH*(MFB_LENGTH/8);

    -- extracted fields from the PCIe header
    signal pcie_hdr_addr         : std_logic_vector(63 downto 0);
    signal pcie_hdr_bar_id       : std_logic_vector(2 downto 0);
    signal pcie_hdr_bar_aperture : std_logic_vector(5 downto 0);
    signal pcie_hdr_fbe          : std_logic_vector(3 downto 0);
    signal pcie_hdr_lbe          : std_logic_vector(3 downto 0);

    signal pcie_addr_mask   : std_logic_vector(63 downto 0);
    signal pcie_addr_masked : std_logic_vector(63 downto 0);

    signal split_sel  : std_logic_vector(PCIE_MFB_REGIONS*max(1, log2(CHANNELS)) -1 downto 0);
    -- Determines if curently contained payload of the incoming PCIe transaction is a DMA header
    signal is_dma_hdr : std_logic;
    -- contains the last byte enable, first byte enable signals from the PCIE META input, the size
    -- of a current PCIE transaction in bytes and one bit indication if DMA header is included in a
    -- current transaction
    signal pcie_mfb_meta_int : std_logic_vector(4+4+1 -1 downto 0);
    signal usr_mfb_meta_int : slv_array_t(CHANNELS -1 downto 0)(4+4+1 -1 downto 0);
begin

    pcie_hdr_deparser_i : entity work.PCIE_CQ_HDR_DEPARSER
        generic map (
            DEVICE       => DEVICE)
        port map (
            OUT_TAG          => open,
            OUT_ADDRESS      => pcie_hdr_addr,
            OUT_REQ_ID       => open,
            OUT_TC           => open,
            OUT_DW_CNT       => open,
            OUT_ATTRIBUTES   => open,
            OUT_FBE          => pcie_hdr_fbe,
            OUT_LBE          => pcie_hdr_lbe,
            OUT_ADDRESS_TYPE => open,
            OUT_TARGET_FUNC  => open,
            OUT_BAR_ID       => pcie_hdr_bar_id,
            OUT_BAR_APERTURE => pcie_hdr_bar_aperture,
            OUT_ADDR_LEN     => open,
            OUT_REQ_TYPE     => open,

            IN_HEADER     => PCIE_MFB_DATA(PCIE_CQ_META_HEADER),
            IN_FBE        => PCIE_MFB_META(PCIE_CQ_META_FBE),
            IN_LBE        => PCIE_MFB_META(PCIE_CQ_META_LBE),
            -- TODO: connect this for Intel FPGA
            IN_INTEL_META => (others => '0'));

    -- =============================================================================================
    -- creates mask for pcie addr based on the BAR APERTURE value in the PCIE header
    -- =============================================================================================
    addr_mask_gen_p : process (all)
        variable mask_var : std_logic_vector(63 downto 0);
    begin
        mask_var := (others => '0');
        for i in 0 to 63 loop
            if (i < unsigned(pcie_hdr_bar_aperture)) then
                mask_var(i) := '1';
            end if;
        end loop;
        pcie_addr_mask <= mask_var;
    end process;

    pcie_addr_masked <= pcie_hdr_addr and pcie_addr_mask;

    -- =============================================================================================
    -- Controling split to different channels according to the current PCIe address
    -- =============================================================================================
    channel_select_p : process (all) is
    begin
        is_dma_hdr <= '0';
        split_sel  <= (others => '0');

        -- NOTE: does not fully work because a different BAR ID has to drop the transaction
        if (PCIE_MFB_SOF = "1" and PCIE_MFB_SRC_RDY = '1') then
            -- Base address of the first DMA header buffer is always larger by one than the last
            -- addres for a data buffer in a last channel
            is_dma_hdr <= pcie_addr_masked(log2(CHANNELS) + log2(FIFO_BYTES_STORED));

            -- select only the part of the address which indexes DMA channels
            split_sel <= pcie_addr_masked(log2(CHANNELS) + log2(FIFO_BYTES_STORED) -1 downto log2(FIFO_BYTES_STORED));
        end if;
    end process;

    pcie_mfb_meta_int <= pcie_hdr_lbe & pcie_hdr_fbe & is_dma_hdr;

    mfb_splitter_simple_gen_i : entity work.MFB_SPLITTER_SIMPLE_GEN
        generic map (
            SPLITTER_OUTPUTS => CHANNELS,

            REGIONS     => PCIE_MFB_REGIONS,
            REGION_SIZE => PCIE_MFB_REGION_SIZE,
            BLOCK_SIZE  => PCIE_MFB_BLOCK_SIZE,
            ITEM_WIDTH  => PCIE_MFB_ITEM_WIDTH,

            META_WIDTH => 4+4+1,
            DEVICE     => DEVICE)
        port map (
            CLK   => CLK,
            RESET => RESET,

            RX_MFB_SEL => split_sel,

            RX_MFB_DATA    => PCIE_MFB_DATA,
            RX_MFB_META    => pcie_mfb_meta_int,
            RX_MFB_SOF     => PCIE_MFB_SOF,
            RX_MFB_EOF     => PCIE_MFB_EOF,
            RX_MFB_SOF_POS => PCIE_MFB_SOF_POS,
            RX_MFB_EOF_POS => PCIE_MFB_EOF_POS,
            RX_MFB_SRC_RDY => PCIE_MFB_SRC_RDY,
            RX_MFB_DST_RDY => PCIE_MFB_DST_RDY,

            TX_MFB_DATA    => USR_MFB_DATA,
            TX_MFB_META    => usr_mfb_meta_int,
            TX_MFB_SOF     => USR_MFB_SOF,
            TX_MFB_EOF     => USR_MFB_EOF,
            TX_MFB_SOF_POS => USR_MFB_SOF_POS,
            TX_MFB_EOF_POS => USR_MFB_EOF_POS,
            TX_MFB_SRC_RDY => USR_MFB_SRC_RDY,
            TX_MFB_DST_RDY => USR_MFB_DST_RDY);

    conn_out_meta_g: for i in 0 to (CHANNELS -1) generate
        USR_MFB_META_IS_DMA_HDR(i) <= usr_mfb_meta_int(i)(0);
        USR_MFB_META_FBE(i)        <= usr_mfb_meta_int(i)(4 downto 1);
        USR_MFB_META_LBE(i)        <= usr_mfb_meta_int(i)(8 downto 5);
    end generate;
end architecture;
