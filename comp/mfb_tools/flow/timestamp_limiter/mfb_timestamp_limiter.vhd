-- Copyright (C) 2023 CESNET z. s. p. o.
-- Author(s): Daniel Kondys <kondys@cesnet.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.math_pack.all;
use work.type_pack.all;


-- =========================================================================
--  Description
-- =========================================================================

-- This component limits output speed according to given Timestamps via the :vhdl:portsignal:`RX_MFB_TIMESTAMP <mfb_timestamp_limiter.rx_mfb_timestamp>` port.
-- The incoming packets are split into queues (e.g., per each DMA Channel), where the order of packets is kept the same.
-- Then in each Queue, the MFB Packet Delayer component outputs each packet when the time is right.
-- Finally, the packets from all Queues are merged back into a single stream (no order is kept here).
--
entity MFB_TIMESTAMP_LIMITER is
generic(
    -- Number of Regions within a data word, must be power of 2.
    MFB_REGIONS           : natural := 1;
    -- Region size (in Blocks).
    MFB_REGION_SIZE       : natural := 8;
    -- Block size (in Items), must be 8.
    MFB_BLOCK_SIZE        : natural := 8;
    -- Item width (in bits), must be 8.
    MFB_ITEM_WIDTH        : natural := 8;
    -- Metadata width (in bits).
    MFB_META_WIDTH        : natural := 0;

    -- Freq of the CLK signal (in Hz).
    CLK_FREQUENCY         : natural := 322265625;
    -- Width of Timestamps (in bits).
    TIMESTAMP_WIDTH       : natural := 48;
    -- Format of Timestamps. Options:
    --
    -- - ``0`` number of NS between individual packets,
    -- - ``1`` number of NS from RESET. WIP, not used yet
    TIMESTAMP_FORMAT      : natural := 0;
    -- Number of NS(?) in IDLE state until scheduling an autoreset.
    -- Autoreset (Only for TS_FORMAT=1?) will reset accumulated time from the prev RESET with the next SOF.
    -- WIP, not used yet
    AUTORESET_TIMEOUT     : natural := 1000000;
    -- Number of Items in the Packet Delayer's RX FIFO (the main buffer).
    BUFFER_SIZE           : natural := 2048;
    -- The number of Queues (DMA Channels).
    QUEUES                : natural := 1;

    -- FPGA device name: ULTRASCALE, STRATIX10, AGILEX, ...
    DEVICE                : string := "STRATIX10"
);
port(
    -- =====================================================================
    --  Clock and Reset
    -- =====================================================================

    CLK              : in  std_logic;
    RESET            : in  std_logic;

    -- =====================================================================
    --  RX MFB STREAM
    -- =====================================================================

    RX_MFB_DATA      : in  std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
    -- Valid with SOF.
    RX_MFB_META      : in  std_logic_vector(MFB_REGIONS*MFB_META_WIDTH-1 downto 0) := (others => '0');
    -- ID of the packet's DMA channel or queue.
    RX_MFB_QUEUE     : in  std_logic_vector(MFB_REGIONS*max(1,log2(QUEUES))-1 downto 0) := (others => '0');
    -- Timestamps are valid with each SOF.
    RX_MFB_TIMESTAMP : in  std_logic_vector(MFB_REGIONS*TIMESTAMP_WIDTH-1 downto 0) := (others => '0');
    RX_MFB_SOF_POS   : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    RX_MFB_EOF_POS   : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    RX_MFB_SOF       : in  std_logic_vector(MFB_REGIONS-1 downto 0);
    RX_MFB_EOF       : in  std_logic_vector(MFB_REGIONS-1 downto 0);
    RX_MFB_SRC_RDY   : in  std_logic;
    RX_MFB_DST_RDY   : out std_logic;

    -- =====================================================================
    --  TX MFB STREAM
    -- =====================================================================

    TX_MFB_DATA      : out std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
    -- Valid with SOF.
    TX_MFB_META      : out std_logic_vector(MFB_REGIONS*MFB_META_WIDTH-1 downto 0);
    TX_MFB_SOF_POS   : out std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    TX_MFB_EOF_POS   : out std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    TX_MFB_SOF       : out std_logic_vector(MFB_REGIONS-1 downto 0);
    TX_MFB_EOF       : out std_logic_vector(MFB_REGIONS-1 downto 0);
    TX_MFB_SRC_RDY   : out std_logic;
    TX_MFB_DST_RDY   : in  std_logic
);
end entity;

architecture FULL of MFB_TIMESTAMP_LIMITER is

    -- ========================================================================
    --                                CONSTANTS
    -- ========================================================================

    constant MFB_REGION_WIDTH : natural := MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH;
    constant MFB_WORD_WIDTH   : natural := MFB_REGIONS*MFB_REGION_WIDTH;
    constant MFB_SOFPOS_WIDTH : natural := max(1,log2(MFB_REGION_SIZE));
    constant MFB_EOFPOS_WIDTH : natural := max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE));

    constant MFB_META_COMB_WIDTH : natural := MFB_META_WIDTH + TIMESTAMP_WIDTH;

    -- ========================================================================
    --                                 SIGNALS
    -- ========================================================================

    signal rx_mfb_meta_arr      : slv_array_t     (MFB_REGIONS-1 downto 0)(MFB_META_WIDTH-1 downto 0);
    signal rx_mfb_ts_arr        : slv_array_t     (MFB_REGIONS-1 downto 0)(TIMESTAMP_WIDTH-1 downto 0);
    signal rx_mfb_comb_meta_arr : slv_array_t     (MFB_REGIONS-1 downto 0)(MFB_META_COMB_WIDTH-1 downto 0);
    signal rx_mfb_comb_meta     : std_logic_vector(MFB_REGIONS*            MFB_META_COMB_WIDTH-1 downto 0);

    signal rx_pd_comb_meta      : slv_array_t   (QUEUES-1 downto 0)(MFB_REGIONS*            MFB_META_COMB_WIDTH-1 downto 0);
    signal rx_pd_comb_meta_arr  : slv_array_2d_t(QUEUES-1 downto 0)(MFB_REGIONS-1 downto 0)(MFB_META_COMB_WIDTH-1 downto 0);
    signal rx_pd_meta_arr       : slv_array_2d_t(QUEUES-1 downto 0)(MFB_REGIONS-1 downto 0)(MFB_META_WIDTH-1 downto 0);
    signal rx_pd_ts_arr         : slv_array_2d_t(QUEUES-1 downto 0)(MFB_REGIONS-1 downto 0)(TIMESTAMP_WIDTH-1 downto 0);

    signal rx_pd_data           : slv_array_t     (QUEUES-1 downto 0)(MFB_WORD_WIDTH-1 downto 0);
    signal rx_pd_meta           : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS*MFB_META_WIDTH-1 downto 0);
    signal rx_pd_ts             : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS*TIMESTAMP_WIDTH-1 downto 0);
    signal rx_pd_sof_pos        : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS*MFB_SOFPOS_WIDTH-1 downto 0);
    signal rx_pd_eof_pos        : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS*MFB_EOFPOS_WIDTH-1 downto 0);
    signal rx_pd_sof            : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS-1 downto 0);
    signal rx_pd_eof            : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS-1 downto 0);
    signal rx_pd_src_rdy        : std_logic_vector(QUEUES-1 downto 0);
    signal rx_pd_dst_rdy        : std_logic_vector(QUEUES-1 downto 0);
    
    signal tx_pd_data           : slv_array_t     (QUEUES-1 downto 0)(MFB_WORD_WIDTH-1 downto 0);
    signal tx_pd_meta           : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS*MFB_META_WIDTH-1 downto 0);
    signal tx_pd_sof_pos        : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS*MFB_SOFPOS_WIDTH-1 downto 0);
    signal tx_pd_eof_pos        : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS*MFB_EOFPOS_WIDTH-1 downto 0);
    signal tx_pd_sof            : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS-1 downto 0);
    signal tx_pd_eof            : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS-1 downto 0);
    signal tx_pd_src_rdy        : std_logic_vector(QUEUES-1 downto 0);
    signal tx_pd_dst_rdy        : std_logic_vector(QUEUES-1 downto 0);

begin

    -- ========================================================================
    -- Input MFB Splitter
    -- ========================================================================

    rx_mfb_meta_arr <= slv_array_deser(RX_MFB_META     , MFB_REGIONS);
    rx_mfb_ts_arr   <= slv_array_deser(RX_MFB_TIMESTAMP, MFB_REGIONS);

    rx_splitter_g : for r in 0 to MFB_REGIONS-1 generate
        rx_mfb_comb_meta_arr(r) <= rx_mfb_meta_arr(r) & rx_mfb_ts_arr(r);
    end generate;

    rx_mfb_comb_meta <= slv_array_ser(rx_mfb_comb_meta_arr);

    mfb_splitter_tree_i : entity work.MFB_SPLITTER_SIMPLE_GEN
    generic map(
        SPLITTER_OUTPUTS => QUEUES         ,
        REGIONS          => MFB_REGIONS    ,
        REGION_SIZE      => MFB_REGION_SIZE,
        BLOCK_SIZE       => MFB_BLOCK_SIZE ,
        ITEM_WIDTH       => MFB_ITEM_WIDTH ,
        META_WIDTH       => MFB_META_COMB_WIDTH
    )
    port map(
        CLK             => CLK,
        RESET           => RESET,

        RX_MFB_SEL      => RX_MFB_QUEUE    ,
        RX_MFB_DATA     => RX_MFB_DATA     ,
        RX_MFB_META     => rx_mfb_comb_meta,
        RX_MFB_SOF      => RX_MFB_SOF      ,
        RX_MFB_EOF      => RX_MFB_EOF      ,
        RX_MFB_SOF_POS  => RX_MFB_SOF_POS  ,
        RX_MFB_EOF_POS  => RX_MFB_EOF_POS  ,
        RX_MFB_SRC_RDY  => RX_MFB_SRC_RDY  ,
        RX_MFB_DST_RDY  => RX_MFB_DST_RDY  ,

        TX_MFB_DATA     => rx_pd_data      ,
        TX_MFB_META     => rx_pd_comb_meta ,
        TX_MFB_SOF      => rx_pd_sof       ,
        TX_MFB_EOF      => rx_pd_eof       ,
        TX_MFB_SOF_POS  => rx_pd_sof_pos   ,
        TX_MFB_EOF_POS  => rx_pd_eof_pos   ,
        TX_MFB_SRC_RDY  => rx_pd_src_rdy   ,
        TX_MFB_DST_RDY  => rx_pd_dst_rdy
    );

    -- ========================================================================
    -- Packet Delayers
    -- ========================================================================

    packet_delayers_g : for q in 0 to QUEUES-1 generate

        rx_pd_comb_meta_arr(q) <= slv_array_deser(rx_pd_comb_meta(q), MFB_REGIONS);
        rx_splitter_g : for r in 0 to MFB_REGIONS-1 generate
            rx_pd_meta_arr(q)(r) <= rx_pd_comb_meta_arr(q)(r)(MFB_META_COMB_WIDTH-1 downto TIMESTAMP_WIDTH);
            rx_pd_ts_arr  (q)(r) <= rx_pd_comb_meta_arr(q)(r)(TIMESTAMP_WIDTH-1 downto 0);
        end generate;

        rx_pd_meta(q) <= slv_array_ser(rx_pd_meta_arr(q));
        rx_pd_ts  (q) <= slv_array_ser(rx_pd_ts_arr  (q));

        packet_delayer_i : entity work.MFB_PACKET_DELAYER
        generic map(
            MFB_REGIONS     => MFB_REGIONS        ,
            MFB_REGION_SIZE => MFB_REGION_SIZE    ,
            MFB_BLOCK_SIZE  => MFB_BLOCK_SIZE     ,
            MFB_ITEM_WIDTH  => MFB_ITEM_WIDTH     ,
            MFB_META_WIDTH  => MFB_META_WIDTH     ,

            CLK_FREQUENCY     => CLK_FREQUENCY    ,
            TS_WIDTH          => TIMESTAMP_WIDTH  ,
            TS_FORMAT         => TIMESTAMP_FORMAT ,
            AUTORESET_TIMEOUT => AUTORESET_TIMEOUT,
            FIFO_DEPTH        => BUFFER_SIZE      ,
            DEVICE            => DEVICE
        )
        port map(
            CLK   => CLK,
            RESET => RESET,

            RX_MFB_DATA    => rx_pd_data   (q),
            RX_MFB_META    => rx_pd_meta   (q),
            RX_MFB_TS      => rx_pd_ts     (q),
            RX_MFB_SOF_POS => rx_pd_sof_pos(q),
            RX_MFB_EOF_POS => rx_pd_eof_pos(q),
            RX_MFB_SOF     => rx_pd_sof    (q),
            RX_MFB_EOF     => rx_pd_eof    (q),
            RX_MFB_SRC_RDY => rx_pd_src_rdy(q),
            RX_MFB_DST_RDY => rx_pd_dst_rdy(q),

            TX_MFB_DATA    => tx_pd_data   (q),
            TX_MFB_META    => tx_pd_meta   (q),
            TX_MFB_SOF_POS => tx_pd_sof_pos(q),
            TX_MFB_EOF_POS => tx_pd_eof_pos(q),
            TX_MFB_SOF     => tx_pd_sof    (q),
            TX_MFB_EOF     => tx_pd_eof    (q),
            TX_MFB_SRC_RDY => tx_pd_src_rdy(q),
            TX_MFB_DST_RDY => tx_pd_dst_rdy(q)
        );
            
    end generate;

    -- ========================================================================
    -- Output MFB Merger
    -- ========================================================================

    mfb_merger_tree_i : entity work.MFB_MERGER_SIMPLE_GEN
    generic map(
        MERGER_INPUTS   => QUEUES         ,
        MFB_REGIONS     => MFB_REGIONS    ,
        MFB_REGION_SIZE => MFB_REGION_SIZE,
        MFB_BLOCK_SIZE  => MFB_BLOCK_SIZE ,
        MFB_ITEM_WIDTH  => MFB_ITEM_WIDTH ,
        MFB_META_WIDTH  => MFB_META_WIDTH ,
        MASKING_EN      => True           ,
        CNT_MAX         => 64
    )
    port map(
        CLK             => CLK,
        RST             => RESET,

        RX_MFB_DATA     => tx_pd_data    ,
        RX_MFB_META     => tx_pd_meta    ,
        RX_MFB_SOF      => tx_pd_sof     ,
        RX_MFB_EOF      => tx_pd_eof     ,
        RX_MFB_SOF_POS  => tx_pd_sof_pos ,
        RX_MFB_EOF_POS  => tx_pd_eof_pos ,
        RX_MFB_SRC_RDY  => tx_pd_src_rdy ,
        RX_MFB_DST_RDY  => tx_pd_dst_rdy ,

        TX_MFB_DATA     => TX_MFB_DATA   ,
        TX_MFB_META     => TX_MFB_META   ,
        TX_MFB_SOF      => TX_MFB_SOF    ,
        TX_MFB_EOF      => TX_MFB_EOF    ,
        TX_MFB_SOF_POS  => TX_MFB_SOF_POS,
        TX_MFB_EOF_POS  => TX_MFB_EOF_POS,
        TX_MFB_SRC_RDY  => TX_MFB_SRC_RDY,
        TX_MFB_DST_RDY  => TX_MFB_DST_RDY
    );

end architecture;
