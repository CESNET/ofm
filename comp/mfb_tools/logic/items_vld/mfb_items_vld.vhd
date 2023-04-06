-- mfb_items_vld.vhd: A component that validates Items from the given Offset for the given Length.
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
--  Description
-- ============================================================================

-- This component validates Items from the received offset until the Length is reached.
entity MFB_ITEMS_VLD is
generic(
    -- Number of Regions within a data word, must be power of 2.
    MFB_REGIONS          : natural := 4;
    -- Region size (in Blocks).
    MFB_REGION_SIZE      : natural := 8;
    -- Block size (in Items).
    MFB_BLOCK_SIZE       : natural := 8;
    -- Item width (in bits).
    MFB_ITEM_WIDTH       : natural := 8;
    -- Metadata width (in bits).
    MFB_META_WIDTH       : natural := 0;

    -- Maximum size of a packet (in Items).
    PKT_MTU              : natural := 2**14;

    -- Width of each Offset signal in the in the RX_OFFSET vector.
    OFFSET_WIDTH         : integer := log2(PKT_MTU);
    -- Width of each Length signal in the in the RX_LENGTH vector.
    LENGTH_WIDTH         : integer := log2(PKT_MTU)
);
port(
    -- ========================================================================
    -- Clock and Reset
    -- ========================================================================

    CLK              : in  std_logic;
    RESET            : in  std_logic;

    -- ========================================================================
    -- RX STREAM
    --
    -- #. Input packets (MFB),
    -- #. Meta information.
    -- ========================================================================

    RX_MFB_DATA      : in  std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
    RX_MFB_META      : in  std_logic_vector(MFB_REGIONS*MFB_META_WIDTH-1 downto 0) := (others => '0');
    RX_MFB_SOF_POS   : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    RX_MFB_EOF_POS   : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    RX_MFB_SOF       : in  std_logic_vector(MFB_REGIONS-1 downto 0);
    RX_MFB_EOF       : in  std_logic_vector(MFB_REGIONS-1 downto 0);
    RX_MFB_SRC_RDY   : in  std_logic;
    RX_MFB_DST_RDY   : out std_logic;

    -- A vector of Offsets (each in Items), valid with SOF.
    RX_OFFSET        : in  std_logic_vector(MFB_REGIONS*OFFSET_WIDTH-1 downto 0);
    -- A vector of Lengths (each in Items), valid with SOF.
    RX_LENGTH        : in  std_logic_vector(MFB_REGIONS*LENGTH_WIDTH-1 downto 0);
    -- Enable data validation, valid with SOF.
    RX_ENABLE        : in  std_logic_vector(MFB_REGIONS-1 downto 0);

    -- ========================================================================
    -- TX STREAM
    --
    -- Validated data.
    -- ========================================================================

    -- Extracted data for the checksum calculation.
    TX_DATA       : out std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
    TX_META       : out std_logic_vector(MFB_REGIONS*MFB_META_WIDTH-1 downto 0);
    -- Valid per each Item.
    TX_VLD        : out std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE-1 downto 0);
    TX_SRC_RDY    : out std_logic := '0';
    TX_DST_RDY    : in  std_logic
);
end entity;

architecture FULL of MFB_ITEMS_VLD is

    -- ========================================================================
    --                                CONSTANTS
    -- ========================================================================

    -- MFB data width.
    constant MFB_DATA_W       : natural := MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH;

    -- Maximum amount of Words a single packet can stretch over. (multiplied by 2 for one extra bit)
    constant PKT_MAX_WORDS    : natural := div_roundup(PKT_MTU, MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE) *2;

    -- Number of Items in a Region.
    constant SOFPOS_WORD_W  : natural := log2(MFB_REGIONS) + max(1, log2(MFB_REGION_SIZE)) + log2(MFB_BLOCK_SIZE);
    constant REGION_ITEMS   : natural := MFB_REGION_SIZE*MFB_BLOCK_SIZE;
    constant REGION_ITEMS_W : natural := log2(REGION_ITEMS);
    -- MAX_REGIONS = maximum amount of Regions (possibly across multiple words) a single packet can strech over.
    constant MAX_REGIONS_W  : natural := max(0, OFFSET_WIDTH - REGION_ITEMS_W);
    constant WORD_ITEMS_W : natural := log2(MFB_REGIONS) + REGION_ITEMS_W;

    -- Extended
    constant OFFSET_WIDTH_EXT : natural := minimum(max(WORD_ITEMS_W, log2(PKT_MTU)), max(WORD_ITEMS_W, OFFSET_WIDTH+LENGTH_WIDTH)) + 1;
    -- Diminished
    constant OFFSET_WIDTH_DIM : natural := tsel(LENGTH_WIDTH >= REGION_ITEMS_W, LENGTH_WIDTH, REGION_ITEMS_W);

    -- ========================================================================
    --                                 SIGNALS
    -- ========================================================================

    signal rx_length_arr         : u_array_t       (MFB_REGIONS-1 downto 0)(LENGTH_WIDTH-1 downto 0);
    signal length_not_0          : std_logic_vector(MFB_REGIONS-1 downto 0);

    signal word_cnt              : u_array_t(MFB_REGIONS downto 0)(log2(PKT_MAX_WORDS)-1 downto 0);

    signal rx_offset_arr         : u_array_t(MFB_REGIONS-1 downto 0)(OFFSET_WIDTH-1 downto 0);
    signal rx_mfb_sof_pos_arr    : u_array_t(MFB_REGIONS-1 downto 0)(max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    signal rx_sof_pos_word       : u_array_t(MFB_REGIONS-1 downto 0)(SOFPOS_WORD_W-1 downto 0);
    signal act_offset            : u_array_t(MFB_REGIONS-1 downto 0)(OFFSET_WIDTH_EXT-1 downto 0);

    signal rx_data_reg0          : std_logic_vector(MFB_DATA_W-1 downto 0);
    signal rx_meta_reg0          : std_logic_vector(MFB_REGIONS*MFB_META_WIDTH-1 downto 0);
    signal rx_sof_pos_reg0       : std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    -- signal rx_eof_pos_reg0       : std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    signal rx_sof_reg0           : std_logic_vector(MFB_REGIONS-1 downto 0);
    -- signal rx_eof_reg0           : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal rx_src_rdy_reg0       : std_logic;
    signal rx_dst_rdy_reg0       : std_logic;
    signal rx_offset_reg0        : u_array_t       (MFB_REGIONS-1 downto 0)(OFFSET_WIDTH_EXT-1 downto 0);
    signal rx_length_reg0        : u_array_t       (MFB_REGIONS-1 downto 0)(LENGTH_WIDTH-1 downto 0);
    signal rx_enable_reg0        : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal word_cnt_reg0         : u_array_t       (MFB_REGIONS-1 downto 0)(log2(PKT_MAX_WORDS)-1 downto 0);
    signal word_cnt_prev_reg0    : u_array_t       (MFB_REGIONS-1 downto 0)(log2(PKT_MAX_WORDS)-1 downto 0);

    signal vp_rx_word            : u_array_t       (MFB_REGIONS-1 downto 0)(log2(PKT_MAX_WORDS)-1 downto 0);
    signal vp_rx_offset          : u_array_t       (MFB_REGIONS-1 downto 0)(OFFSET_WIDTH_EXT-1 downto 0);
    signal vp_rx_length          : u_array_t       (MFB_REGIONS-1 downto 0)(LENGTH_WIDTH-1 downto 0);
    signal vp_rx_valid           : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal vp_rx_src_rdy         : std_logic;
    signal vp_rx_dst_rdy         : std_logic;
    signal vp_tx_offset          : u_array_t       (MFB_REGIONS-1 downto 0)(OFFSET_WIDTH_EXT-1 downto 0);
    signal vp_tx_length          : u_array_t       (MFB_REGIONS-1 downto 0)(LENGTH_WIDTH-1 downto 0);
    signal vp_tx_valid           : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal vp_tx_src_rdy         : std_logic;
    signal vp_tx_dst_rdy         : std_logic;
    
    signal vp_tx_offset1_reg0        : u_array_t       (MFB_REGIONS-1 downto 0)(OFFSET_WIDTH_EXT-1 downto 0);
    signal vp_tx_length1_reg0        : u_array_t       (MFB_REGIONS-1 downto 0)(LENGTH_WIDTH-1 downto 0);
    signal vp_tx_valid1_reg0         : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal vp_word_reg0              : u_array_t       (MFB_REGIONS-1 downto 0)(log2(PKT_MAX_WORDS)-1 downto 0);
    signal offset_from_vp_reached    : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal vp_tx_offset2_reg0        : u_array_t       (MFB_REGIONS-1 downto 0)(OFFSET_WIDTH_EXT-1 downto 0);
    signal vp_tx_length2_reg0        : u_array_t       (MFB_REGIONS-1 downto 0)(LENGTH_WIDTH-1 downto 0);
    signal vp_tx_valid2_reg0         : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal offset_from_input_reached : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal vp_tx_src_rdy_reg0        : std_logic;
    signal vp_tx_dst_rdy_reg0        : std_logic;
    
    signal rx_data_reg1           : std_logic_vector(MFB_DATA_W-1 downto 0);
    signal rx_data_items_reg1     : slv_array_t     (MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE-1 downto 0)(MFB_ITEM_WIDTH-1 downto 0); -- debug
    signal rx_meta_reg1           : std_logic_vector(MFB_REGIONS*MFB_META_WIDTH-1 downto 0);
    signal vd_offset1_reg1        : u_array_t       (MFB_REGIONS-1 downto 0)(OFFSET_WIDTH_EXT-1 downto 0);
    signal vd_length1_reg1        : u_array_t       (MFB_REGIONS-1 downto 0)(LENGTH_WIDTH-1 downto 0);
    signal vd_valid1_reg1         : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal vd_offset2_reg1        : u_array_t       (MFB_REGIONS-1 downto 0)(OFFSET_WIDTH_EXT-1 downto 0);
    signal vd_length2_reg1        : u_array_t       (MFB_REGIONS-1 downto 0)(LENGTH_WIDTH-1 downto 0);
    signal vd_valid2_reg1         : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal vd_src_rdy_reg1        : std_logic;
    signal vd_dst_rdy_reg1        : std_logic;

    signal vd_offset1_low         : u_array_t       (MFB_REGIONS-1 downto 0)(REGION_ITEMS_W-1 downto 0);
    signal vd_offset1_high_tmp    : u_array_t       (MFB_REGIONS-1 downto 0)(OFFSET_WIDTH_DIM downto 0);
    signal vd_offset1_high        : u_array_t       (MFB_REGIONS-1 downto 0)(REGION_ITEMS_W-1 downto 0);
    signal vd_valid1              : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal vd_offset2_low         : u_array_t       (MFB_REGIONS-1 downto 0)(REGION_ITEMS_W-1 downto 0);
    signal vd_offset2_high_tmp    : u_array_t       (MFB_REGIONS-1 downto 0)(OFFSET_WIDTH_DIM downto 0);
    signal vd_offset2_high        : u_array_t       (MFB_REGIONS-1 downto 0)(REGION_ITEMS_W-1 downto 0);
    signal vd_valid2              : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal vd_valid_vec           : std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE-1 downto 0);

begin

    assert (OFFSET_WIDTH <= log2(PKT_MTU))
        report "MFB_ITEMS_VLD: the value of the OFFSET_WIDTH generic can't be greater than log2(PKT_MTU)!"-- &
            -- " offset width: " & integer'image(OFFSET_WIDTH) &
            -- "log2(MTU): " & integer'image(log2(PKT_MTU))
        severity failure;

    assert (LENGTH_WIDTH <= log2(PKT_MTU))
        report "MFB_ITEMS_VLD: the value of the LENGTH_WIDTH generic can't be greater than the log2(PKT_MTU)!"-- &
            -- " length width: " & integer'image(LENGTH_WIDTH) &
            -- "log2(MTU): " & integer'image(log2(PKT_MTU))
        severity failure;

    -- TODO: Add more asserts ?
    -- for current offset+length?

    RX_MFB_DST_RDY <= rx_dst_rdy_reg0;

    -- -----------------------
    --  Validate input length
    -- -----------------------
    rx_length_arr <= slv_arr_to_u_arr(slv_array_deser(RX_LENGTH, MFB_REGIONS));
    length_check_g : for r in 0 to MFB_REGIONS-1 generate
        length_not_0(r) <= '1' when (rx_length_arr(r) > 0) else '0';
    end generate;

    -- --------------
    --  Word counter
    -- --------------
    word_cnt_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RX_MFB_SRC_RDY = '1') and (rx_dst_rdy_reg0 = '1') then
                word_cnt(0) <= word_cnt(MFB_REGIONS) + 1;
            end if;
            if (RESET = '1') then
                word_cnt(0) <= (others => '0');
            end if;
        end if;
    end process;

    -- Current (Valid) counts are at word_cnt(MFB_REGIONS downto 1) and
    -- word_cnt(0) carries the value from the previous clock cycle
    word_cnt_g: for r in 0 to MFB_REGIONS-1 generate
        word_cnt(r+1) <= (others => '0') when (RX_MFB_SOF(r) = '1') and (length_not_0(r) = '1') else word_cnt(r);
    end generate;

    -- -----------------------
    --  Offset precalculation
    -- -----------------------
    rx_offset_arr      <= slv_arr_to_u_arr(slv_array_deser(RX_OFFSET     , MFB_REGIONS));
    rx_mfb_sof_pos_arr <= slv_arr_to_u_arr(slv_array_deser(RX_MFB_SOF_POS, MFB_REGIONS));
    act_offset_g : for r in 0  to MFB_REGIONS-1 generate
        rx_sof_pos_word(r) <= to_unsigned(r, log2(MFB_REGIONS)) &   -- add the Regional prefix
                              rx_mfb_sof_pos_arr(r)             &   -- to the SOF POS
                              to_unsigned(0, log2(MFB_BLOCK_SIZE)); -- and conver it to Items
        -- Actual Offset begins from the start of the word rather than the SOF POS
        act_offset(r) <= resize_left(rx_offset_arr(r), OFFSET_WIDTH_EXT) + resize_left(rx_sof_pos_word(r), WORD_ITEMS_W);
    end generate;

    -- ========================================================================
    -- Input register
    -- ========================================================================

    rx_dst_rdy_reg0 <= vp_rx_dst_rdy;

    process(CLK)
    begin
        if rising_edge(CLK) then
            if (vp_rx_dst_rdy = '1') then
                rx_data_reg0    <= RX_MFB_DATA;
                rx_sof_pos_reg0 <= RX_MFB_SOF_POS;
                -- rx_eof_pos_reg0 <= RX_MFB_EOF_POS;
                rx_sof_reg0     <= RX_MFB_SOF and RX_MFB_SRC_RDY and length_not_0;
                -- rx_eof_reg0     <= RX_MFB_EOF;
                rx_src_rdy_reg0 <= RX_MFB_SRC_RDY;

                rx_offset_reg0  <= act_offset;
                rx_length_reg0  <= rx_length_arr; -- as rx_offset_end this could be pre-calculated (=> easier calculation?)
                rx_enable_reg0  <= RX_ENABLE;

                word_cnt_reg0   <= word_cnt(MFB_REGIONS downto 1);
                word_cnt_prev_reg0 <= word_cnt(MFB_REGIONS-1 downto 0);
            end if;

            if (RESET = '1') then
                rx_src_rdy_reg0 <= '0';
            end if;
        end if;
    end process;

    -- ------------------------
    --  Validation Do RX inf 1
    -- ------------------------
    -- Check the Offset from the input register
    offset_reached2_g : for r in 0 to MFB_REGIONS-1 generate
        offset_reached2_i : entity work.OFFSET_REACHED
        generic map(
            MAX_WORDS     => PKT_MAX_WORDS   ,
            REGIONS       => MFB_REGIONS     ,
            REGION_ITEMS  => REGION_ITEMS    ,
            OFFSET_WIDTH  => OFFSET_WIDTH_EXT,
            REGION_NUMBER => r
        )
        port map(
            RX_WORD    => word_cnt_reg0 (r),
            RX_OFFSET  => rx_offset_reg0(r),
            RX_VALID   => rx_sof_reg0   (r), -- and rx_enable_reg0
    
            TX_REACHED => offset_from_input_reached(r)
        );
    end generate;

    vp_tx_offset2_reg0 <= rx_offset_reg0;
    vp_tx_length2_reg0 <= rx_length_reg0;
    vp_tx_valid2_reg0  <= offset_from_input_reached;

    -- ------------------------
    --  Validation Do RX inf 2
    -- ------------------------
    vp_rx_word    <= word_cnt_reg0;
    vp_rx_offset  <= rx_offset_reg0;
    vp_rx_length  <= rx_length_reg0;
    vp_rx_valid   <= rx_sof_reg0; -- and rx_enable_reg0
    vp_rx_src_rdy <= rx_src_rdy_reg0;

    -- Prepare for validation
    validation_prepare_i : entity work.VALIDATION_PREPARE
    generic map(
        MFB_REGIONS     => MFB_REGIONS    ,
        MFB_REGION_SIZE => MFB_REGION_SIZE,
        MFB_BLOCK_SIZE  => MFB_BLOCK_SIZE ,
        MAX_WORDS       => PKT_MAX_WORDS  ,
        OFFSET_WIDTH    => OFFSET_WIDTH_EXT,
        LENGTH_WIDTH    => LENGTH_WIDTH
    )
    port map(
        CLK   => CLK,
        RESET => RESET,

        RX_WORD    => vp_rx_word   ,
        RX_OFFSET  => vp_rx_offset , -- RX_OFFSET_START
        RX_LENGTH  => vp_rx_length , -- as RX_OFFSET_END this could be pre-calculated (=> easier calculation?)
        RX_VALID   => vp_rx_valid  ,
        RX_SRC_RDY => vp_rx_src_rdy,
        RX_DST_RDY => vp_rx_dst_rdy,

        TX_OFFSET  => vp_tx_offset ,
        TX_LENGTH  => vp_tx_length ,
        TX_VALID   => vp_tx_valid  ,
        TX_SRC_RDY => vp_tx_src_rdy,
        TX_DST_RDY => vp_tx_dst_rdy
    );

    vp_tx_src_rdy_reg0 <= vp_tx_src_rdy;
    vp_tx_dst_rdy <= vp_tx_dst_rdy_reg0;

    -- VP output logic:
    -- 1) Shift one Region backward
    vp_to_vd1_g : for r in 0 to MFB_REGIONS-2 generate
        vp_tx_offset1_reg0(r+1) <= vp_tx_offset(r);
        vp_tx_length1_reg0(r+1) <= vp_tx_length(r);
        vp_tx_valid1_reg0 (r+1) <= vp_tx_valid (r);
    end generate;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (vp_tx_src_rdy_reg0 = '1') and (vp_tx_dst_rdy_reg0 = '1') then
                vp_tx_offset1_reg0(0) <= vp_tx_offset(MFB_REGIONS-1);
                vp_tx_length1_reg0(0) <= vp_tx_length(MFB_REGIONS-1);
                vp_tx_valid1_reg0 (0) <= vp_tx_valid (MFB_REGIONS-1);
            end if;
            if (RESET = '1') then
                vp_tx_valid1_reg0(0) <= '0';
            end if;
        end if;
    end process;

    vp_word_reg0 <= word_cnt_prev_reg0;

    -- 2) Check whether the shifted Offset is in each Region
    offset_reached1_g : for r in 0 to MFB_REGIONS-1 generate
        offset_reached1_i : entity work.OFFSET_REACHED
        generic map(
            MAX_WORDS     => PKT_MAX_WORDS   ,
            REGIONS       => MFB_REGIONS     ,
            REGION_ITEMS  => REGION_ITEMS    ,
            OFFSET_WIDTH  => OFFSET_WIDTH_EXT,
            REGION_NUMBER => r
        )
        port map(
            RX_WORD    => vp_word_reg0      (r),
            RX_OFFSET  => vp_tx_offset1_reg0(r),
            RX_VALID   => vp_tx_valid1_reg0 (r),
    
            TX_REACHED => offset_from_vp_reached(r)
        );
    end generate;

    -- ----------------------------------------
    --  Secong stage (Mid-validation) register
    -- ----------------------------------------
    vp_tx_dst_rdy_reg0 <= vd_dst_rdy_reg1;

    process(CLK)
    begin
        if rising_edge(CLK) then
            if (vd_dst_rdy_reg1 = '1') then
                rx_data_reg1    <= rx_data_reg0;
                rx_data_items_reg1 <= slv_array_deser(rx_data_reg0, MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE); -- Debug data signal

                -- TODO: swap 1 and 2
                vd_offset1_reg1 <= vp_tx_offset1_reg0;
                vd_length1_reg1 <= vp_tx_length1_reg0;
                vd_valid1_reg1  <= offset_from_vp_reached;

                vd_offset2_reg1 <= vp_tx_offset2_reg0;
                vd_length2_reg1 <= vp_tx_length2_reg0;
                vd_valid2_reg1  <= vp_tx_valid2_reg0;

                vd_src_rdy_reg1 <= vp_tx_src_rdy_reg0;
            end if;

            if (RESET = '1') then
                vd_valid1_reg1  <= (others => '0');
                vd_valid2_reg1  <= (others => '0');
                vd_src_rdy_reg1 <= '0';
            end if;
        end if;
    end process;

    -- -----------------------------
    --  Do (perform) the validation
    -- -----------------------------
    vd_inputs_adjust_g : for r in 0 to MFB_REGIONS-1 generate
        vd_offset1_low(r) <= resize_left(vd_offset1_reg1(r), REGION_ITEMS_W);
        vd_offset2_low(r) <= resize_left(vd_offset2_reg1(r), REGION_ITEMS_W);

        vd_offset_high_tmp_g : if LENGTH_WIDTH < WORD_ITEMS_W generate
            vd_offset1_high_tmp(r) <= resize_left(vd_offset1_low(r), OFFSET_WIDTH_DIM+1) + vd_length1_reg1(r);
            vd_offset2_high_tmp(r) <= resize_left(vd_offset2_low(r), OFFSET_WIDTH_DIM+1) + vd_length2_reg1(r);
        else generate
            vd_offset1_high_tmp(r) <= vd_offset1_low(r) + resize_left(vd_length1_reg1(r), OFFSET_WIDTH_DIM+1);
            vd_offset2_high_tmp(r) <= vd_offset2_low(r) + resize_left(vd_length2_reg1(r), OFFSET_WIDTH_DIM+1);
        end generate;

        -- The high Offset is all '1's when it is over the scope of this Region.
        vd_offset1_high(r) <= resize_left(vd_offset1_high_tmp(r)-1, REGION_ITEMS_W) when (vd_offset1_high_tmp(r) < REGION_ITEMS) else (others => '1');
        vd_offset2_high(r) <= resize_left(vd_offset2_high_tmp(r)-1, REGION_ITEMS_W) when (vd_offset2_high_tmp(r) < REGION_ITEMS) else (others => '1');
    end generate;

    vd_valid1 <= vd_valid1_reg1;
    vd_valid2 <= vd_valid2_reg1;

    validation_do_i : entity work.VALIDATION_DO
    generic map(
        MFB_REGIONS     => MFB_REGIONS    ,
        MFB_REGION_SIZE => MFB_REGION_SIZE,
        MFB_BLOCK_SIZE  => MFB_BLOCK_SIZE
    )
    port map(
        OFFSET1_LOW  => vd_offset1_low ,
        OFFSET1_HIGH => vd_offset1_high,
        VALID1       => vd_valid1      ,

        OFFSET2_LOW  => vd_offset2_low ,
        OFFSET2_HIGH => vd_offset2_high,
        VALID2       => vd_valid2      ,

        VALID_VECTOR => vd_valid_vec
    );

    -- ========================================================================
    -- Output register
    -- ========================================================================

    process(CLK)
    begin
        if rising_edge(CLK) then
            if (TX_DST_RDY = '1') then
                TX_DATA    <= rx_data_reg1;
                TX_META    <= rx_meta_reg1;
                TX_VLD     <= vd_valid_vec;
                TX_SRC_RDY <= vd_src_rdy_reg1 and (or vd_valid_vec); -- TODO
            end if;

            if (RESET = '1') then
                TX_VLD     <= (others => '0');
                TX_SRC_RDY <= '0';
            end if;
        end if;
    end process;

    vd_dst_rdy_reg1 <= TX_DST_RDY;

end architecture;
