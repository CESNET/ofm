-- superunpacketer.vhd: SuperUnPacketer
-- Copyright (C) 2022 CESNET z. s. p. o.
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

-- This unit accepts and processes SuperPackets.
-- SuperPackets consist of one or more packets.
-- Each ``individual`` packet of the SuperPacket has a special header:
--
-- +--------------+-----------+-----------+--------------+----------------+
-- | Length - 15b | Next - 1b | Mask - 4B | Loop_id - 2B | Timestamp - 8B |
-- +--------------+-----------+-----------+--------------+----------------+
--
-- Fields:
--
-- - Length [B] - the length of the packet (without this header) -> to metadata,
-- - Next - a flag signalling another packet follows after this one,
-- - Mask - for later use (VLAN insertion and so on) -> to metadata,
-- - Loop_id - also for later use -> to metadata,
-- - Timestamp - and also for later use -> to metadata.
--
-- Packets inside a SuperPacket are aligned normally, which can create small
-- gaps between them.
entity SUPERUNPACKETER is
generic(
    -- Number of Regions within a data word, must be power of 2.
    MFB_REGIONS           : natural := 4;
    -- Region size (in Blocks).
    MFB_REGION_SIZE       : natural := 8;
    -- Block size (in Items), must be 8.
    MFB_BLOCK_SIZE        : natural := 8;
    -- Item width (in bits), must be 8.
    MFB_ITEM_WIDTH        : natural := 8;

    -- Output metadata width (in bits), header (16B) - the Next bit.
    OUT_META_WIDTH        : natural := 2*8*8-1;
    -- The extracted Header is output as:
    --   - Insert header to output metadata with SOF (MODE 0),
    --   - Insert header to output metadata with EOF (MODE 1),
    --   - Insert header on MVB (MODE 2)
    OUT_META_MODE         : natural := 0;

    -- Maximum size of a packet (in Items).
    PKT_MTU               : natural := 2**12;

    -- FPGA device name: ULTRASCALE, STRATIX10, AGILEX, ...
    DEVICE                : string := "STRATIX10"
);
port(
    -- =====================================================================
    --  Clock and Reset
    -- =====================================================================

    CLK            : in  std_logic;
    RESET          : in  std_logic;

    -- =====================================================================
    --  RX MFB STREAM (SuperPackets)
    -- =====================================================================

    RX_MFB_DATA    : in  std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
    RX_MFB_SOF_POS : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    RX_MFB_EOF_POS : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    RX_MFB_SOF     : in  std_logic_vector(MFB_REGIONS-1 downto 0);
    RX_MFB_EOF     : in  std_logic_vector(MFB_REGIONS-1 downto 0);
    RX_MFB_SRC_RDY : in  std_logic;
    RX_MFB_DST_RDY : out std_logic;

    -- =====================================================================
    --  TX MFB STREAM (individual packets)
    -- =====================================================================

    TX_MFB_DATA    : out std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
    TX_MFB_META    : out std_logic_vector(MFB_REGIONS*OUT_META_WIDTH-1 downto 0);
    TX_MFB_SOF_POS : out std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    TX_MFB_EOF_POS : out std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    TX_MFB_SOF     : out std_logic_vector(MFB_REGIONS-1 downto 0);
    TX_MFB_EOF     : out std_logic_vector(MFB_REGIONS-1 downto 0);
    TX_MFB_SRC_RDY : out std_logic;
    TX_MFB_DST_RDY : in  std_logic;

    -- =====================================================================
    --  TX MVB Headers
    -- =====================================================================

    TX_MVB_DATA    : out std_logic_vector(MFB_REGIONS*OUT_META_WIDTH-1 downto 0);
    TX_MVB_VLD     : out std_logic_vector(MFB_REGIONS-1 downto 0);
    TX_MVB_SRC_RDY : out std_logic;
    TX_MVB_DST_RDY : in  std_logic := '1'
);
end entity;

architecture FULL of SUPERUNPACKETER is

    -- ========================================================================
    --                                CONSTANTS
    -- ========================================================================

    -- Width of one MFB Region.
    constant MFB_REGION_WIDTH : natural := MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH;
    -- MFB  data word width.
    constant MFB_WORD_WIDTH   : natural := MFB_REGIONS*MFB_REGION_WIDTH;
    -- Length of the Length field.
    constant LENGTH_WIDTH     : natural := 15;
    -- Width of the output metadata per each Region (in bits).
    --                                     Mask + Loop_id + Timestamp
    constant MISC_WIDTH       : natural := 4*8  + 2*8     + 8*8;
    -- Header length (in bits).
    constant HDR_WIDTH        : natural := LENGTH_WIDTH + 1 + MISC_WIDTH;
    -- Header length (in Items).
    constant HDR_ITEMS        : natural := HDR_WIDTH/MFB_ITEM_WIDTH;
    -- Maximum amount of Words a single packet can stretch over.
    constant PKT_MAX_WORDS    : natural := PKT_MTU/(MFB_WORD_WIDTH/MFB_ITEM_WIDTH);
    -- SOF offset width.
    constant SOF_OFFSET_W     : natural := log2(PKT_MAX_WORDS*MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE);

    -- ========================================================================
    --                                 SIGNALS
    -- ========================================================================

    -- Input logic
    signal rx_supkt_data_arr     : slv_array_t     (MFB_REGIONS*MFB_REGION_SIZE-1 downto 0)(MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
    signal rx_supkt_sof_pos_arr  : slv_array_t     (MFB_REGIONS-1 downto 0)(max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    signal rx_supkt_sof_pos_word : u_array_t       (MFB_REGIONS-1 downto 0)(max(1,log2(MFB_REGIONS*MFB_REGION_SIZE))-1 downto 0);
    signal rx_supkt_len_arr      : slv_array_t     (MFB_REGIONS-1 downto 0)(LENGTH_WIDTH-1 downto 0);

    signal regional_offset     : u_array_t(MFB_REGIONS-1 downto 0)(SOF_OFFSET_W-1 downto 0);
    signal sof_pos_offset      : u_array_t(MFB_REGIONS-1 downto 0)(SOF_OFFSET_W-1 downto 0);
    signal hdr_length          : u_array_t(MFB_REGIONS-1 downto 0)(SOF_OFFSET_W-1 downto 0);
    signal pkt_length          : u_array_t(MFB_REGIONS-1 downto 0)(SOF_OFFSET_W-1 downto 0);
    signal rx_supkt_offset_arr : u_array_t(MFB_REGIONS-1 downto 0)(SOF_OFFSET_W-1 downto 0);

    signal eof_propg_reg         : std_logic;
    signal eof_propg             : std_logic_vector(MFB_REGIONS   downto 0);
    signal sphe_tx_sof_mask      : std_logic_vector(MFB_REGIONS-1 downto 0);

    -- Word counter
    signal word_cnt_reg : unsigned                       (log2(PKT_MAX_WORDS)-1 downto 0) := (others => '0');
    signal word_cnt     : u_array_t(MFB_REGIONS downto 0)(log2(PKT_MAX_WORDS)-1 downto 0);

    -- SOF offset
    signal sphe_tx_sof_masked       : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal sof_offset               : u_array_t       (MFB_REGIONS-1 downto 0)(SOF_OFFSET_W-1 downto 0);
    signal sof_offset_prev          : u_array_t       (MFB_REGIONS-1 downto 0)(SOF_OFFSET_W-1 downto 0);
    signal sof_offset_prev_reg      : unsigned                                (SOF_OFFSET_W-1 downto 0);

    -- First stage register
    signal rx_supkt_data_reg0        : std_logic_vector(MFB_WORD_WIDTH-1 downto 0);
    signal rx_supkt_sof_pos_reg0     : std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    signal rx_supkt_eof_pos_reg0     : std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    signal rx_supkt_sof_reg0         : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal rx_supkt_eof_reg0         : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal rx_supkt_src_rdy_reg0     : std_logic;
    signal rx_supkt_dst_rdy_reg0     : std_logic;

    -- Debug cnt
    signal rx_supkt_pkt_cnt_reg0     : u_array_t(MFB_REGIONS downto 0)(16-1 downto 0);
    -- attribute noprune: boolean;
    -- attribute noprune of rx_supkt_pkt_cnt_reg0 : signal is true;
    attribute preserve_for_debug : boolean;
    attribute preserve_for_debug of rx_supkt_pkt_cnt_reg0 : signal is true;

    signal rx_supkt_offset_reg0_arr : u_array_t  (MFB_REGIONS-1 downto 0)(SOF_OFFSET_W-1 downto 0);
    signal sphe_tx_sof_mask_reg0    : std_logic_vector(MFB_REGIONS-1 downto 0);

    signal rx_supkt_data_reg0_arr    : slv_array_t(MFB_REGIONS-1 downto 0)(MFB_REGION_WIDTH-1 downto 0);
    signal rx_supkt_sof_pos_reg0_arr : slv_array_t(MFB_REGIONS-1 downto 0)(max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    signal rx_supkt_eof_pos_reg0_arr : slv_array_t(MFB_REGIONS-1 downto 0)(max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);

    -- SuperPacket Header Extractor (SPHE)
    signal sphe_rx_data        : slv_array_t(MFB_REGIONS-1 downto 0)(MFB_REGION_WIDTH-1 downto 0);
    signal sphe_rx_sof_offset  : slv_array_t(MFB_REGIONS-1 downto 0)(SOF_OFFSET_W-1 downto 0);
    signal sphe_rx_word_cnt    : slv_array_t(MFB_REGIONS-1 downto 0)(log2(PKT_MAX_WORDS)-1 downto 0);

    signal sphe_tx_data       : slv_array_t     (MFB_REGIONS-1 downto 0)(MFB_REGION_WIDTH-1 downto 0);
    signal sphe_tx_sof        : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal sphe_tx_sof_pos    : slv_array_t     (MFB_REGIONS-1 downto 0)(max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    signal sphe_tx_eof        : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal sphe_tx_eof_pos    : slv_array_t     (MFB_REGIONS-1 downto 0)(max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    signal sphe_tx_offset     : slv_array_t     (MFB_REGIONS-1 downto 0)(SOF_OFFSET_W-1 downto 0);
    signal sphe_tx_src_rdy    : std_logic;
    signal sphe_tx_dst_rdy    : std_logic;

    -- Second stage register
    signal rx_supkt_sof_pos_reg1_arr : slv_array_t     (MFB_REGIONS-1 downto 0)(max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    signal rx_supkt_eof_pos_reg1_arr : slv_array_t     (MFB_REGIONS-1 downto 0)(max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    signal rx_supkt_sof_reg1         : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal rx_supkt_eof_reg1         : std_logic_vector(MFB_REGIONS-1 downto 0);

    signal sphe_tx_data_reg1    : slv_array_t     (MFB_REGIONS-1 downto 0)(MFB_REGION_WIDTH-1 downto 0);
    signal sphe_tx_sof_pos_reg1 : slv_array_t     (MFB_REGIONS-1 downto 0)(max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    signal sphe_tx_eof_pos_reg1 : slv_array_t     (MFB_REGIONS-1 downto 0)(max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    signal sphe_tx_sof_reg1     : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal sphe_tx_eof_reg1     : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal sphe_tx_src_rdy_reg1 : std_logic;
    signal sphe_tx_dst_rdy_reg1 : std_logic;

    signal sphe_tx_data_new    : slv_array_t     (MFB_REGIONS-1 downto 0)(MFB_REGION_WIDTH-1 downto 0);
    signal sphe_tx_sof_new     : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal sphe_tx_sof_pos_new : slv_array_t     (MFB_REGIONS-1 downto 0)(max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    signal sphe_tx_eof_new     : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal sphe_tx_eof_pos_new : slv_array_t     (MFB_REGIONS-1 downto 0)(max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    signal sphe_tx_src_rdy_new : std_logic;
    signal sphe_tx_dst_rdy_new : std_logic;

    -- Third stage register
    signal indv_pkt_data    : std_logic_vector(MFB_WORD_WIDTH-1 downto 0);
    signal indv_pkt_sof_pos : std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    signal indv_pkt_eof_pos : std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    signal indv_pkt_sof     : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal indv_pkt_eof     : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal indv_pkt_src_rdy : std_logic;
    signal indv_pkt_dst_rdy : std_logic;

    -- MFB Get Items
    signal getit_indv_pkt_data    : std_logic_vector(MFB_WORD_WIDTH-1 downto 0);
    signal getit_indv_pkt_sof_pos : std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    signal getit_indv_pkt_eof_pos : std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    signal getit_indv_pkt_sof     : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal getit_indv_pkt_eof     : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal getit_indv_pkt_src_rdy : std_logic;
    signal getit_indv_pkt_dst_rdy : std_logic;

    signal getit_indv_hdr_data    : std_logic_vector(MFB_REGIONS*HDR_WIDTH-1 downto 0);
    signal getit_indv_hdr_vld     : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal getit_indv_hdr_src_rdy : std_logic;
    signal getit_indv_hdr_dst_rdy : std_logic;

    signal getit_indv_hdr_data_arr   : slv_array_t(MFB_REGIONS-1 downto 0)(HDR_WIDTH-1 downto 0);
    signal getit_indv_hdr_misc_arr   : slv_array_t(MFB_REGIONS-1 downto 0)(MISC_WIDTH-1 downto 0);
    signal getit_indv_hdr_length_arr : slv_array_t(MFB_REGIONS-1 downto 0)(LENGTH_WIDTH-1 downto 0);

    -- Pipe
    signal pipe_indv_pkt_data    : std_logic_vector(MFB_WORD_WIDTH-1 downto 0);
    signal pipe_indv_pkt_hdr     : std_logic_vector(MFB_REGIONS*OUT_META_WIDTH-1 downto 0);
    signal pipe_indv_pkt_sof_pos : std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    signal pipe_indv_pkt_eof_pos : std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    signal pipe_indv_pkt_sof     : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal pipe_indv_pkt_eof     : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal pipe_indv_pkt_src_rdy : std_logic;
    signal pipe_indv_pkt_dst_rdy : std_logic;

    signal pipe_indv_hdr_data_arr : slv_array_t     (MFB_REGIONS-1 downto 0)(OUT_META_WIDTH-1 downto 0);
    signal pipe_indv_hdr_data     : std_logic_vector(MFB_REGIONS*            OUT_META_WIDTH-1 downto 0);
    signal pipe_indv_hdr_vld      : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal pipe_indv_hdr_src_rdy  : std_logic;
    signal pipe_indv_hdr_dst_rdy  : std_logic;

    -- Metadata Insertor
    signal metains_indv_pkt_data    : std_logic_vector(MFB_WORD_WIDTH-1 downto 0);
    signal metains_indv_pkt_hdr     : std_logic_vector(MFB_REGIONS*OUT_META_WIDTH-1 downto 0);
    signal metains_indv_pkt_sof_pos : std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    signal metains_indv_pkt_eof_pos : std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    signal metains_indv_pkt_sof     : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal metains_indv_pkt_eof     : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal metains_indv_pkt_src_rdy : std_logic;
    signal metains_indv_pkt_dst_rdy : std_logic;
    
    signal metains_indv_hdr_data_arr : slv_array_t     (MFB_REGIONS-1 downto 0)(OUT_META_WIDTH-1 downto 0);
    signal metains_indv_hdr_data     : std_logic_vector(MFB_REGIONS*            OUT_META_WIDTH-1 downto 0);
    signal metains_indv_hdr_vld      : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal metains_indv_hdr_src_rdy  : std_logic;
    signal metains_indv_hdr_dst_rdy  : std_logic;

    -- Output
    signal cut_data    : std_logic_vector(MFB_WORD_WIDTH-1 downto 0);
    signal cut_meta    : std_logic_vector(MFB_REGIONS*OUT_META_WIDTH-1 downto 0);
    signal cut_sof_pos : std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    signal cut_eof_pos : std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    signal cut_sof     : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal cut_eof     : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal cut_src_rdy : std_logic;
    signal cut_dst_rdy : std_logic;

begin

    -- ========================================================================
    -- Input logic
    -- ========================================================================

    -- ----------------------------------------------------
    --  Extraction of the first header of each SuperPacket
    -- ----------------------------------------------------

    rx_supkt_data_arr    <= slv_array_deser(RX_MFB_DATA   , MFB_REGIONS*MFB_REGION_SIZE);
    rx_supkt_sof_pos_arr <= slv_array_deser(RX_MFB_SOF_POS, MFB_REGIONS);
    
    supkt_hdr_extract_g : for r in 0 to MFB_REGIONS-1 generate
        -- Create a global SOF POS (per one word)
        rx_supkt_sof_pos_word(r) <= to_unsigned(r,log2(MFB_REGIONS)) & unsigned(rx_supkt_sof_pos_arr(r));

        rx_supkt_len_arr(r) <= rx_supkt_data_arr(to_integer(rx_supkt_sof_pos_word(r)))(LENGTH_WIDTH-1 downto 0);
    end generate;

    -- -------------------------------
    --  Precalculate SuPkt SOF offset
    -- -------------------------------

    sof_offset_count_g : for r in 0 to MFB_REGIONS-1 generate
        regional_offset(r) <= to_unsigned((r)*MFB_REGION_SIZE*MFB_BLOCK_SIZE                                                   , SOF_OFFSET_W);
        sof_pos_offset (r) <= resize     (resize_right(unsigned(rx_supkt_sof_pos_arr(r)), log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE)), SOF_OFFSET_W);
        hdr_length     (r) <= to_unsigned(HDR_ITEMS                                                                            , SOF_OFFSET_W);
        pkt_length     (r) <= resize     (unsigned(rx_supkt_len_arr(r))                                                        , SOF_OFFSET_W);

        -- SuperPacket SOF offset (calculated from the first packet of a SP)
        rx_supkt_offset_arr(r) <= regional_offset(r) + -- Regional offset
                                  sof_pos_offset (r) + -- SOF POS (conv to Items)
                                  hdr_length     (r) + -- Header length
                                  pkt_length     (r);  -- Length of the packet (w/o the header)
    end generate;

    -- use the Next bit?
    -- -------------------------------------------
    --  Precalculate the mask for the SPHE TX SOF
    -- -------------------------------------------

    process(CLK)
    begin
        if rising_edge(CLK) then
            if (RX_MFB_SRC_RDY = '1') and (RX_MFB_DST_RDY = '1') then
                eof_propg_reg <= eof_propg(MFB_REGIONS);
            end if;
            if (RESET = '1') then
                eof_propg_reg <= '0';
            end if;
        end if;
    end process;

    eof_propg(0) <= '1' when (RX_MFB_EOF(0) = '1') else eof_propg_reg;
    eof_propg_g : for r in 1 to MFB_REGIONS-1 generate
        eof_propg(r) <= '0'            when (RX_MFB_SOF(r-1) = '1') else
                        '1'            when (RX_MFB_EOF(r  ) = '1') else
                        eof_propg(r-1);
    end generate;
    eof_propg(MFB_REGIONS) <= '0' when (RX_MFB_SOF(MFB_REGIONS-1) = '1') else eof_propg(MFB_REGIONS-1);

    sphe_tx_sof_mask <= not eof_propg(MFB_REGIONS-1 downto 0);

    -- ========================================================================
    -- Input (first stage) register
    -- ========================================================================

    RX_MFB_DST_RDY <= sphe_tx_dst_rdy;

    process(CLK)
    begin
        if rising_edge(CLK) then
            if (sphe_tx_dst_rdy = '1') then
                rx_supkt_data_reg0    <= RX_MFB_DATA;
                rx_supkt_sof_pos_reg0 <= RX_MFB_SOF_POS;
                rx_supkt_eof_pos_reg0 <= RX_MFB_EOF_POS;
                rx_supkt_sof_reg0     <= RX_MFB_SOF and RX_MFB_SRC_RDY; -- TODO: RX_MFB_SOF
                rx_supkt_eof_reg0     <= RX_MFB_EOF and RX_MFB_SRC_RDY; -- TODO: RX_MFB_EOF
                
                rx_supkt_offset_reg0_arr <= rx_supkt_offset_arr;

                sphe_tx_sof_mask_reg0 <= sphe_tx_sof_mask;
                
                rx_supkt_src_rdy_reg0 <= RX_MFB_SRC_RDY;
            end if;

            if (RESET = '1') then
                rx_supkt_src_rdy_reg0 <= '0';
            end if;
        end if;
    end process;

    rx_supkt_data_reg0_arr    <= slv_array_deser(rx_supkt_data_reg0   , MFB_REGIONS);
    rx_supkt_sof_pos_reg0_arr <= slv_array_deser(rx_supkt_sof_pos_reg0, MFB_REGIONS);
    rx_supkt_eof_pos_reg0_arr <= slv_array_deser(rx_supkt_eof_pos_reg0, MFB_REGIONS);

    sphe_tx_src_rdy <= rx_supkt_src_rdy_reg0;

    -- ========================================================================
    -- Debug counter
    -- ========================================================================

    process(CLK)
    begin
        if rising_edge(CLK) then
            if (sphe_tx_src_rdy = '1') and (sphe_tx_dst_rdy = '1') then
                rx_supkt_pkt_cnt_reg0(0) <= rx_supkt_pkt_cnt_reg0(MFB_REGIONS);
                -- report "Packet count: " & to_string(to_integer(rx_supkt_pkt_cnt_reg0(0)));
            end if;

            if (RESET = '1') then
                rx_supkt_pkt_cnt_reg0(0) <= (others => '0');
            end if;
        end if;
    end process;

    dbg_cnt_g : for r in 0 to MFB_REGIONS-1 generate
        rx_supkt_pkt_cnt_reg0(r+1) <= rx_supkt_pkt_cnt_reg0(r) when (rx_supkt_eof_reg0(r) = '1') else rx_supkt_pkt_cnt_reg0(r) + 1;
    end generate;

    -- ========================================================================
    -- Control logic for the SuperPacket Header Extractors (SPHEs)
    -- ========================================================================

    -- --------------
    --  Word counter
    -- --------------

    word_cnt_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (sphe_tx_src_rdy = '1') and (sphe_tx_dst_rdy = '1') then
                word_cnt_reg <= word_cnt(MFB_REGIONS) + 1;
            end if;
            if (RESET = '1') then
                word_cnt_reg <= (others => '0');
            end if;
        end if;
    end process;

    word_cnt(0) <= word_cnt_reg when (rx_supkt_sof_reg0(0) = '0') else (others => '0');
    word_cnt_g: for r in 0 to MFB_REGIONS-1 generate
        word_cnt(r+1) <= word_cnt(r) when (rx_supkt_sof_reg0(r) = '0') else (others => '0');
    end generate;

    -- ------------------------
    --  SOF offset calculation
    -- ------------------------

    -- Validate SPHE TX SOF
    sphe_tx_sof_masked <= sphe_tx_sof and sphe_tx_sof_mask_reg0;

    --               SuperPacket SOF offset      if   there was a SuPkt SOF        or   copy the SOF offset from the previous word
    sof_offset(0) <= rx_supkt_offset_reg0_arr(0) when (rx_supkt_sof_reg0(0) = '1') else sof_offset_prev_reg;

    sof_offset_g : for r in 1 to MFB_REGIONS-1 generate
        --               SuperPacket SOF offset      if   there was a SuPkt SOF        or ...
        sof_offset(r) <= rx_supkt_offset_reg0_arr(r) when (rx_supkt_sof_reg0(r) = '1') else sof_offset_prev(r-1);
        --                  ... calculated SOF offset         if   there is a SOF of an indiv pkt  or   propagate the previous SOF offset
        sof_offset_prev(r-1) <= unsigned(sphe_tx_offset(r-1)) when (sphe_tx_sof_masked(r-1) = '1') else sof_offset(r-1);
    end generate;

    sof_offset_prev(MFB_REGIONS-1) <= unsigned(sphe_tx_offset(MFB_REGIONS-1)) when (sphe_tx_sof_masked(MFB_REGIONS-1) = '1') else sof_offset(MFB_REGIONS-1);

    sof_offset_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (sphe_tx_src_rdy = '1') and (sphe_tx_dst_rdy = '1') then
                sof_offset_prev_reg <= sof_offset_prev(MFB_REGIONS-1);
            end if;
        end if;
    end process;

    -- ========================================================================
    -- SuperPacket Header Extractors
    -- ========================================================================

    sphe_tx_dst_rdy <= sphe_tx_dst_rdy_reg1;

    sphe_rx_data <= rx_supkt_data_reg0_arr;
    sphe_rx_g: for r in 0 to MFB_REGIONS-1 generate
        sphe_rx_sof_offset(r) <= std_logic_vector(sof_offset(r));
        sphe_rx_word_cnt  (r) <= std_logic_vector(word_cnt  (r));
    end generate;

    supkt_hdr_extractor_g : for r in 0 to MFB_REGIONS-1 generate
        supkt_hdr_extractor_i : entity work.SUPKT_HDR_EXTRACTOR
        generic map(
            REGIONS     => MFB_REGIONS      ,
            REGION_SIZE => MFB_REGION_SIZE  ,
            BLOCK_SIZE  => MFB_BLOCK_SIZE   ,
            ITEM_WIDTH  => MFB_ITEM_WIDTH   ,

            REGION_NUMBER   => r            ,
            LENGTH_WIDTH    => LENGTH_WIDTH ,
            MAX_WORDS       => PKT_MAX_WORDS
        )
        port map(
            CLK   => CLK,
            RESET => RESET,

            RX_DATA     => sphe_rx_data      (r),
            RX_OFFSET   => sphe_rx_sof_offset(r),
            RX_WORD_CNT => sphe_rx_word_cnt  (r),

            TX_DATA     => sphe_tx_data      (r),
            TX_SOF      => sphe_tx_sof       (r),
            TX_SOF_POS  => sphe_tx_sof_pos   (r),
            TX_EOF      => sphe_tx_eof       (r),
            TX_EOF_POS  => sphe_tx_eof_pos   (r),
            TX_NEW_OFF  => sphe_tx_offset    (r)
        );
    end generate;

    -- ========================================================================
    -- Second stage register
    -- ========================================================================

    sphe_tx_dst_rdy_reg1 <= sphe_tx_dst_rdy_new;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (sphe_tx_dst_rdy_reg1 = '1') then
                rx_supkt_sof_pos_reg1_arr <= rx_supkt_sof_pos_reg0_arr;
                rx_supkt_eof_pos_reg1_arr <= rx_supkt_eof_pos_reg0_arr;
                rx_supkt_sof_reg1         <= rx_supkt_sof_reg0;
                rx_supkt_eof_reg1         <= rx_supkt_eof_reg0;

                sphe_tx_data_reg1    <= sphe_tx_data;
                sphe_tx_sof_pos_reg1 <= sphe_tx_sof_pos;
                sphe_tx_eof_pos_reg1 <= sphe_tx_eof_pos;
                sphe_tx_sof_reg1     <= sphe_tx_sof_masked;
                sphe_tx_eof_reg1     <= sphe_tx_eof;

                sphe_tx_src_rdy_reg1 <= sphe_tx_src_rdy;
            end if;
            if (RESET = '1') then
                sphe_tx_src_rdy_reg1 <= '0';
            end if;
        end if;
    end process;

    -- ========================================================================
    -- SPHE output logic
    -- ========================================================================

    sphe_tx_data_new <= sphe_tx_data_reg1;

    -- MUX which chooses between data either from:
    --     the input or
    --     the SUPKT_HDR_EXTRACTOR
    sphe_output_mux_g : for r in 0 to MFB_REGIONS-1 generate
        sphe_tx_sof_new    (r) <= '1'                          when (rx_supkt_sof_reg1(r) = '1') else sphe_tx_sof_reg1    (r);
        sphe_tx_sof_pos_new(r) <= rx_supkt_sof_pos_reg1_arr(r) when (rx_supkt_sof_reg1(r) = '1') else sphe_tx_sof_pos_reg1(r);

        sphe_tx_eof_new    (r) <= '1'                          when (rx_supkt_eof_reg1(r) = '1') else sphe_tx_eof_reg1    (r);
        sphe_tx_eof_pos_new(r) <= rx_supkt_eof_pos_reg1_arr(r) when (rx_supkt_eof_reg1(r) = '1') else sphe_tx_eof_pos_reg1(r);
    end generate;

    sphe_tx_src_rdy_new <= sphe_tx_src_rdy_reg1;

    -- ========================================================================
    -- Third stage register
    -- ========================================================================

    sphe_tx_dst_rdy_new <= indv_pkt_dst_rdy;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (indv_pkt_dst_rdy = '1') then
                indv_pkt_data    <= slv_array_ser(sphe_tx_data_new);
                indv_pkt_sof_pos <= slv_array_ser(sphe_tx_sof_pos_new);
                indv_pkt_eof_pos <= slv_array_ser(sphe_tx_eof_pos_new);
                indv_pkt_sof     <= sphe_tx_sof_new;
                indv_pkt_eof     <= sphe_tx_eof_new;
                indv_pkt_src_rdy <= sphe_tx_src_rdy_new;
            end if;
            if (RESET = '1') then
                indv_pkt_src_rdy <= '0';
            end if;
        end if;
    end process;

    -- ========================================================================
    -- Extraction of the headers of the individual packets
    -- ========================================================================

    mfb_get_items_i2 : entity work.MFB_GET_ITEMS
    generic map(
        REGIONS          => MFB_REGIONS    ,
        REGION_SIZE      => MFB_REGION_SIZE,
        BLOCK_SIZE       => MFB_BLOCK_SIZE ,
        ITEM_WIDTH       => MFB_ITEM_WIDTH ,
        META_WIDTH       => 0              ,

        MAX_FRAME_LENGHT => PKT_MTU        ,
        EXTRACTED_ITEMS  => HDR_ITEMS      ,
        EXTRACTED_OFFSET => 0
    )
    port map(
        CLK   => CLK,
        RESET => RESET,

        RX_DATA    => indv_pkt_data         ,
        RX_META    => (others => '0')       ,
        RX_SOF_POS => indv_pkt_sof_pos      ,
        RX_EOF_POS => indv_pkt_eof_pos      ,
        RX_SOF     => indv_pkt_sof          ,
        RX_EOF     => indv_pkt_eof          ,
        RX_SRC_RDY => indv_pkt_src_rdy      ,
        RX_DST_RDY => indv_pkt_dst_rdy      ,

        TX_DATA    => getit_indv_pkt_data   ,
        TX_META    => open                  ,
        TX_SOF_POS => getit_indv_pkt_sof_pos,
        TX_EOF_POS => getit_indv_pkt_eof_pos,
        TX_SOF     => getit_indv_pkt_sof    ,
        TX_EOF     => getit_indv_pkt_eof    ,
        TX_SRC_RDY => getit_indv_pkt_src_rdy,
        TX_DST_RDY => getit_indv_pkt_dst_rdy,

        -- Output register inside
        EX_DATA    => getit_indv_hdr_data   ,
        EX_VLD     => getit_indv_hdr_vld    ,
        EX_SRC_RDY => getit_indv_hdr_src_rdy,
        EX_DST_RDY => getit_indv_hdr_dst_rdy
    );

    meta_insert_g : if (OUT_META_MODE = 0) or (OUT_META_MODE = 1) generate

    -- ========================================================================
    -- Insert headers to metadata
    -- ========================================================================

        -- Delay MFB stream
        mfb_pipe_i2 : entity work.MFB_PIPE
        generic map(
            REGIONS     => MFB_REGIONS    ,
            REGION_SIZE => MFB_REGION_SIZE,
            BLOCK_SIZE  => MFB_BLOCK_SIZE ,
            ITEM_WIDTH  => MFB_ITEM_WIDTH ,
            META_WIDTH  => 0              ,

            FAKE_PIPE   => false          ,
            USE_DST_RDY => true           ,
            PIPE_TYPE   => "SHREG"        ,
            DEVICE      => DEVICE
        )
        port map(
            CLK   => CLK,
            RESET => RESET,

            RX_DATA    => getit_indv_pkt_data   ,
            RX_META    => (others => '0')       ,
            RX_SOF_POS => getit_indv_pkt_sof_pos,
            RX_EOF_POS => getit_indv_pkt_eof_pos,
            RX_SOF     => getit_indv_pkt_sof    ,
            RX_EOF     => getit_indv_pkt_eof    ,
            RX_SRC_RDY => getit_indv_pkt_src_rdy,
            RX_DST_RDY => getit_indv_pkt_dst_rdy,

            TX_DATA     => pipe_indv_pkt_data   ,
            TX_META     => open                 ,
            TX_SOF_POS  => pipe_indv_pkt_sof_pos,
            TX_EOF_POS  => pipe_indv_pkt_eof_pos,
            TX_SOF      => pipe_indv_pkt_sof    ,
            TX_EOF      => pipe_indv_pkt_eof    ,
            TX_SRC_RDY  => pipe_indv_pkt_src_rdy,
            TX_DST_RDY  => pipe_indv_pkt_dst_rdy
        );

        getit_indv_hdr_data_arr <= slv_array_deser(getit_indv_hdr_data, MFB_REGIONS);
        out_meta_g : for r in 0 to MFB_REGIONS-1 generate
            getit_indv_hdr_misc_arr  (r) <= getit_indv_hdr_data_arr(r)(HDR_WIDTH-1 downto HDR_WIDTH-MISC_WIDTH);
            getit_indv_hdr_length_arr(r) <= getit_indv_hdr_data_arr(r)(LENGTH_WIDTH-1 downto 0);

            pipe_indv_hdr_data_arr(r) <= getit_indv_hdr_misc_arr(r) & getit_indv_hdr_length_arr(r);
        end generate;

        pipe_indv_hdr_data     <= slv_array_ser(pipe_indv_hdr_data_arr);
        pipe_indv_hdr_vld      <= getit_indv_hdr_vld;
        pipe_indv_hdr_src_rdy  <= getit_indv_hdr_src_rdy;
        getit_indv_hdr_dst_rdy <= pipe_indv_hdr_dst_rdy;

        -- Headers to metadata
        metadata_insertor_i2 : entity work.METADATA_INSERTOR
        generic map(
            MVB_ITEMS            => MFB_REGIONS    ,
            MVB_ITEM_WIDTH       => OUT_META_WIDTH ,

            MFB_REGIONS          => MFB_REGIONS    ,
            MFB_REGION_SIZE      => MFB_REGION_SIZE,
            MFB_BLOCK_SIZE       => MFB_BLOCK_SIZE ,
            MFB_ITEM_WIDTH       => MFB_ITEM_WIDTH ,
            MFB_META_WIDTH       => 0              ,

            INSERT_MODE   => OUT_META_MODE         ,
            MVB_FIFO_SIZE => 4                     ,
            DEVICE        => DEVICE
        )
        port map(
            CLK   => CLK,
            RESET => RESET,

            RX_MVB_DATA    => pipe_indv_hdr_data       ,
            RX_MVB_VLD     => pipe_indv_hdr_vld        ,
            RX_MVB_SRC_RDY => pipe_indv_hdr_src_rdy    ,
            RX_MVB_DST_RDY => pipe_indv_hdr_dst_rdy    ,

            RX_MFB_DATA    => pipe_indv_pkt_data       ,
            RX_MFB_META    => (others => '0')          ,
            RX_MFB_SOF_POS => pipe_indv_pkt_sof_pos    ,
            RX_MFB_EOF_POS => pipe_indv_pkt_eof_pos    ,
            RX_MFB_SOF     => pipe_indv_pkt_sof        ,
            RX_MFB_EOF     => pipe_indv_pkt_eof        ,
            RX_MFB_SRC_RDY => pipe_indv_pkt_src_rdy    ,
            RX_MFB_DST_RDY => pipe_indv_pkt_dst_rdy    ,

            TX_MFB_DATA     => metains_indv_pkt_data   ,
            TX_MFB_META     => open                    ,
            TX_MFB_META_NEW => metains_indv_pkt_hdr    ,
            TX_MFB_SOF_POS  => metains_indv_pkt_sof_pos,
            TX_MFB_EOF_POS  => metains_indv_pkt_eof_pos,
            TX_MFB_SOF      => metains_indv_pkt_sof    ,
            TX_MFB_EOF      => metains_indv_pkt_eof    ,
            TX_MFB_SRC_RDY  => metains_indv_pkt_src_rdy,
            TX_MFB_DST_RDY  => metains_indv_pkt_dst_rdy
        );

        metains_indv_hdr_data    <= (others => '0');
        metains_indv_hdr_vld     <= (others => '0');
        metains_indv_hdr_src_rdy <= '0';

    else generate

        -- ========================================================================
        -- Keep headers on independent MVB stream
        -- ========================================================================

        getit_indv_hdr_data_arr <= slv_array_deser(getit_indv_hdr_data, MFB_REGIONS);
        out_meta_g : for r in 0 to MFB_REGIONS-1 generate
            getit_indv_hdr_misc_arr  (r) <= getit_indv_hdr_data_arr(r)(HDR_WIDTH-1 downto HDR_WIDTH-MISC_WIDTH);
            getit_indv_hdr_length_arr(r) <= getit_indv_hdr_data_arr(r)(LENGTH_WIDTH-1 downto 0);

            metains_indv_hdr_data_arr(r) <= getit_indv_hdr_misc_arr(r) & getit_indv_hdr_length_arr(r);
        end generate;

        metains_indv_hdr_data    <= slv_array_ser(metains_indv_hdr_data_arr);
        metains_indv_hdr_vld     <= getit_indv_hdr_vld;
        metains_indv_hdr_src_rdy <= getit_indv_hdr_src_rdy;
        getit_indv_hdr_dst_rdy <= metains_indv_hdr_dst_rdy;

        metains_indv_pkt_data    <= getit_indv_pkt_data;
        metains_indv_pkt_hdr     <= (others => '0');
        metains_indv_pkt_sof_pos <= getit_indv_pkt_sof_pos;
        metains_indv_pkt_eof_pos <= getit_indv_pkt_eof_pos;
        metains_indv_pkt_sof     <= getit_indv_pkt_sof;
        metains_indv_pkt_eof     <= getit_indv_pkt_eof;
        metains_indv_pkt_src_rdy <= getit_indv_pkt_src_rdy;
        getit_indv_pkt_dst_rdy <= metains_indv_pkt_dst_rdy;

    end generate;

    -- ========================================================================
    -- Get rid of the headers from the individual packets
    -- ========================================================================

    mfb_cutter_i : entity work.MFB_CUTTER_SIMPLE
    generic map(
        REGIONS        => MFB_REGIONS    ,
        REGION_SIZE    => MFB_REGION_SIZE,
        BLOCK_SIZE     => MFB_BLOCK_SIZE ,
        ITEM_WIDTH     => MFB_ITEM_WIDTH ,
        META_WIDTH     => OUT_META_WIDTH ,
        META_ALIGNMENT => OUT_META_MODE  ,
        CUTTED_ITEMS   => HDR_ITEMS
    )
    port map(
        CLK   => CLK,
        RESET => RESET,

        RX_DATA    => metains_indv_pkt_data   ,
        RX_META    => metains_indv_pkt_hdr    ,
        RX_SOF     => metains_indv_pkt_sof    ,
        RX_EOF     => metains_indv_pkt_eof    ,
        RX_SOF_POS => metains_indv_pkt_sof_pos,
        RX_EOF_POS => metains_indv_pkt_eof_pos,
        RX_SRC_RDY => metains_indv_pkt_src_rdy,
        RX_DST_RDY => metains_indv_pkt_dst_rdy,

        RX_CUT     => (others => '1')         ,

        TX_DATA    => cut_data                ,
        TX_META    => cut_meta                ,
        TX_SOF     => cut_sof                 ,
        TX_EOF     => cut_eof                 ,
        TX_SOF_POS => cut_sof_pos             ,
        TX_EOF_POS => cut_eof_pos             ,
        TX_SRC_RDY => cut_src_rdy             ,
        TX_DST_RDY => cut_dst_rdy
    );

    -- ========================================================================
    -- Output assignment
    -- ========================================================================

    TX_MFB_DATA    <= cut_data;
    TX_MFB_META    <= cut_meta;
    TX_MFB_SOF_POS <= cut_sof_pos;
    TX_MFB_EOF_POS <= cut_eof_pos;
    TX_MFB_SOF     <= cut_sof;
    TX_MFB_EOF     <= cut_eof;
    TX_MFB_SRC_RDY <= cut_src_rdy;
    cut_dst_rdy    <= TX_MFB_DST_RDY;

    TX_MVB_DATA    <= metains_indv_hdr_data;
    TX_MVB_VLD     <= metains_indv_hdr_vld;
    TX_MVB_SRC_RDY <= metains_indv_hdr_src_rdy;
    metains_indv_hdr_dst_rdy <= TX_MVB_DST_RDY;

end architecture;
