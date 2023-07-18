-- mfb_frame_masker.vhd: MFB Frame Masker
-- Copyright (C) 2023 CESNET z. s. p. o.
-- Author(s): Yaroslav Marushchenko <xmarus09@stud.fit.vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- library containing log2 function
use work.math_pack.all;
-- library containing slv_array_t type
use work.type_pack.all;

-- =========================================================================
--  Description
-- =========================================================================

-- This component can mask incoming packets depending on the input TX_MASK value. This input allows to specify masking for each MFB region separately. 
-- It can handle all variations of packet layouts in a data word, for example, a packet that has only a beginning or only an end.
entity MFB_FRAME_MASKER is
    generic(
        -- =============================
        -- Bus parameters
        -- =============================
    
        -- Any power of two
        REGIONS     : integer := 4;
        -- Any power of two
        REGION_SIZE : integer := 8;
        -- Any power of two
        BLOCK_SIZE  : integer := 8;
        -- Any power of two
        ITEM_WIDTH  : integer := 8;
        -- Any power of two
        META_WIDTH  : integer := 0;

        -- =============================
        -- Other parameters
        -- =============================

        -- Enables MFB_PIPE on RX side
        USE_PIPE    : boolean := false
      );
    
      port(
        -- =============================
        -- Clock and Reset
        -- =============================
  
        CLK        : in std_logic;
        RESET      : in std_logic;
  
        -- =============================
        -- MFB input interface
        -- =============================
          
        RX_DATA    : in std_logic_vector(REGIONS*REGION_SIZE*BLOCK_SIZE*ITEM_WIDTH-1 downto 0);
        RX_META    : in std_logic_vector(REGIONS*META_WIDTH-1 downto 0) := (others => '0');
        RX_SOF     : in std_logic_vector(REGIONS-1 downto 0);
        RX_EOF     : in std_logic_vector(REGIONS-1 downto 0);
        RX_SOF_POS : in std_logic_vector(REGIONS*max(1,log2(REGION_SIZE))-1 downto 0);
        RX_EOF_POS : in std_logic_vector(REGIONS*max(1,log2(REGION_SIZE*BLOCK_SIZE))-1 downto 0);
        RX_SRC_RDY : in std_logic;
        RX_DST_RDY : out std_logic; 
  
        -- =============================
        -- MFB output interface
        -- =============================
  
        TX_DATA    : out std_logic_vector(REGIONS*REGION_SIZE*BLOCK_SIZE*ITEM_WIDTH-1 downto 0);
        TX_META    : out std_logic_vector(REGIONS*META_WIDTH-1 downto 0);
        TX_SOF     : out std_logic_vector(REGIONS-1 downto 0);
        TX_EOF     : out std_logic_vector(REGIONS-1 downto 0);
        TX_SOF_POS : out std_logic_vector(REGIONS*max(1,log2(REGION_SIZE))-1 downto 0);
        TX_EOF_POS : out std_logic_vector(REGIONS*max(1,log2(REGION_SIZE*BLOCK_SIZE))-1 downto 0);
        TX_SRC_RDY : out std_logic;
        TX_DST_RDY : in std_logic;

        -- =============================
        -- Mask signal
        -- =============================

        -- Bit signal of size ``REGIONS``, which specifies from which regions of the word packets will be read
        TX_MASK    : in std_logic_vector(REGIONS-1 downto 0)
      );
end entity;

architecture FULL of MFB_FRAME_MASKER is

    -- --------------------------------------------------------------------------
    --  Constants
    -- --------------------------------------------------------------------------

    constant SOF_POS_WIDTH : natural := max(1,log2(REGION_SIZE));
    constant EOF_POS_WIDTH : natural := max(1,log2(REGION_SIZE*BLOCK_SIZE));

    -- --------------------------------------------------------------------------
    --  MFB_PIPE output signals
    -- --------------------------------------------------------------------------

    signal pipe_tx_data    : std_logic_vector(REGIONS*REGION_SIZE*BLOCK_SIZE*ITEM_WIDTH-1 downto 0);
    signal pipe_tx_meta    : std_logic_vector(REGIONS*META_WIDTH-1 downto 0);
    signal pipe_tx_sof     : std_logic_vector(REGIONS-1 downto 0);
    signal pipe_tx_eof     : std_logic_vector(REGIONS-1 downto 0);
    signal pipe_tx_sof_pos : std_logic_vector(REGIONS*SOF_POS_WIDTH-1 downto 0);
    signal pipe_tx_eof_pos : std_logic_vector(REGIONS*EOF_POS_WIDTH-1 downto 0);
    signal pipe_tx_src_rdy : std_logic;
    signal pipe_tx_dst_rdy : std_logic;

    -- --------------------------------------------------------------------------
    --  Stored MFB data word
    -- --------------------------------------------------------------------------

    signal data_reg    : std_logic_vector(REGIONS*REGION_SIZE*BLOCK_SIZE*ITEM_WIDTH-1 downto 0);
    signal meta_reg    : std_logic_vector(REGIONS*META_WIDTH-1 downto 0);
    signal sof_reg     : std_logic_vector(REGIONS-1 downto 0);
    signal eof_reg     : std_logic_vector(REGIONS-1 downto 0);
    signal sof_pos_reg : std_logic_vector(REGIONS*SOF_POS_WIDTH-1 downto 0);
    signal eof_pos_reg : std_logic_vector(REGIONS*EOF_POS_WIDTH-1 downto 0);

    -- --------------------------------------------------------------------------
    --  FSM signals
    -- --------------------------------------------------------------------------

    type fsm_state_t is (IDLE, MASKING, DONE);
    signal curr_state : fsm_state_t;
    signal next_state : fsm_state_t;

    -- --------------------------------------------------------------------------
    --  Mask signals
    -- --------------------------------------------------------------------------
    
    signal full_mask   : std_logic_vector(REGIONS-1 downto 0);
    
    -- --------------------------------------------------------------------------
    --  Other signals
    -- --------------------------------------------------------------------------

    signal u_array_sof_pos_items            : u_array_t(REGIONS-1 downto 0)(EOF_POS_WIDTH-1 downto 0);
    signal u_array_sof_pos                  : u_array_t(REGIONS-1 downto 0)(SOF_POS_WIDTH-1 downto 0);
    signal u_array_eof_pos                  : u_array_t(REGIONS-1 downto 0)(EOF_POS_WIDTH-1 downto 0);
    signal prev_mask                        : std_logic_vector((REGIONS+1)-1 downto 0);
    signal whole_frame                      : std_logic_vector(REGIONS-1 downto 0);
    signal frame_only_with_beginning        : std_logic_vector(REGIONS-1 downto 0);
    signal frame_only_with_ending           : std_logic_vector(REGIONS-1 downto 0);
    signal masked_sof                       : std_logic_vector(REGIONS-1 downto 0);
    signal masked_eof                       : std_logic_vector(REGIONS-1 downto 0);
    signal regions_to_drop                  : std_logic_vector(REGIONS-1 downto 0);
    signal regions_to_hide                  : std_logic_vector(REGIONS-1 downto 0);
    signal hidden_regions_reg               : std_logic_vector(REGIONS-1 downto 0);
    signal dropped_regions_reg              : std_logic_vector(REGIONS-1 downto 0);
    signal need_to_drop_next_single_eof_reg : std_logic;
    signal next_single_eof_mask             : std_logic;
    signal start_of_processing              : std_logic;
    signal end_of_processing                : std_logic;
    signal need_to_process                  : std_logic;
    signal is_done                          : std_logic;
    signal is_masking                       : std_logic;
    signal highest_mask_index               : integer;
    
begin
    
    -- --------------------------------------------------------------------------
    --  MFB_PIPE instantiation
    -- --------------------------------------------------------------------------

    mfb_pipe_i : entity work.MFB_PIPE
    generic map (
        REGIONS     => REGIONS,
        REGION_SIZE => REGION_SIZE,
        BLOCK_SIZE  => BLOCK_SIZE,
        ITEM_WIDTH  => ITEM_WIDTH,
        META_WIDTH  => META_WIDTH,

        FAKE_PIPE   => not USE_PIPE,
        USE_DST_RDY => true
    )
    port map (
        CLK        => CLK,
        RESET      => RESET,

        RX_DATA    => RX_DATA,
        RX_META    => RX_META,
        RX_SOF     => RX_SOF,
        RX_EOF     => RX_EOF,
        RX_SOF_POS => RX_SOF_POS,
        RX_EOF_POS => RX_EOF_POS,
        RX_SRC_RDY => RX_SRC_RDY,
        RX_DST_RDY => RX_DST_RDY,

        TX_DATA    => pipe_tx_data,
        TX_META    => pipe_tx_meta,
        TX_SOF     => pipe_tx_sof,
        TX_EOF     => pipe_tx_eof,
        TX_SOF_POS => pipe_tx_sof_pos,
        TX_EOF_POS => pipe_tx_eof_pos,
        TX_SRC_RDY => pipe_tx_src_rdy,
        TX_DST_RDY => pipe_tx_dst_rdy
    );

    -- --------------------------------------------------------------------------
    --  FSM
    -- --------------------------------------------------------------------------

    state_update_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RESET = '1') then
                curr_state <= IDLE;
            else
                curr_state <= next_state;
            end if;
        end if;
    end process;

    next_state_logic_p : process (all)
    begin
        case curr_state is
            when IDLE =>
                next_state <= IDLE;

                if (pipe_tx_src_rdy = '1' and TX_DST_RDY = '1') then
                    if (need_to_process = '0') then
                        next_state <= DONE;
                    else
                        next_state <= MASKING;
                    end if;
                end if;
            when MASKING =>
                next_state <= MASKING;

                if (TX_DST_RDY = '1' and is_done = '1') then
                    next_state <= DONE;
                end if;
            when DONE =>
                next_state <= DONE;

                if (TX_DST_RDY = '1') then
                    if (pipe_tx_src_rdy = '1') then
                        if (need_to_process = '0') then
                            next_state <= DONE;
                        else
                            next_state <= MASKING;
                        end if;
                    else
                        next_state <= IDLE;
                    end if;
                end if;
            when others =>
                next_state <= IDLE;

                if (pipe_tx_src_rdy = '1' and TX_DST_RDY = '1') then
                    if (need_to_process = '0') then
                        next_state <= DONE;
                    else
                        next_state <= MASKING;
                    end if;
                end if;
        end case;
    end process;

    output_logic_p : process (all)
    begin
        case curr_state is
            when IDLE =>
                is_masking        <= '0';
                end_of_processing <= '0';
                TX_SRC_RDY        <= '0';
                pipe_tx_dst_rdy   <= TX_DST_RDY;

                if (pipe_tx_src_rdy = '1' and TX_DST_RDY = '1') then
                    end_of_processing <= '1';
                end if;
            when MASKING =>
                is_masking        <= '1';
                end_of_processing <= '0';
                TX_SRC_RDY        <= '1';
                pipe_tx_dst_rdy   <= '0';
            when DONE =>
                is_masking        <= '0';
                end_of_processing <= '0';
                TX_SRC_RDY        <= '1';
                pipe_tx_dst_rdy   <= TX_DST_RDY;

                if (pipe_tx_src_rdy = '1' and TX_DST_RDY = '1') then
                    end_of_processing <= '1';
                end if;
            when others =>
                is_masking        <= '0';
                end_of_processing <= '0';
                TX_SRC_RDY        <= '0';
                pipe_tx_dst_rdy   <= TX_DST_RDY;

                if (pipe_tx_src_rdy = '1' and TX_DST_RDY = '1') then
                    end_of_processing <= '1';
                end if;
        end case;
    end process;

    -- --------------------------------------------------------------------------
    --  Data registers
    -- --------------------------------------------------------------------------

    -- Stores the data word
    data_word_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (end_of_processing = '1') then
                data_reg    <= pipe_tx_data;
                meta_reg    <= pipe_tx_meta;
                sof_reg     <= pipe_tx_sof;
                eof_reg     <= pipe_tx_eof;
                sof_pos_reg <= pipe_tx_sof_pos;
                eof_pos_reg <= pipe_tx_eof_pos;
            end if;
        end if;
    end process;

    -- Indicates the start of processing a new data word
    start_of_processing_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (TX_DST_RDY = '1') then
                start_of_processing <= end_of_processing;
            end if;
        end if;
    end process;

    -- Stores information about already hidden regions
    hidden_regions_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (TX_DST_RDY = '1') then
                hidden_regions_reg <= regions_to_hide;                
            end if;
        end if;
    end process;

    regions_drop_g : if REGIONS > 1 generate

        -- Stores information about already dropped regions
        dropped_regions_reg_p : process (CLK)
        begin
            if (rising_edge(CLK)) then
                if (RESET = '1') then
                    dropped_regions_reg <= (others => '0');
                elsif (end_of_processing = '1') then
                    dropped_regions_reg <= regions_to_drop;
                elsif (TX_DST_RDY = '1' and is_masking = '1') then
                    dropped_regions_reg <= dropped_regions_reg or regions_to_drop;
                end if;
            end if;
        end process;

        -- Stores information that the next single EOF needs to be dropped
        need_to_drop_next_single_eof_reg_p : process (CLK)
        begin
            if (rising_edge(CLK)) then
                if (RESET = '1') then
                    need_to_drop_next_single_eof_reg <= '0';
                elsif (end_of_processing = '1') then
                    need_to_drop_next_single_eof_reg <= (or (dropped_regions_reg and frame_only_with_beginning)) or
                                                        (need_to_drop_next_single_eof_reg and not (or eof_reg));
                end if;
            end if;
        end process;

    else generate

        dropped_regions_reg              <= (others => '0');
        need_to_drop_next_single_eof_reg <= '0';

    end generate;

    -- --------------------------------------------------------------------------
    --  Masking logic
    -- --------------------------------------------------------------------------

    -- Logic vector to array of unsigned
    u_array_sof_pos <= slv_arr_to_u_arr(slv_array_downto_deser(sof_pos_reg, REGIONS, SOF_POS_WIDTH));
    u_array_eof_pos <= slv_arr_to_u_arr(slv_array_downto_deser(eof_pos_reg, REGIONS, EOF_POS_WIDTH));

    -- Masks a single EOF
    prev_mask(0) <= not next_single_eof_mask;

    frame_masking_logic_g : for r in 0 to REGIONS-1 generate
    
        -- Block to item conversion
        u_array_sof_pos_items(r) <= resize_right(u_array_sof_pos(r), EOF_POS_WIDTH);

        -- Indicates that the frame starts and ends in the same word
        whole_frame(r) <= '1' when (sof_reg(r) = '1' and eof_reg(r) = '1' and
                                   (u_array_sof_pos_items(r)) <= u_array_eof_pos(r)) else '0';

        -- Indicates that the last masked frame was not completely masked
        prev_mask(r+1) <= '1' when ((full_mask(r) = '0' and sof_reg(r) = '1' and whole_frame(r) = '0') or
                                    (prev_mask(r) = '1' and eof_reg(r) = '0')) else '0';

        -- Output SOF and EOF that have been modified based on the full mask
        masked_sof(r) <= '0' when ( full_mask(r) = '0')                                                 else sof_reg(r);
        masked_eof(r) <= '0' when ((full_mask(r) = '0' and whole_frame(r) = '1') or prev_mask(r) = '1') else eof_reg(r);

    end generate;

    -- Finds a frame with only the ending
    frame_only_with_ending_p : process (all)
    begin
        frame_only_with_ending <= (others => '0');
        for r in 0 to REGIONS-1 loop
            if (eof_reg(r) = '1') then
                if ((sof_reg(r) = '0') or
                    (sof_reg(r) = '1' and whole_frame(r) = '0'))
                then
                    frame_only_with_ending(r) <= '1';
                end if;
                exit;
            elsif (sof_reg(r) = '1') then
                exit;
            end if;
        end loop;
    end process;

    multi_regions_logic_g : if REGIONS > 1 generate

        -- Finds a frame with only the beginning
        frame_only_with_beginning_p : process (all)
        begin
            frame_only_with_beginning <= (others => '0');
            for r in REGIONS-1 downto 0 loop
                if (sof_reg(r) = '1') then
                    if ((eof_reg(r) = '0') or 
                        (eof_reg(r) = '1' and whole_frame(r) = '0'))
                    then
                        frame_only_with_beginning(r) <= '1';
                    end if;
                    exit;
                elsif (eof_reg(r) = '1') then
                    exit;
                end if;
            end loop;
        end process;

        -- Finds the index of the highest mask bit
        highest_mask_index_p : process (all)
        begin
            highest_mask_index <= REGIONS-1;
            for r in REGIONS-1 downto 0 loop
                if (TX_MASK(r) = '1') then
                    highest_mask_index <= r;
                    exit;
                end if;
            end loop;
        end process;

        -- Finds regions to drop
        regions_to_drop_p : process (all)
        begin
            regions_to_drop <= (others => '0');
            for r in 0 to REGIONS-1 loop
                if (r <= highest_mask_index) then
                    regions_to_drop(r) <= not TX_MASK(r);
                end if;
            end loop;
        end process;

        -- Finds regions to hide
        regions_to_hide_p : process (all)
        begin
            regions_to_hide <= (others => '0');
            for r in 0 to REGIONS-1 loop
                if (r > highest_mask_index) then
                    regions_to_hide(r) <= '1';
                end if;
            end loop;
        end process;

    else generate

        frame_only_with_beginning <= (others => '0');
        highest_mask_index        <= 0;
        regions_to_drop           <= (others => '0');
        regions_to_hide           <= not TX_MASK;

    end generate;

    -- Mask for next single EOF
    next_single_eof_mask <= '0' when ((start_of_processing = '0' or need_to_drop_next_single_eof_reg = '1') and
                                      (or frame_only_with_ending = '1')) else '1';

    -- Full mask based on hidden and dropped regions
    full_mask <= not (hidden_regions_reg or dropped_regions_reg);

    -- Indicates that there is no need to process the data word
    need_to_process <= (or (regions_to_hide and pipe_tx_sof));
    
    -- Indicates that there are not unread frames left in the data word
    is_done <= not (or (regions_to_hide and sof_reg));

    -- --------------------------------------------------------------------------
    --  MFB output
    -- --------------------------------------------------------------------------

    TX_DATA    <= data_reg;
    TX_META    <= meta_reg;
    TX_SOF     <= masked_sof;
    TX_EOF     <= masked_eof;
    TX_SOF_POS <= sof_pos_reg;
    TX_EOF_POS <= eof_pos_reg;

end architecture;
