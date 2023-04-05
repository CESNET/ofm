-- validation_prepare.vhd: A component that processes Offsets and Lengths in order to select those for the actual validation process.
-- Copyright (C) 2023 CESNET z.s.p.o.
-- Author(s): Daniel Kondys <kondys@cesnet.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.type_pack.all;
use work.math_pack.all;


-- ============================================================================
-- Description
-- ============================================================================

-- This component prepares the Offsets and Lengths for the next stage, where the validation is actually performed.
-- The preparation is about converting the Offsets that are from SOF POS to be from the beginning of the current word.
-- When the Offset is reached (Word and Region), the Offset gets rounded up to the following Region.
-- And also, the Length is decremented by the number of Items that are from the Offset to the end of the Region.
entity VALIDATION_PREPARE is
generic(
    -- Number of Regions within a data word, must be power of 2.
    MFB_REGIONS     : natural := 4;
    -- Region size (in Blocks).
    MFB_REGION_SIZE : natural := 8;
    -- Block size (in Items).
    MFB_BLOCK_SIZE  : natural := 8;

    -- Maximum amount of Words a single packet can stretch over.
    MAX_WORDS            : natural := 10;
    -- Width of the Offset signals.
    OFFSET_WIDTH         : integer := log2(MAX_WORDS*MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE)+1;
    -- Width of the Length signals.
    LENGTH_WIDTH    : integer := log2(MAX_WORDS*MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE)
);
port(
    -- ========================================================================
    -- Clock and Reset
    -- ========================================================================

    CLK        : in  std_logic;
    RESET      : in  std_logic;

    -- ========================================================================
    -- RX inf
    -- ========================================================================

    -- Number of the current word (counted from each SOF).
    RX_WORD    : in  u_array_t       (MFB_REGIONS-1 downto 0)(log2(MAX_WORDS)-1 downto 0);
    -- Offset of the Section-to-be-validated from the beginning of the word (in Items).
    RX_OFFSET  : in  u_array_t       (MFB_REGIONS-1 downto 0)(OFFSET_WIDTH-1 downto 0);
    -- Length of the Section-to-be-validated (in Items).
    RX_LENGTH  : in  u_array_t       (MFB_REGIONS-1 downto 0)(LENGTH_WIDTH-1 downto 0);
    RX_VALID   : in  std_logic_vector(MFB_REGIONS-1 downto 0);
    RX_SRC_RDY : in  std_logic;
    RX_DST_RDY : out std_logic;

    -- ========================================================================
    -- TX inf
    -- ========================================================================

    TX_OFFSET  : out u_array_t       (MFB_REGIONS-1 downto 0)(OFFSET_WIDTH-1 downto 0);
    TX_LENGTH  : out u_array_t       (MFB_REGIONS-1 downto 0)(LENGTH_WIDTH-1 downto 0);
    TX_VALID   : out std_logic_vector(MFB_REGIONS-1 downto 0);
    TX_SRC_RDY : out std_logic;
    TX_DST_RDY : in  std_logic
);
end entity;

architecture FULL of VALIDATION_PREPARE is

    -- ========================================================================
    --                                 SIGNALS
    -- ========================================================================

    signal vp_rx_word       : u_array_t       (MFB_REGIONS-1 downto 0)(log2(MAX_WORDS)-1 downto 0);
    signal vp_rx_new_offset : u_array_t       (MFB_REGIONS-1 downto 0)(OFFSET_WIDTH-1 downto 0);
    signal vp_rx_new_length : u_array_t       (MFB_REGIONS-1 downto 0)(LENGTH_WIDTH-1 downto 0);
    signal vp_rx_new_valid  : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal vp_rx_old_offset : u_array_t       (MFB_REGIONS-1 downto 0)(OFFSET_WIDTH-1 downto 0);
    signal vp_rx_old_length : u_array_t       (MFB_REGIONS-1 downto 0)(LENGTH_WIDTH-1 downto 0);
    signal vp_rx_old_valid  : std_logic_vector(MFB_REGIONS-1 downto 0);

    signal vp_tx_offset     : u_array_t       (MFB_REGIONS-1 downto 0)(OFFSET_WIDTH-1 downto 0);
    signal vp_tx_length     : u_array_t       (MFB_REGIONS-1 downto 0)(LENGTH_WIDTH-1 downto 0);
    signal vp_tx_valid      : std_logic_vector(MFB_REGIONS-1 downto 0);

begin

    RX_DST_RDY <= TX_DST_RDY;

    -- ------------------------
    --  Prepare for validation
    -- ------------------------
    vp_rx_word       <= RX_WORD;
    vp_rx_new_offset <= RX_OFFSET;
    vp_rx_new_length <= RX_LENGTH;
    vp_rx_new_valid  <= RX_VALID;

    validation_prepare_r_g : for r in 0 to MFB_REGIONS-1 generate
        validation_prepare_r_i : entity work.VALIDATION_PREPARE_R
        generic map(
            MFB_REGIONS     => MFB_REGIONS    ,
            MFB_REGION_SIZE => MFB_REGION_SIZE,
            MFB_BLOCK_SIZE  => MFB_BLOCK_SIZE ,
            REGION_NUMBER   => r              ,
            MAX_WORDS       => MAX_WORDS      ,
            OFFSET_WIDTH    => OFFSET_WIDTH   ,
            LENGTH_WIDTH    => LENGTH_WIDTH
        )
        port map(
            RX_WORD       => vp_rx_word      (r),
            RX_NEW_OFFSET => vp_rx_new_offset(r),
            RX_NEW_LENGTH => vp_rx_new_length(r),
            RX_NEW_VALID  => vp_rx_new_valid (r),
            RX_OLD_OFFSET => vp_rx_old_offset(r),
            RX_OLD_LENGTH => vp_rx_old_length(r),
            RX_OLD_VALID  => vp_rx_old_valid (r),

            TX_OFFSET     => vp_tx_offset    (r),
            TX_LENGTH     => vp_tx_length    (r),
            TX_VALID      => vp_tx_valid     (r)
        );
    end generate;

    -- -------------------------
    --  Propagate vp_tx signals
    -- -------------------------
    propagate_signals_g : for r in 0 to MFB_REGIONS-2 generate
        vp_rx_old_offset(r+1) <= vp_tx_offset(r);
        vp_rx_old_length(r+1) <= vp_tx_length(r);
        vp_rx_old_valid (r+1) <= vp_tx_valid (r);
    end generate;

    process(CLK)
    begin
        if rising_edge(CLK) then
            if (RX_SRC_RDY = '1') and (TX_DST_RDY = '1') then
                vp_rx_old_offset(0) <= vp_tx_offset(MFB_REGIONS-1);
                vp_rx_old_length(0) <= vp_tx_length(MFB_REGIONS-1);
                vp_rx_old_valid (0) <= vp_tx_valid (MFB_REGIONS-1);
            end if;
            if (RESET = '1') then
                vp_rx_old_valid(0) <= '0';
            end if;
        end if;
    end process;

    -- -------------------
    --  Output assignment
    -- -------------------
    TX_OFFSET  <= vp_tx_offset;
    TX_LENGTH  <= vp_tx_length;
    TX_VALID   <= vp_tx_valid;
    TX_SRC_RDY <= RX_SRC_RDY;

end architecture;
