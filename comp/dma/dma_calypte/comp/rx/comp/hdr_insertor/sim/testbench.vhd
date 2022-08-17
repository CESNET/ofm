-- testbench.vhd:
-- Copyright (c) 2022 CESNET z.s.p.o.
-- Author(s): Vladislav Valek  <xvalek14@vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-CLause

library ieee;
use ieee.std_logic_1164.all;

use work.math_pack.all;
use work.type_pack.all;

--=================================================================================================================

entity TESTBENCH is

end entity;

--=================================================================================================================

architecture BEHAVIORAL of TESTBENCH is

    -- component generics
    constant RX_REGIONS     : natural := 1;
    constant RX_REGION_SIZE : natural := 1;
    constant RX_BLOCK_SIZE  : natural := 128;
    constant RX_ITEM_WIDTH  : natural := 8;

    constant TX_REGIONS     : natural := 1;
    constant TX_REGION_SIZE : natural := 1;
    constant TX_BLOCK_SIZE  : natural := 8;
    constant TX_ITEM_WIDTH  : natural := 32;

    constant PKT_SIZE_MAX : natural := 2**16;

    -- component ports
    signal clk : std_logic;
    signal rst : std_logic;

    signal rx_mfb_data    : std_logic_vector(RX_REGIONS*RX_REGION_SIZE*RX_BLOCK_SIZE*RX_ITEM_WIDTH-1 downto 0);
    signal rx_mfb_sof     : std_logic_vector(RX_REGIONS-1 downto 0);
    signal rx_mfb_eof     : std_logic_vector(RX_REGIONS-1 downto 0);
    signal rx_mfb_sof_pos : std_logic_vector(RX_REGIONS*max(1, log2(RX_REGION_SIZE))-1 downto 0);
    signal rx_mfb_eof_pos : std_logic_vector(RX_REGIONS*max(1, log2(RX_REGION_SIZE*RX_BLOCK_SIZE))-1 downto 0);
    signal rx_mfb_src_rdy : std_logic;
    signal rx_mfb_dst_rdy : std_logic;

    signal tx_mfb_data    : std_logic_vector(TX_REGIONS*TX_REGION_SIZE*TX_BLOCK_SIZE*TX_ITEM_WIDTH-1 downto 0);
    signal tx_mfb_sof     : std_logic_vector(TX_REGIONS-1 downto 0);
    signal tx_mfb_eof     : std_logic_vector(TX_REGIONS-1 downto 0);
    signal tx_mfb_sof_pos : std_logic_vector(TX_REGIONS*max(1, log2(TX_REGION_SIZE))-1 downto 0);
    signal tx_mfb_eof_pos : std_logic_vector(TX_REGIONS*max(1, log2(TX_REGION_SIZE*TX_BLOCK_SIZE))-1 downto 0);
    signal tx_mfb_src_rdy : std_logic;
    signal tx_mfb_dst_rdy : std_logic;

    signal hdrm_pcie_hdr_data    : std_logic_vector(127 downto 0);
    signal hdrm_pcie_hdr_type    : std_logic;
    signal hdrm_pcie_hdr_src_rdy : std_logic;
    signal hdrm_pcie_hdr_dst_rdy : std_logic;

    signal hdrm_dma_hdr_data    : std_logic_vector(63 downto 0);
    signal hdrm_pkt_drop        : std_logic;
    signal hdrm_dma_hdr_src_rdy : std_logic;
    signal hdrm_dma_hdr_dst_rdy : std_logic;
    signal hdrm_pkt_sent_inc    : std_logic;
    signal hdrm_pkt_disc_inc    : std_logic;
    signal hdrm_pkt_size        : std_logic_vector((log2(PKT_SIZE_MAX) - 1) downto 0);

    constant CLK_PERIOD : time := 2560 PS;
begin

    -- component instantiation
    uut_i : entity work.RX_DMA_HDR_INSERTOR
        generic map (
            RX_REGIONS     => RX_REGIONS,
            RX_REGION_SIZE => RX_REGION_SIZE,
            RX_BLOCK_SIZE  => RX_BLOCK_SIZE,
            RX_ITEM_WIDTH  => RX_ITEM_WIDTH,

            TX_REGIONS     => TX_REGIONS,
            TX_REGION_SIZE => TX_REGION_SIZE,
            TX_BLOCK_SIZE  => TX_BLOCK_SIZE,
            TX_ITEM_WIDTH  => TX_ITEM_WIDTH)
        port map (
            CLK => clk,
            RST => rst,

            RX_MFB_DATA    => rx_mfb_data,
            RX_MFB_SOF     => rx_mfb_sof,
            RX_MFB_EOF     => rx_mfb_eof,
            RX_MFB_SOF_POS => rx_mfb_sof_pos,
            RX_MFB_EOF_POS => rx_mfb_eof_pos,
            RX_MFB_SRC_RDY => rx_mfb_src_rdy,
            RX_MFB_DST_RDY => rx_mfb_dst_rdy,

            TX_MFB_DATA    => tx_mfb_data,
            TX_MFB_SOF     => tx_mfb_sof,
            TX_MFB_EOF     => tx_mfb_eof,
            TX_MFB_SOF_POS => tx_mfb_sof_pos,
            TX_MFB_EOF_POS => tx_mfb_eof_pos,
            TX_MFB_SRC_RDY => tx_mfb_src_rdy,
            TX_MFB_DST_RDY => tx_mfb_dst_rdy,

            HDRM_PCIE_HDR_DATA    => hdrm_pcie_hdr_data,
            HDRM_PCIE_HDR_TYPE    => hdrm_pcie_hdr_type,
            HDRM_PCIE_HDR_SRC_RDY => hdrm_pcie_hdr_src_rdy,
            HDRM_PCIE_HDR_DST_RDY => hdrm_pcie_hdr_dst_rdy,

            HDRM_DMA_HDR_DATA    => hdrm_dma_hdr_data,
            HDRM_PKT_DROP        => hdrm_pkt_drop,
            HDRM_DMA_HDR_SRC_RDY => hdrm_dma_hdr_src_rdy,
            HDRM_DMA_HDR_DST_RDY => hdrm_dma_hdr_dst_rdy,

            HDRM_PKT_SENT_INC => hdrm_pkt_sent_inc,
            HDRM_PKT_DISC_INC => hdrm_pkt_disc_inc,
            HDRM_PKT_SIZE     => hdrm_pkt_size);

-- clock generation
    clk_p : process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- waveform generation
    stim_p : process
    begin
        -- insert signal assignments here

        rx_mfb_data    <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB88888888888888888888888888888888888888888888888888888888888888881111111111111111111111111111111111111111111111111111111111111111";
        rx_mfb_sof     <= "1";
        rx_mfb_sof_pos <= "0";
        rx_mfb_eof     <= "1";
        rx_mfb_eof_pos <= "1111111";
        rx_mfb_src_rdy <= '1';

        tx_mfb_dst_rdy        <= '0';
        hdrm_pcie_hdr_src_rdy <= '0';
        hdrm_dma_hdr_src_rdy  <= '0';

        rst <= '1';
        wait for clk_period*100;
        rst <= '0';

        wait for clk_period*10;

        hdrm_pcie_hdr_data    <= x"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
        hdrm_pcie_hdr_type    <= '0';
        hdrm_pcie_hdr_src_rdy <= '1';

        wait for clk_period*10;

        hdrm_dma_hdr_data    <= x"CCCCCCCCCCCCCCCC";
        hdrm_pkt_drop        <= '0';
        hdrm_dma_hdr_src_rdy <= '1';

        wait for clk_period*50;
        tx_mfb_dst_rdy <= '1';

        wait;
        wait;
    end process;

end architecture;

--=================================================================================================================
