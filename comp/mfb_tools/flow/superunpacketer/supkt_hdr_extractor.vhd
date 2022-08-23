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

-- This component extracts the Length and the Next bit from the headers of
-- the individual packets.
entity SUPKT_HDR_EXTRACTOR is
generic(
    -- Number of Regions
    REGIONS           : natural := 4;
    -- Region size (in Blocks).
    REGION_SIZE       : natural := 8;
    -- Block size (in Items), must be 8.
    BLOCK_SIZE        : natural := 8;
    -- Item width (in bits), must be 8.
    ITEM_WIDTH        : natural := 8;

    -- The ID of the analyzer.
    REGION_NUMBER     : natural := 0;

    -- The width of the Length field (in Items).
    LENGTH_WIDTH      : natural := 15;
    -- Maximum amount of words one (individual) packet can strech over.
    MAX_WORDS         : natural
);
port(
    -- =====================================================================
    --  Clock and Reset
    -- =====================================================================

    CLK         : in  std_logic;
    RESET       : in  std_logic;

    -- =====================================================================
    --  INPUT
    -- =====================================================================

    -- A single Region of MFB data.
    RX_DATA     : in  std_logic_vector(REGION_SIZE*BLOCK_SIZE*ITEM_WIDTH-1 downto 0);
    -- On which Item does the packet start? Word      Region  Block       Item
    RX_OFFSET   : in  std_logic_vector(log2(MAX_WORDS*REGIONS*REGION_SIZE*BLOCK_SIZE)-1 downto 0);
    -- How many words does the packet currently sretch over?
    RX_WORD_CNT : in  std_logic_vector(log2(MAX_WORDS)-1 downto 0);

    -- =====================================================================
    --  OUTPUT
    -- =====================================================================

    TX_DATA     : out std_logic_vector(REGION_SIZE*BLOCK_SIZE*ITEM_WIDTH-1 downto 0);
    TX_SOF      : out std_logic;
    TX_SOF_POS  : out std_logic_vector(log2(REGION_SIZE)-1 downto 0);
    TX_EOF      : out std_logic;
    TX_EOF_POS  : out std_logic_vector(log2(REGION_SIZE*BLOCK_SIZE)-1 downto 0);
    TX_LENGTH   : out std_logic_vector(LENGTH_WIDTH-1 downto 0);
    TX_NEXT     : out std_logic
);
end entity;

architecture FULL of SUPKT_HDR_EXTRACTOR is

    -- Extracted header width is:       Length       + Next
    constant EXT_HDR_WIDTH : natural := LENGTH_WIDTH + 1;

    signal eof_offset        : unsigned(log2(MAX_WORDS*REGIONS*REGION_SIZE*BLOCK_SIZE)-1 downto 0);

    signal sof_target_word       : std_logic_vector(log2(MAX_WORDS)-1 downto 0);
    signal sof_target_region     : std_logic_vector(max(1,log2(REGIONS))-1 downto 0);
    signal sof_target_block      : std_logic_vector(log2(REGION_SIZE)-1 downto 0);
    signal sof_target_item       : std_logic_vector(log2(BLOCK_SIZE)-1 downto 0);

    signal sof_target_word_adj   : unsigned(log2(MAX_WORDS)-1 downto 0);
    signal sof_target_region_adj : unsigned(max(1,log2(REGIONS))-1 downto 0);
    signal sof_target_block_adj  : unsigned(log2(REGION_SIZE)-1 downto 0);

    signal eof_target_word   : unsigned(log2(MAX_WORDS)-1 downto 0);
    signal eof_target_region : unsigned(max(1,log2(REGIONS))-1 downto 0);
    signal eof_target_block  : unsigned(log2(REGION_SIZE)-1 downto 0);
    signal eof_target_item   : unsigned(log2(BLOCK_SIZE)-1 downto 0);

    signal sof_hit_word          : std_logic;
    signal sof_hit_region        : std_logic;
    signal sof               : std_logic;

    signal eof_hit_word      : std_logic;
    signal eof_hit_region    : std_logic;
    signal eof               : std_logic;

    signal sof_pos_ptr       : integer range REGION_SIZE*BLOCK_SIZE*ITEM_WIDTH-EXT_HDR_WIDTH downto 0;
    signal ext_hdr           : std_logic_vector(EXT_HDR_WIDTH-1 downto 0);
    signal ext_next          : std_logic;
    signal ext_length        : std_logic_vector(LENGTH_WIDTH-1 downto 0);

begin

    -- EOF is on the previous Item
    eof_offset <= unsigned(RX_OFFSET) - 1;

    one_region_g : if REGIONS > 1 generate

        -- --------------------
        -- Parse the SOF offset
        -- --------------------
        sof_target_word   <= RX_OFFSET(RX_OFFSET'high                                                 downto RX_OFFSET'high-log2(MAX_WORDS)                                +1);
        sof_target_region <= RX_OFFSET(RX_OFFSET'high-log2(MAX_WORDS)                                 downto RX_OFFSET'high-log2(MAX_WORDS)-log2(REGIONS)                  +1);
        sof_target_block  <= RX_OFFSET(RX_OFFSET'high-log2(MAX_WORDS)-log2(REGIONS)                   downto RX_OFFSET'high-log2(MAX_WORDS)-log2(REGIONS)-log2(REGION_SIZE)+1);
        sof_target_item   <= RX_OFFSET(RX_OFFSET'high-log2(MAX_WORDS)-log2(REGIONS)-log2(REGION_SIZE) downto 0                                                               );

        -- Block, Region, and Word corrections (adjustments)
        sof_target_block_adj  <= unsigned(sof_target_block ) when  ((or sof_target_item) = '0'                                                                                              ) else unsigned(sof_target_block ) + 1;
        sof_target_region_adj <= unsigned(sof_target_region) when (((or sof_target_item) = '0') or (unsigned(sof_target_block) < REGION_SIZE-1)                                             ) else unsigned(sof_target_region) + 1;
        sof_target_word_adj   <= unsigned(sof_target_word  ) when (((or sof_target_item) = '0') or (unsigned(sof_target_block) < REGION_SIZE-1) or (unsigned(sof_target_region) < REGIONS-1)) else unsigned(sof_target_word  ) + 1;

        -- --------------------
        -- Parse the EOF offset
        -- --------------------
        eof_target_word   <= eof_offset(eof_offset'high                                                 downto eof_offset'high-log2(MAX_WORDS)                                +1);
        eof_target_region <= eof_offset(eof_offset'high-log2(MAX_WORDS)                                 downto eof_offset'high-log2(MAX_WORDS)-log2(REGIONS)                  +1);
        eof_target_block  <= eof_offset(eof_offset'high-log2(MAX_WORDS)-log2(REGIONS)                   downto eof_offset'high-log2(MAX_WORDS)-log2(REGIONS)-log2(REGION_SIZE)+1);
        eof_target_item   <= eof_offset(eof_offset'high-log2(MAX_WORDS)-log2(REGIONS)-log2(REGION_SIZE) downto 0                                                                );

    else generate

        -- --------------------
        -- Parse the SOF offset
        -- --------------------
        sof_target_region    (0) <= '0';
        sof_target_region_adj(0) <= '0';

        sof_target_word  <= RX_OFFSET(RX_OFFSET'high                                   downto RX_OFFSET'high-log2(MAX_WORDS)                  +1);
        sof_target_block <= RX_OFFSET(RX_OFFSET'high-log2(MAX_WORDS)                   downto RX_OFFSET'high-log2(MAX_WORDS)-log2(REGION_SIZE)+1);
        sof_target_item  <= RX_OFFSET(RX_OFFSET'high-log2(MAX_WORDS)-log2(REGION_SIZE) downto 0                                                 );

        -- Block and Word corrections (adjustments)
        sof_target_block_adj <= unsigned(sof_target_block) when  ((or sof_target_item) = '0'                                                 ) else unsigned(sof_target_block) + 1;
        sof_target_word_adj  <= unsigned(sof_target_word ) when (((or sof_target_item) = '0') or (unsigned(sof_target_block) < REGION_SIZE-1)) else unsigned(sof_target_word ) + 1;

        -- --------------------
        -- Parse the EOF offset
        -- --------------------
        eof_target_region(0) <= '0';

        eof_target_word  <= eof_offset(eof_offset'high                                   downto eof_offset'high-log2(MAX_WORDS)                  +1);
        eof_target_block <= eof_offset(eof_offset'high-log2(MAX_WORDS)                   downto eof_offset'high-log2(MAX_WORDS)-log2(REGION_SIZE)+1);
        eof_target_item  <= eof_offset(eof_offset'high-log2(MAX_WORDS)-log2(REGION_SIZE) downto 0                                                  );

    end generate;

    -- --------------------------------
    -- Word and region evaluation - SOF
    -- --------------------------------
    sof_hit_word   <= '1' when (unsigned(RX_WORD_CNT) = sof_target_word_adj  ) else '0';
    sof_hit_region <= '1' when (REGION_NUMBER         = sof_target_region_adj) else '0';
    sof            <= sof_hit_word and sof_hit_region;

    -- --------------
    -- Header parsing
    -- --------------
    -- NOTE: One header (Length and Next bit) won't ever be in two Regions at once.
    sof_pos_ptr <= to_integer(resize_right(sof_target_block_adj, sof_target_block_adj'length+log2(BLOCK_SIZE*ITEM_WIDTH)));
    ext_hdr     <= RX_DATA(sof_pos_ptr+EXT_HDR_WIDTH-1 downto sof_pos_ptr);
    ext_next    <= ext_hdr(ext_hdr'high);
    ext_length  <= ext_hdr(ext_hdr'high-1 downto 0);

    -- --------------------------------
    -- Word and region evaluation - EOF
    -- --------------------------------
    eof_hit_word   <= '1' when (unsigned(RX_WORD_CNT) = eof_target_word  ) else '0';
    eof_hit_region <= '1' when (REGION_NUMBER         = eof_target_region) else '0';
    eof            <= eof_hit_word and eof_hit_region;

    -- -----------------
    -- Output assignment
    -- -----------------
    TX_DATA    <= RX_DATA;
    TX_SOF     <= sof;
    TX_SOF_POS <= std_logic_vector(sof_target_block_adj);
    TX_EOF     <= eof;
    TX_EOF_POS <= std_logic_vector(eof_target_block) & std_logic_vector(eof_target_item);
    TX_LENGTH  <= ext_length;
    TX_NEXT    <= ext_next;

end architecture;
