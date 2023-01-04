-- xof_to_item_vld_conv.vhd: A component that converts SOFs with an offset to Item valid.
-- Copyright (C) 2022 CESNET z. s. p. o.
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

-- 
entity XOF_TO_ITEM_VLD_CONV is
generic(
    -- Number of Regions within a data word, must be power of 2.
    MFB_REGIONS           : natural := 4;
    -- Region size (in Blocks).
    MFB_REGION_SIZE       : natural := 8;
    -- Block size (in Items).
    MFB_BLOCK_SIZE        : natural := 8;
    -- Item width (in bits), must be 8.
    MFB_ITEM_WIDTH        : natural := 8;

    -- Width of the total offset from the SOF (in bits).
    SOF_OFFSET_W       : natural := 7
);
port(
    -- ========================================================================
    -- Clock and Reset
    -- ========================================================================

    CLK              : in  std_logic;
    RESET            : in  std_logic;

    -- ========================================================================
    -- RX Interface
    -- ========================================================================

    RX_SOF_POS    : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    -- Offset from the SOF (in Items), valid with SOF.
    RX_SOF_OFFSET : in  std_logic_vector(MFB_REGIONS*SOF_OFFSET_W-1 downto 0);
    RX_SOF        : in  std_logic_vector(MFB_REGIONS-1 downto 0);
    RX_SRC_RDY    : in  std_logic;
    RX_DST_RDY    : out std_logic;

    -- ========================================================================
    -- TX Interface
    -- ========================================================================

    TX_ITEM_VLD  : out std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE-1 downto 0);
    TX_SRC_RDY   : out std_logic;
    TX_DST_RDY   : in  std_logic
);
end entity;

architecture FULL of XOF_TO_ITEM_VLD_CONV is

-- ========================================================================
--                           FUNCTION DECLARATIONS
-- ========================================================================

function or_slv_array(slv_array : slv_array_t; items : integer) return std_logic_vector;
function or_u_array(u_array : u_array_t; items : integer) return unsigned;

    -- ========================================================================
    --                                CONSTANTS
    -- ========================================================================

    -- MFB data width.
    constant MFB_DATA_W           : natural := MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH;
    constant MFB_REGION_W         : natural := MFB_DATA_W/MFB_REGIONS;
    constant MFB_DATA_ITEMS       : natural := MFB_DATA_W/MFB_ITEM_WIDTH;

    -- SOF POS width (for one Region).
    constant SOF_POS_W            : natural := max(1,log2(MFB_REGION_SIZE));
    -- SOF POS width (for the whole word).
    constant SOF_POS_WORD_W       : natural := log2(MFB_REGIONS) + SOF_POS_W;
    -- SOF POS width (for the whole word and in Items).
    constant SOF_POS_WORD_ITEMS_W : natural := SOF_POS_WORD_W + log2(MFB_BLOCK_SIZE);

    -- Width of the SOF POS signal across the whole word.
    constant SOF_POS_LONG_W       : natural := max(log2(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE), SOF_OFFSET_W) + 1;

    -- Width of the signal indicating the target word.
    constant TARGET_WORD_W        : natural := SOF_POS_LONG_W - SOF_POS_WORD_ITEMS_W;

    -- ========================================================================
    --                                FUNCTIONS
    -- ========================================================================

    function or_slv_array(slv_array : slv_array_t; items : integer) return std_logic_vector is
        variable v : std_logic_vector(slv_array(0)'high downto 0) := (others => '0');
    begin
        for i in 0 to items-1 loop
            v := v or slv_array(i);
        end loop;
        return v;
    end;

    function or_u_array(u_array : u_array_t; items : integer) return unsigned is
        variable v : unsigned(u_array(0)'high downto 0) := (others => '0');
    begin
        for i in 0 to items-1 loop
            v := v or u_array(i);
        end loop;
        return v;
    end;

    -- ========================================================================
    --                                 SIGNALS
    -- ========================================================================

    -- state signals for L3 SOF POS FSM
    type state is (
        IDLE,
        HERE,
        FURTHER_1WORD,
        FURTHER,
        HERE_AND_FURTHER_1WORD,
        HERE_AND_FURTHER,
        HERE_END,
        HERE_END_AND_HERE,
        HERE_END_AND_FURTHER_1WORD,
        HERE_END_AND_FURTHER,
        HERE_END_HERE_AND_FURTHER,
        HERE_END_HERE_AND_FURTHER_1WORD
    );

    signal rx_sof_pos_arr         : u_array_t(MFB_REGIONS-1 downto 0)(SOF_POS_W-1 downto 0);
    signal rx_offset_arr          : u_array_t(MFB_REGIONS-1 downto 0)(SOF_OFFSET_W-1 downto 0);

    signal rx_sof_pos_reg0        : std_logic_vector(MFB_REGIONS*SOF_POS_W-1 downto 0);
    signal rx_sof_reg0            : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal rx_src_rdy_reg0        : std_logic;
    signal l3_sof_pos_word_reg0   : u_array_t(MFB_REGIONS-1 downto 0)(SOF_POS_WORD_ITEMS_W-1 downto 0);
    signal valid_sof_reg0         : std_logic_vector(MFB_REGIONS-1 downto 0);
    
    signal l3_sof_pos_long        : u_array_t(MFB_REGIONS-1 downto 0)(SOF_POS_LONG_W-1 downto 0);
    signal l3_sof_pos_target_word : u_array_t(MFB_REGIONS-1 downto 0)(TARGET_WORD_W-1 downto 0);
    signal l3_sof_pos_word        : u_array_t(MFB_REGIONS-1 downto 0)(SOF_POS_WORD_ITEMS_W-1 downto 0);
    signal l3_sof_pos_this_word_r : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l3_sof_pos_this_word   : std_logic;
    signal l3_sof_pos_future_word : std_logic;

    signal l3_sof_pos_word_select          : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l3_sof_pos_word_selected        : unsigned(SOF_POS_WORD_ITEMS_W-1 downto 0);
    signal l3_sof_pos_target_word_selected : unsigned(TARGET_WORD_W-1 downto 0);

    signal target_word_count_reached : std_logic;
    signal target_word_reached       : std_logic;

    signal l3_sof_pos_word_dly        : unsigned(SOF_POS_WORD_ITEMS_W-1 downto 0);
    signal l3_sof_pos_word_dly2       : unsigned(SOF_POS_WORD_ITEMS_W-1 downto 0);
    signal l3_sof_pos_target_word_dly : unsigned(TARGET_WORD_W-1 downto 0);
    signal l3_sof_pos_future_word_dly : std_logic := '0';

    signal l3_sof_pos_word_vld      : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l3_sof_pos_word_dly_vld  : std_logic;

    signal l3_word_count_rst        : std_logic;
    signal l3_word_count_rst_to_one : std_logic;
    signal l3_word_count_en         : std_logic;

    signal l3_word_count            : unsigned(TARGET_WORD_W-1 downto 0);

    signal l3_sof_pos_addr_en       : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l3_sof_pos_addr          : slv_array_t     (MFB_REGIONS-1 downto 0)(SOF_POS_WORD_ITEMS_W-1 downto 0);
    signal l3_sof_pos_onehot        : slv_array_t     (MFB_REGIONS-1 downto 0)(2**SOF_POS_WORD_ITEMS_W-1 downto 0); -- MFB_DATA_ITEMS

    signal l3_sof_pos_addr_dly_en   : std_logic;
    signal l3_sof_pos_addr_dly      : std_logic_vector(SOF_POS_WORD_ITEMS_W-1 downto 0);
    signal l3_sof_pos_onehot_dly    : std_logic_vector(2**SOF_POS_WORD_ITEMS_W-1 downto 0); -- MFB_DATA_ITEMS

    signal l3_sof_pos_multihot_r    : slv_array_t(MFB_REGIONS-1 downto 0)(2**SOF_POS_WORD_ITEMS_W-1 downto 0); -- MFB_DATA_ITEMS
    signal l3_sof_pos_multihot      : std_logic_vector(2**SOF_POS_WORD_ITEMS_W-1 downto 0); -- MFB_DATA_ITEMS

    signal state_change_en          : std_logic;
    signal present_st               : state := IDLE;
    signal next_st                  : state := IDLE;

begin

    RX_DST_RDY <= TX_DST_RDY;

    -- ========================================================================
    -- Input logic
    -- ========================================================================

    rx_sof_pos_arr <= slv_arr_to_u_arr(slv_array_deser(RX_SOF_POS   , MFB_REGIONS), MFB_REGIONS);
    rx_offset_arr  <= slv_arr_to_u_arr(slv_array_deser(RX_SOF_OFFSET, MFB_REGIONS), MFB_REGIONS);

    -- Input logic for the FSM
    l3_sof_pos_g : for r in 0 to MFB_REGIONS-1 generate
        -- Applies only for MFB_REGIONS > 1 !!!
        -- Add: the SOF POS and the L2 Header length and offset it by the number of the current Region.
        l3_sof_pos_long(r) <= resize(resize_right(rx_sof_pos_arr(r), SOF_POS_W+log2(MFB_BLOCK_SIZE)), SOF_POS_LONG_W) +
                              rx_offset_arr(r)                                                                           +
                              resize_right(to_unsigned(r, log2(MFB_REGIONS)), log2(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE));
        
        -- Split the l3_sof_pos_long into:
        -- the MSBs indicating the target word of the SOF POS and ...
        l3_sof_pos_target_word(r) <= l3_sof_pos_long(r)(SOF_POS_LONG_W-1 downto SOF_POS_LONG_W-TARGET_WORD_W);
        -- ... the rest indicating SOF POS across the whole word
        l3_sof_pos_word(r) <= l3_sof_pos_long(r)(SOF_POS_LONG_W-TARGET_WORD_W-1 downto 0);

        -- Indicates whether the l3 SOF POS is in the current word (per Region)
        l3_sof_pos_this_word_r(r) <= not (or l3_sof_pos_target_word(r));

    end generate;

    -- Indicates whether the l3 SOF POS is in the current word (per word)
    l3_sof_pos_this_word <= or (l3_sof_pos_this_word_r and RX_SOF) and RX_SRC_RDY;
    -- Indicates whether the l3 SOF POS will be in one of the following words (per word)
    l3_sof_pos_future_word <= or ((not l3_sof_pos_this_word_r) and RX_SOF) and RX_SRC_RDY;

    -- ========================================================================
    -- Input register
    -- ========================================================================
    process(CLK)
    begin
        if rising_edge(CLK) then
            if (TX_DST_RDY = '1') then

                for r in 0 to MFB_REGIONS-1 loop
                    if (l3_sof_pos_this_word_r(r) = '1') and (RX_SOF(r) = '1') and (RX_SRC_RDY = '1') then
                        valid_sof_reg0(r) <= '1';
                    else
                        valid_sof_reg0(r) <= '0';
                    end if;
                end loop;

                l3_sof_pos_word_reg0 <= l3_sof_pos_word;
                rx_src_rdy_reg0 <= RX_SRC_RDY;

            end if;

            if (RESET = '1') then
                rx_src_rdy_reg0 <= '0';
            end if;
        end if;
    end process;

    -- ========================================================================
    -- Pre-FSM logic
    -- ========================================================================

    word_sel_g : for r in MFB_REGIONS-1 downto 0 generate
        l3_sof_pos_word_select(r) <= '1' when (l3_sof_pos_this_word_r(r) = '0') and (RX_SOF(r) = '1') and (RX_SRC_RDY = '1') else '0';
    end generate;

    -- Prepare data for the put-aside register.
    process(all)
    begin
        l3_sof_pos_word_selected        <= (others => '0');
        l3_sof_pos_target_word_selected <= (others => '0');

        -- Select only the data that are for one of the following (future) words.
        for r in 0 to MFB_REGIONS-1 loop
            if (l3_sof_pos_word_select(r) = '1') then
                l3_sof_pos_word_selected        <= l3_sof_pos_word       (r);
                l3_sof_pos_target_word_selected <= l3_sof_pos_target_word(r);
                exit;
            end if;
        end loop;
    end process;

    target_word_count_reached <= '1' when (l3_word_count+1 = l3_sof_pos_target_word_dly) else '0';
    -- target_word_reached <= target_word_count_reached or l3_sof_pos_future_word;

    -- Set-aside register: delays data until the target word is reached.
    process(CLK)
    begin
        if rising_edge(CLK) then

            if (RX_SRC_RDY = '1') and (TX_DST_RDY = '1') then
                if (l3_sof_pos_future_word = '1') then
                    l3_sof_pos_word_dly        <= l3_sof_pos_word_selected;
                    l3_sof_pos_target_word_dly <= l3_sof_pos_target_word_selected;
                    -- l3_sof_pos_future_word_dly <= '1';
                -- elsif (target_word_count_reached = '1') then
                --     l3_sof_pos_word_dly        <= (others => '0'); -- not necessary
                --     l3_sof_pos_target_word_dly <= (others => '0'); -- not necessary
                --     l3_sof_pos_future_word_dly <= '0';
                end if;
            end if;

            l3_sof_pos_word_dly2 <= l3_sof_pos_word_dly;

            if (RESET = '1') then
                l3_sof_pos_word_dly        <= (others => '0'); -- not necessary
                l3_sof_pos_target_word_dly <= (others => '0'); -- not necessary
                l3_sof_pos_future_word_dly <= '0';
            end if;

        end if;
    end process;

    -- ========================================================================
    -- FSM
    -- States: IDLE                - default
    --         ALL_HERE            - all offset SOFs are in this word
    --         FURTHER_ON          - an offset SOF only continues to one of the
    --                               following words
    --         HERE_AND_FURTHER_ON - an offset SOF is in this word and another
    --                               continues to one of the following words
    -- ========================================================================

    next_state_logic_p : process(all)
    begin
        case present_st is
            
            when IDLE =>
                if (l3_sof_pos_this_word = '1') and (l3_sof_pos_future_word = '0') then
                    next_st <= HERE;
                elsif (l3_sof_pos_this_word = '1') and (l3_sof_pos_future_word = '1') then
                    if (l3_sof_pos_target_word_selected = 1) then
                        next_st <= HERE_AND_FURTHER_1WORD;
                    else -- (l3_sof_pos_target_word_selected > 1)
                        next_st <= HERE_AND_FURTHER;
                    end if;
                elsif (l3_sof_pos_this_word = '0') and (l3_sof_pos_future_word = '1') then
                    if (l3_sof_pos_target_word_selected = 1) then
                        next_st <= FURTHER_1WORD;
                    else -- (l3_sof_pos_target_word_selected > 1)
                        next_st <= FURTHER;
                    end if;
                else -- (l3_sof_pos_this_word = '0') and (l3_sof_pos_future_word = '0')
                    next_st <= IDLE;
                end if;

            when HERE =>
                if (l3_sof_pos_this_word = '1') and (l3_sof_pos_future_word = '0') then
                    next_st <= HERE;
                elsif (l3_sof_pos_this_word = '1') and (l3_sof_pos_future_word = '1') then
                    if (l3_sof_pos_target_word_selected = 1) then
                        next_st <= HERE_AND_FURTHER_1WORD;
                    else -- (l3_sof_pos_target_word_selected > 1)
                        next_st <= HERE_AND_FURTHER;
                    end if;
                elsif (l3_sof_pos_this_word = '0') and (l3_sof_pos_future_word = '1') then
                    if (l3_sof_pos_target_word_selected = 1) then
                        next_st <= FURTHER_1WORD;
                    else -- (l3_sof_pos_target_word_selected > 1)
                        next_st <= FURTHER;
                    end if;
                else -- (l3_sof_pos_this_word = '0') and (l3_sof_pos_future_word = '0')
                    next_st <= IDLE;
                end if;

            when FURTHER_1WORD =>
                if (l3_sof_pos_this_word = '1') and (l3_sof_pos_future_word = '0') then
                    next_st <= HERE_END_AND_HERE;
                elsif (l3_sof_pos_this_word = '0') and (l3_sof_pos_future_word = '1') then
                    if (l3_sof_pos_target_word_selected = 1) then
                        next_st <= HERE_END_AND_FURTHER_1WORD;
                    else -- (l3_sof_pos_target_word_selected > 1)
                        next_st <= HERE_END_AND_FURTHER;
                    end if;
                elsif (l3_sof_pos_this_word = '1') and (l3_sof_pos_future_word = '1') then
                    if (l3_sof_pos_target_word_selected = 1) then
                        next_st <= HERE_END_HERE_AND_FURTHER_1WORD;
                    else -- (l3_sof_pos_target_word_selected > 1)
                        next_st <= HERE_END_HERE_AND_FURTHER;
                    end if;
                else -- (l3_sof_pos_this_word = '0') and (l3_sof_pos_future_word = '0')
                    next_st <= HERE_END;
                end if;

            when FURTHER =>
                if (target_word_count_reached = '1') then
                    if (l3_sof_pos_this_word = '1') and (l3_sof_pos_future_word = '0') then
                        next_st <= HERE_END_AND_HERE;
                    elsif (l3_sof_pos_this_word = '0') and (l3_sof_pos_future_word = '1') then
                        if (l3_sof_pos_target_word_selected = 1) then
                            next_st <= HERE_END_AND_FURTHER_1WORD;
                        else -- (l3_sof_pos_target_word_selected > 1)
                            next_st <= HERE_END_AND_FURTHER;
                        end if;
                    elsif (l3_sof_pos_this_word = '1') and (l3_sof_pos_future_word = '1') then
                        if (l3_sof_pos_target_word_selected = 1) then
                            next_st <= HERE_END_HERE_AND_FURTHER_1WORD;
                        else -- (l3_sof_pos_target_word_selected > 1)
                            next_st <= HERE_END_HERE_AND_FURTHER;
                        end if;
                    else -- (l3_sof_pos_this_word = '0') and (l3_sof_pos_future_word = '0')
                        next_st <= HERE_END;
                    end if;
                else -- (target_word_count_reached = '0')
                    next_st <= FURTHER;
                end if;

            when HERE_AND_FURTHER_1WORD =>
                if (l3_sof_pos_this_word = '1') and (l3_sof_pos_future_word = '0') then
                    next_st <= HERE_END_AND_HERE;
                elsif (l3_sof_pos_this_word = '0') and (l3_sof_pos_future_word = '1') then
                    if (l3_sof_pos_target_word_selected = 1) then
                        next_st <= HERE_END_AND_FURTHER_1WORD;
                    else -- (l3_sof_pos_target_word_selected > 1)
                        next_st <= HERE_END_AND_FURTHER;
                    end if;
                elsif (l3_sof_pos_this_word = '1') and (l3_sof_pos_future_word = '1') then
                    if (l3_sof_pos_target_word_selected = 1) then
                        next_st <= HERE_END_HERE_AND_FURTHER_1WORD;
                    else -- (l3_sof_pos_target_word_selected > 1)
                        next_st <= HERE_END_HERE_AND_FURTHER;
                    end if;
                else -- (l3_sof_pos_this_word = '0') and (l3_sof_pos_future_word = '0')
                    next_st <= HERE_END;
                end if;

            when HERE_AND_FURTHER =>
                -- if (target_word_count_reached = '1') then
                --     if (l3_sof_pos_this_word = '1') and (l3_sof_pos_future_word = '0') then
                --         next_st <= HERE_END_AND_HERE;
                --     elsif (l3_sof_pos_this_word = '0') and (l3_sof_pos_future_word = '1') then
                --         if (l3_sof_pos_target_word_selected = 1) then
                --             next_st <= HERE_END_AND_FURTHER_1WORD;
                --         else -- (l3_sof_pos_target_word_selected > 1)
                --             next_st <= HERE_END_AND_FURTHER;
                --         end if;
                --     elsif (l3_sof_pos_this_word = '1') and (l3_sof_pos_future_word = '1') then
                --         if (l3_sof_pos_target_word_selected = 1) then
                --             next_st <= HERE_END_HERE_AND_FURTHER_1WORD;
                --         else -- (l3_sof_pos_target_word_selected > 1)
                --             next_st <= HERE_END_HERE_AND_FURTHER;
                --         end if;
                --     else -- (l3_sof_pos_this_word = '0') and (l3_sof_pos_future_word = '0')
                --         next_st <= HERE_END;
                --     end if;
                -- else -- (target_word_count_reached = '0')
                --     next_st <= FURTHER;
                -- end if;
                next_st <= FURTHER;

            when HERE_END =>
                if (l3_sof_pos_this_word = '1') and (l3_sof_pos_future_word = '0') then
                    next_st <= HERE;
                elsif (l3_sof_pos_this_word = '1') and (l3_sof_pos_future_word = '1') then
                    if (l3_sof_pos_target_word_selected = 1) then
                        next_st <= HERE_AND_FURTHER_1WORD;
                    else -- (l3_sof_pos_target_word_selected > 1)
                        next_st <= HERE_AND_FURTHER;
                    end if;
                elsif (l3_sof_pos_this_word = '0') and (l3_sof_pos_future_word = '1') then
                    if (l3_sof_pos_target_word_selected = 1) then
                        next_st <= FURTHER_1WORD;
                    else -- (l3_sof_pos_target_word_selected > 1)
                        next_st <= FURTHER;
                    end if;
                else -- (l3_sof_pos_this_word = '0') and (l3_sof_pos_future_word = '0')
                    next_st <= IDLE;
                end if;

            when HERE_END_AND_HERE =>
                if (l3_sof_pos_this_word = '1') and (l3_sof_pos_future_word = '0') then
                    next_st <= HERE;
                elsif (l3_sof_pos_this_word = '1') and (l3_sof_pos_future_word = '1') then
                    if (l3_sof_pos_target_word_selected = 1) then
                        next_st <= HERE_AND_FURTHER_1WORD;
                    else -- (l3_sof_pos_target_word_selected > 1)
                        next_st <= HERE_AND_FURTHER;
                    end if;
                elsif (l3_sof_pos_this_word = '0') and (l3_sof_pos_future_word = '1') then
                    if (l3_sof_pos_target_word_selected = 1) then
                        next_st <= FURTHER_1WORD;
                    else -- (l3_sof_pos_target_word_selected > 1)
                        next_st <= FURTHER;
                    end if;
                else -- (l3_sof_pos_this_word = '0') and (l3_sof_pos_future_word = '0')
                    next_st <= IDLE;
                end if;

            when HERE_END_AND_FURTHER_1WORD =>
                if (l3_sof_pos_this_word = '1') and (l3_sof_pos_future_word = '0') then
                    next_st <= HERE_END_AND_HERE;
                elsif (l3_sof_pos_this_word = '0') and (l3_sof_pos_future_word = '1') then
                    if (l3_sof_pos_target_word_selected = 1) then
                        next_st <= HERE_END_AND_FURTHER_1WORD;
                    else -- (l3_sof_pos_target_word_selected > 1)
                        next_st <= HERE_END_AND_FURTHER;
                    end if;
                elsif (l3_sof_pos_this_word = '1') and (l3_sof_pos_future_word = '1') then
                    if (l3_sof_pos_target_word_selected = 1) then
                        next_st <= HERE_END_HERE_AND_FURTHER_1WORD;
                    else -- (l3_sof_pos_target_word_selected > 1)
                        next_st <= HERE_END_HERE_AND_FURTHER;
                    end if;
                else -- (l3_sof_pos_this_word = '0') and (l3_sof_pos_future_word = '0')
                    next_st <= HERE_END;
                end if;

            when HERE_END_AND_FURTHER =>
                next_st <= FURTHER;

            when HERE_END_HERE_AND_FURTHER =>
                next_st <= FURTHER;

            when HERE_END_HERE_AND_FURTHER_1WORD =>
                if (l3_sof_pos_this_word = '1') and (l3_sof_pos_future_word = '0') then
                    next_st <= HERE_END_AND_HERE;
                elsif (l3_sof_pos_this_word = '0') and (l3_sof_pos_future_word = '1') then
                    if (l3_sof_pos_target_word_selected = 1) then
                        next_st <= HERE_END_AND_FURTHER_1WORD;
                    else -- (l3_sof_pos_target_word_selected > 1)
                        next_st <= HERE_END_AND_FURTHER;
                    end if;
                elsif (l3_sof_pos_this_word = '1') and (l3_sof_pos_future_word = '1') then
                    if (l3_sof_pos_target_word_selected = 1) then
                        next_st <= HERE_END_HERE_AND_FURTHER_1WORD;
                    else -- (l3_sof_pos_target_word_selected > 1)
                        next_st <= HERE_END_HERE_AND_FURTHER;
                    end if;
                else -- (l3_sof_pos_this_word = '0') and (l3_sof_pos_future_word = '0')
                    next_st <= HERE_END;
                end if;

            when others => 
                next_st <= IDLE;
        end case;
    end process;

    -- process(CLK)
    -- begin
    --     if (rising_edge(CLK)) then
    --         if (RX_SRC_RDY = '1') and (TX_DST_RDY = '1') and (present_st = FURTHER_ON) and (next_st = IDLE) then
    --             assert false
    --                 report "FURTHER_ON state: Invalid condition !! (Or something, IDK)" &
    --                         " l3_word_count value: " & integer'image(to_integer(l3_word_count)) &
    --                         " l3_sof_pos_target_word_dly value: " & integer'image(to_integer(l3_sof_pos_target_word_dly)) &
    --                         " target_word_count_reached value: " & to_string(target_word_count_reached)
    --                 severity failure;
    --         end if;
    --     end if;
    -- end process;

    present_state_reg_p : process(CLK)
    begin
        if (rising_edge(CLK)) then
            if (RX_SRC_RDY = '1') and (TX_DST_RDY = '1') then
                present_st <= next_st;
            end if;
            if (RESET = '1') then
                present_st <= IDLE;
            end if;
        end if;
    end process;

    output_logic_p : process(all)
    begin
        case present_st is
            when IDLE =>
                l3_sof_pos_word_vld     <= (others => '0');
                l3_sof_pos_word_dly_vld <= '0';

                l3_word_count_rst        <= '1';
                l3_word_count_rst_to_one <= '0';
                l3_word_count_en         <= '0';

            when HERE =>
                l3_sof_pos_word_vld     <= valid_sof_reg0;
                l3_sof_pos_word_dly_vld <= '0';

                l3_word_count_rst        <= '1';
                l3_word_count_rst_to_one <= '0';
                l3_word_count_en         <= '0';

            when FURTHER_1WORD =>
                l3_sof_pos_word_vld     <= (others => '0');
                l3_sof_pos_word_dly_vld <= '0';

                l3_word_count_rst        <= '1';
                l3_word_count_rst_to_one <= '0';
                l3_word_count_en         <= '0';

            when FURTHER =>
                l3_sof_pos_word_vld     <= (others => '0');
                l3_sof_pos_word_dly_vld <= '0';

                l3_word_count_rst        <= '0';
                l3_word_count_rst_to_one <= '0';
                l3_word_count_en         <= '1';

            when HERE_AND_FURTHER_1WORD =>
                l3_sof_pos_word_vld     <= valid_sof_reg0;
                l3_sof_pos_word_dly_vld <= '0';

                l3_word_count_rst        <= '1';
                l3_word_count_rst_to_one <= '0';
                l3_word_count_en         <= '0';

            when HERE_AND_FURTHER =>
                l3_sof_pos_word_vld     <= valid_sof_reg0;
                l3_sof_pos_word_dly_vld <= '0';

                l3_word_count_rst        <= '0'; -- 0
                l3_word_count_rst_to_one <= '1';
                l3_word_count_en         <= '0'; -- 1

            when HERE_END =>
                l3_sof_pos_word_vld     <= (others => '0');
                l3_sof_pos_word_dly_vld <= '1';

                l3_word_count_rst        <= '1';
                l3_word_count_rst_to_one <= '0';
                l3_word_count_en         <= '0';

            when HERE_END_AND_HERE =>
                l3_sof_pos_word_vld     <= valid_sof_reg0;
                l3_sof_pos_word_dly_vld <= '1';

                l3_word_count_rst        <= '1';
                l3_word_count_rst_to_one <= '0';
                l3_word_count_en         <= '0';

            when HERE_END_AND_FURTHER_1WORD =>
                l3_sof_pos_word_vld     <= (others => '0');
                l3_sof_pos_word_dly_vld <= '1';

                l3_word_count_rst        <= '1';
                l3_word_count_rst_to_one <= '0';
                l3_word_count_en         <= '0';

            when HERE_END_AND_FURTHER =>
                l3_sof_pos_word_vld     <= (others => '0');
                l3_sof_pos_word_dly_vld <= '1';

                l3_word_count_rst        <= '0';
                l3_word_count_rst_to_one <= '1';
                l3_word_count_en         <= '0';

            when HERE_END_HERE_AND_FURTHER =>
                l3_sof_pos_word_vld     <= valid_sof_reg0;
                l3_sof_pos_word_dly_vld <= '1';

                l3_word_count_rst        <= '0';
                l3_word_count_rst_to_one <= '1';
                l3_word_count_en         <= '0';

            when HERE_END_HERE_AND_FURTHER_1WORD =>
                l3_sof_pos_word_vld     <= valid_sof_reg0;
                l3_sof_pos_word_dly_vld <= '1';

                l3_word_count_rst        <= '1';
                l3_word_count_rst_to_one <= '0';
                l3_word_count_en         <= '0';

            when others =>
                l3_sof_pos_word_vld     <= (others => '0');
                l3_sof_pos_word_dly_vld <= '0';

                l3_word_count_rst        <= '1';
                l3_word_count_rst_to_one <= '0';
                l3_word_count_en         <= '0';

        end case;
    end process;

    -- ========================================================================
    -- Word counter
    -- ========================================================================

    process(CLK)
    begin
        if rising_edge(CLK) then
            if (RX_SRC_RDY = '1') and (TX_DST_RDY = '1') then

                if (l3_word_count_rst = '1') then
                    l3_word_count <= (others => '0');
                elsif (l3_word_count_rst_to_one = '1') then
                    l3_word_count <= to_unsigned(1, l3_word_count'length);
                elsif (l3_word_count_en = '1') then
                    l3_word_count <= l3_word_count + 1;
                end if;

            end if;

            if (RESET = '1') then
                l3_word_count <= (others => '0');
            end if;
        end if;
    end process;

    -- ========================================================================
    -- SOF POS converstion to Onehot format
    -- ========================================================================

    -- 1) from the Input register
    l3_sof_pos_addr_en <= l3_sof_pos_word_vld;
    l3_sof_pos_addr    <= u_arr_to_slv_arr(l3_sof_pos_word_reg0);

    l3_sof_pos_bin2hot_g : for r in 0 to MFB_REGIONS-1 generate

        bin2hot_i : entity work.BIN2HOT
        generic map(
            DATA_WIDTH => log2(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE)
        )
        port map(
            EN     => l3_sof_pos_addr_en(r),
            INPUT  => l3_sof_pos_addr   (r),
            OUTPUT => l3_sof_pos_onehot (r)
        );

    end generate;

    -- 2) from the put-aside register
    l3_sof_pos_addr_dly_en <= l3_sof_pos_word_dly_vld;
    l3_sof_pos_addr_dly    <= std_logic_vector(l3_sof_pos_word_dly2);

    l3_sof_pos_bin2hot_reg_i : entity work.BIN2HOT
    generic map(
        DATA_WIDTH => log2(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE)
    )
    port map(
        EN     => l3_sof_pos_addr_dly_en,
        INPUT  => l3_sof_pos_addr_dly   ,
        OUTPUT => l3_sof_pos_onehot_dly
    );

    -- Finish up SOF POSs to Item valid conversion
    l3_sof_pos_multihot <= or_slv_array(l3_sof_pos_onehot, MFB_REGIONS) or l3_sof_pos_onehot_dly;

    -- ========================================================================
    -- Output assignment
    -- ========================================================================

    TX_ITEM_VLD <= l3_sof_pos_multihot;
    TX_SRC_RDY  <= rx_src_rdy_reg0;

end architecture;
