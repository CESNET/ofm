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
    TX_NEW_OFF  : out std_logic_vector(log2(MAX_WORDS*REGIONS*REGION_SIZE*BLOCK_SIZE)-1 downto 0)
);
end entity;

architecture FULL of SUPKT_HDR_EXTRACTOR is

    -- Extracted header width is:       Length       + Next
    constant EXT_HDR_WIDTH : natural := LENGTH_WIDTH + 1;
    -- SOF offset width.
    constant SOF_OFFSET_W  : natural := log2(MAX_WORDS*REGIONS*REGION_SIZE*BLOCK_SIZE);

    signal multiple_items        : std_logic;
    signal rx_offset_round_block : unsigned(log2(MAX_WORDS*REGIONS*REGION_SIZE)-1 downto 0);
    signal rx_offset_round_item  : unsigned(SOF_OFFSET_W-1 downto 0);

    signal eof_offset        : unsigned(SOF_OFFSET_W-1 downto 0);

    signal sof_target_word       : unsigned(log2(MAX_WORDS)-1 downto 0);
    signal sof_target_region     : unsigned(max(1,log2(REGIONS))-1 downto 0);
    signal sof_target_block      : unsigned(log2(REGION_SIZE)-1 downto 0);
    signal sof_target_item       : unsigned(log2(BLOCK_SIZE)-1 downto 0);

    signal eof_target_word   : unsigned(log2(MAX_WORDS)-1 downto 0);
    signal eof_target_region : unsigned(max(1,log2(REGIONS))-1 downto 0);
    signal eof_target_block  : unsigned(log2(REGION_SIZE)-1 downto 0);
    signal eof_target_item   : unsigned(log2(BLOCK_SIZE)-1 downto 0);

    signal sof               : std_logic;
    signal eof               : std_logic;

    -- signal sof_pos_ptr       : integer range REGION_SIZE*BLOCK_SIZE*ITEM_WIDTH-EXT_HDR_WIDTH downto 0;
    signal rx_data_arr       : slv_array_t(REGION_SIZE-1 downto 0)(BLOCK_SIZE*ITEM_WIDTH-1 downto 0);
    signal ext_block         : std_logic_vector(BLOCK_SIZE*ITEM_WIDTH-1 downto 0);
    signal ext_hdr           : std_logic_vector(EXT_HDR_WIDTH-1 downto 0);
    signal ext_next          : std_logic;
    signal ext_length        : std_logic_vector(LENGTH_WIDTH-1 downto 0);
    signal ext_length_res    : unsigned(SOF_OFFSET_W-1 downto 0);

begin

    multiple_items <= or (RX_OFFSET(log2(BLOCK_SIZE)-1 downto 0));
    -- Round RX offset to Blocks (increment the number of Blocks if the SOF offest is not aligned to a Block)
    rx_offset_round_block <= (unsigned(RX_OFFSET(log2(MAX_WORDS*REGIONS*REGION_SIZE*BLOCK_SIZE)-1 downto log2(BLOCK_SIZE))) + multiple_items);
    -- Convert to Items
    rx_offset_round_item <= rx_offset_round_block & to_unsigned(0, log2(BLOCK_SIZE));

    -- EOF is on the previous Item
    eof_offset <= unsigned(RX_OFFSET) - 1;

    one_region_g : if REGIONS > 1 generate

        -- --------------------
        -- Parse the SOF offset
        -- --------------------
        sof_target_word   <= rx_offset_round_item(RX_OFFSET'high                                                 downto RX_OFFSET'high-log2(MAX_WORDS)                                +1);
        sof_target_region <= rx_offset_round_item(RX_OFFSET'high-log2(MAX_WORDS)                                 downto RX_OFFSET'high-log2(MAX_WORDS)-log2(REGIONS)                  +1);
        sof_target_block  <= rx_offset_round_item(RX_OFFSET'high-log2(MAX_WORDS)-log2(REGIONS)                   downto RX_OFFSET'high-log2(MAX_WORDS)-log2(REGIONS)-log2(REGION_SIZE)+1);
        sof_target_item   <= rx_offset_round_item(RX_OFFSET'high-log2(MAX_WORDS)-log2(REGIONS)-log2(REGION_SIZE) downto 0                                                               );

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

        sof_target_word  <= rx_offset_round_item(RX_OFFSET'high                                   downto RX_OFFSET'high-log2(MAX_WORDS)                  +1);
        sof_target_block <= rx_offset_round_item(RX_OFFSET'high-log2(MAX_WORDS)                   downto RX_OFFSET'high-log2(MAX_WORDS)-log2(REGION_SIZE)+1);
        sof_target_item  <= rx_offset_round_item(RX_OFFSET'high-log2(MAX_WORDS)-log2(REGION_SIZE) downto 0                                                 );

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
    sof <= '1' when (unsigned(RX_WORD_CNT) = sof_target_word) and (REGION_NUMBER = sof_target_region) else '0';

    -- --------------
    -- Header parsing
    -- --------------
    -- NOTE: One header (Length and Next bit) won't ever be in two Regions at once.
    rx_data_arr    <= slv_array_deser(RX_DATA, REGION_SIZE);
    ext_block      <= rx_data_arr(to_integer(sof_target_block));
    ext_hdr        <= ext_block(EXT_HDR_WIDTH-1 downto 0);
    ext_next       <= ext_hdr(ext_hdr'high);
    ext_length     <= ext_hdr(ext_hdr'high-1 downto 0);
    ext_length_res <= resize(unsigned(ext_length) + EXT_HDR_WIDTH, log2(MAX_WORDS*REGIONS*REGION_SIZE*BLOCK_SIZE));

    -- --------------------------------
    -- Word and region evaluation - EOF
    -- --------------------------------
    eof <= '1' when (unsigned(RX_WORD_CNT) = eof_target_word) and (REGION_NUMBER = eof_target_region) else '0';

    -- -----------------
    -- Output assignment
    -- -----------------
    TX_DATA    <= RX_DATA;
    TX_SOF     <= sof;
    TX_SOF_POS <= std_logic_vector(sof_target_block);
    TX_EOF     <= eof;
    TX_EOF_POS <= std_logic_vector(eof_target_block) & std_logic_vector(eof_target_item);
    TX_NEW_OFF <= std_logic_vector(ext_length_res + rx_offset_round_item);

end architecture;
