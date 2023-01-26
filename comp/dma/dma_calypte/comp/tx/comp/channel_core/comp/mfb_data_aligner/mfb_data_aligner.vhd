-- mfb_data_aligner.vhd: input aligner which aligns incoming data to the specific block specified by
-- the ALIGN_BLOCK input
-- Copyright (c) 2022 CESNET z.s.p.o.
-- Author(s): Vladislav Valek  <xvalek14@vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-CLause

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.type_pack.all;
use work.math_pack.all;

-- This component aligns the input data stream on a MFB block specified by the `ALIGN_BLOCK` input.
-- It's function is simlar to the :ref:`rx_dma_input_buffer` with the exception, that the block to
-- which the input frame is aligned, is dynamically set.
entity MFB_DATA_ALIGNER is
    generic (
        -- =========================================================================================
        -- MFB bus parameters
        --
        -- The number of regions is always set to 1
        -- =========================================================================================
        REGION_SIZE : integer := 8;
        BLOCK_SIZE  : integer := 4;
        ITEM_WIDTH  : integer := 8;

        META_WIDTH : integer := 24
        );
    port (
        CLK : in std_logic;
        RST : in std_logic;

        -- =========================================================================================
        -- Input MFB interface
        -- =========================================================================================
        -- index of a block in an output word to which the data from the input should be aligned,
        -- valid with SOF
        ALIGN_BLOCK : in std_logic_vector(log2(REGION_SIZE) -1 downto 0);

        RX_MFB_DATA    : in  std_logic_vector(REGION_SIZE*BLOCK_SIZE*ITEM_WIDTH-1 downto 0);
        RX_MFB_META    : in  std_logic_vector(META_WIDTH -1 downto 0);
        RX_MFB_SOF     : in  std_logic;
        RX_MFB_EOF     : in  std_logic;
        RX_MFB_SOF_POS : in  std_logic_vector(max(1, log2(REGION_SIZE))-1 downto 0);
        RX_MFB_EOF_POS : in  std_logic_vector(max(1, log2(REGION_SIZE*BLOCK_SIZE))-1 downto 0);
        RX_MFB_SRC_RDY : in  std_logic;
        RX_MFB_DST_RDY : out std_logic;

        -- =========================================================================================
        -- Output MFB interface
        -- =========================================================================================
        TX_MFB_DATA    : out std_logic_vector(REGION_SIZE*BLOCK_SIZE*ITEM_WIDTH-1 downto 0);
        TX_MFB_META    : out std_logic_vector(META_WIDTH -1 downto 0) := (others => '0');
        TX_MFB_SOF     : out std_logic;
        TX_MFB_EOF     : out std_logic;
        TX_MFB_SOF_POS : out std_logic_vector(max(1, log2(REGION_SIZE))-1 downto 0);
        TX_MFB_EOF_POS : out std_logic_vector(max(1, log2(REGION_SIZE*BLOCK_SIZE))-1 downto 0);
        TX_MFB_SRC_RDY : out std_logic;
        TX_MFB_DST_RDY : in  std_logic
        );
end entity;

architecture FULL of MFB_DATA_ALIGNER is

    --=============================================================================================================
    -- Packet divider signals
    --=============================================================================================================
    type pkt_divide_state_t is (PKT_PASS, PKT_DIVIDE);
    signal pkt_divide_pst : pkt_divide_state_t := PKT_PASS;
    signal pkt_divide_nst : pkt_divide_state_t := PKT_PASS;

    signal div_tx_align_block : std_logic_vector(ALIGN_BLOCK'range);
    signal div_tx_data        : std_logic_vector(RX_MFB_DATA'range);
    signal div_tx_meta        : std_logic_vector(RX_MFB_META'range);
    signal div_tx_sof         : std_logic;
    signal div_tx_eof         : std_logic;
    signal div_tx_sof_pos     : std_logic_vector(RX_MFB_SOF_POS'range);
    signal div_tx_eof_pos     : std_logic_vector(RX_MFB_EOF_POS'range);
    signal div_tx_src_rdy     : std_logic;
    signal div_tx_dst_rdy     : std_logic;

    --=============================================================================================================
    -- Skid buffer signals
    --=============================================================================================================
    signal sb_rx_align_block : slv_array_t(1 downto 0)(ALIGN_BLOCK'range);
    signal sb_rx_data        : slv_array_t(1 downto 0)(RX_MFB_DATA'range);
    signal sb_rx_meta        : slv_array_t(1 downto 0)(RX_MFB_META'range);
    signal sb_rx_sof         : std_logic_vector(1 downto 0);
    signal sb_rx_eof         : std_logic_vector(1 downto 0);
    signal sb_rx_sof_pos     : slv_array_t(1 downto 0)(RX_MFB_SOF_POS'range);
    signal sb_rx_eof_pos     : slv_array_t(1 downto 0)(RX_MFB_EOF_POS'range);
    signal sb_rx_src_rdy     : std_logic_vector(1 downto 0);

    signal sb_tx_align_block : std_logic_vector(ALIGN_BLOCK'range);
    signal sb_tx_data        : std_logic_vector(RX_MFB_DATA'range);
    signal sb_tx_meta        : std_logic_vector(RX_MFB_META'range);
    signal sb_tx_sof         : std_logic;
    signal sb_tx_eof         : std_logic;
    signal sb_tx_sof_pos     : std_logic_vector(RX_MFB_SOF_POS'range);
    signal sb_tx_eof_pos     : std_logic_vector(RX_MFB_EOF_POS'range);
    signal sb_tx_src_rdy     : std_logic;
    signal sb_tx_dst_rdy     : std_logic;

    signal sb_mfb_eof_succ     : std_logic;
    signal sb_mfb_eof_pos_succ : std_logic_vector(RX_MFB_EOF_POS'range);
    signal sb_buff_full        : std_logic;
    signal sb_1buff_tx_dst_rdy : std_logic;

    --=============================================================================================================
    -- Shifting FSM signals
    --=============================================================================================================
    type pkt_shift_state_type is (PKT_START_DETECT, PKT_NO_SHIFT, PKT_MIDDLE, PKT_END, PKT_START_BREAK);
    signal sh_fsm_pst : pkt_shift_state_type := PKT_START_DETECT;
    signal sh_fsm_nst : pkt_shift_state_type := PKT_START_DETECT;

    signal sh_fsm_tx_sof     : std_logic;
    signal sh_fsm_tx_eof     : std_logic;
    signal sh_fsm_tx_eof_pos : std_logic_vector(TX_MFB_EOF_POS'range);
    signal sh_fsm_tx_src_rdy : std_logic;
    signal sh_fsm_rx_dst_rdy : std_logic;

    -- registers and its inputs which stores SOF-valid packet values for the calculation of shift_sel value for
    -- the rest of the packet
    signal sh_fsm_sof_pos_curr       : std_logic_vector(RX_MFB_SOF_POS'range);
    signal sh_fsm_sof_pos_stored     : std_logic_vector(RX_MFB_SOF_POS'range);
    signal sh_fsm_align_block_curr   : std_logic_vector(ALIGN_BLOCK'range);
    signal sh_fsm_align_block_stored : std_logic_vector(ALIGN_BLOCK'range);

    signal shift_sel         : unsigned(log2(REGION_SIZE) downto 0);
    signal bshifter_data_out : std_logic_vector((2*TX_MFB_DATA'length) - 1 downto 0);

    -- attribute mark_debug : string;

    -- attribute mark_debug of sb_rx_data    : signal is "true";
    -- attribute mark_debug of sb_rx_meta    : signal is "true";
    -- attribute mark_debug of sb_rx_sof     : signal is "true";
    -- attribute mark_debug of sb_rx_eof     : signal is "true";
    -- attribute mark_debug of sb_rx_sof_pos : signal is "true";
    -- attribute mark_debug of sb_rx_eof_pos : signal is "true";
    -- attribute mark_debug of sb_rx_src_rdy : signal is "true";
begin

    --=============================================================================================================
    -- PACKET DIVIDER
    --=============================================================================================================
    pkt_divider_state_reg_p : process (CLK) is
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                pkt_divide_pst <= PKT_PASS;
            elsif (div_tx_dst_rdy = '1') then
                pkt_divide_pst <= pkt_divide_nst;
            end if;
        end if;
    end process;

    pkt_divide_nst_logic_p : process (all) is
        variable sof_pos_un  : unsigned(RX_MFB_SOF_POS'range);
        variable eof_blk_pos : unsigned(RX_MFB_SOF_POS'range);
    begin

        pkt_divide_nst <= pkt_divide_pst;

        case pkt_divide_pst is
            when PKT_PASS =>
                sof_pos_un  := unsigned(RX_MFB_SOF_POS);
                -- select only EOF's block position from the next
                eof_blk_pos := unsigned(RX_MFB_EOF_POS(RX_MFB_EOF_POS'high downto (RX_MFB_EOF_POS'high - (RX_MFB_SOF_POS'length - 1))));

                if (
                    RX_MFB_SOF = '1'
                    and RX_MFB_EOF = '1'
                    and RX_MFB_SRC_RDY = '1'
                    and sof_pos_un > eof_blk_pos
                    ) then

                    pkt_divide_nst <= PKT_DIVIDE;
                end if;

            when PKT_DIVIDE =>
                pkt_divide_nst <= PKT_PASS;

        end case;
    end process;

    pkt_divide_out_logic_p : process (all) is
        variable sof_pos_un  : unsigned(RX_MFB_SOF_POS'range);
        variable eof_blk_pos : unsigned(RX_MFB_SOF_POS'range);
    begin

        div_tx_align_block <= ALIGN_BLOCK;
        div_tx_data        <= RX_MFB_DATA;
        div_tx_meta        <= RX_MFB_META;
        div_tx_sof         <= RX_MFB_SOF;
        div_tx_eof         <= RX_MFB_EOF;
        div_tx_sof_pos     <= RX_MFB_SOF_POS;
        div_tx_eof_pos     <= RX_MFB_EOF_POS;
        div_tx_src_rdy     <= RX_MFB_SRC_RDY;
        RX_MFB_DST_RDY     <= div_tx_dst_rdy;

        case pkt_divide_pst is
            -- passes the incoming packets to its output
            when PKT_PASS =>

                sof_pos_un  := unsigned(RX_MFB_SOF_POS);
                -- select only EOF's block position from the next
                eof_blk_pos := unsigned(RX_MFB_EOF_POS(RX_MFB_EOF_POS'high downto (RX_MFB_EOF_POS'high - (RX_MFB_SOF_POS'length - 1))));

                -- there are two packets occuring in a current word so they need to be divided
                -- into two words, thw SOF value is cleared for the next clock cycle
                -- NOTE: In order to perform the division of the incoming packets, the position of the SOF
                -- needs to be higher than the block position of the EOF. Otherwise there is a whole packet
                -- inside a word in which case it should not be divided.
                if (
                    RX_MFB_SOF = '1'
                    and RX_MFB_EOF = '1'
                    and RX_MFB_SRC_RDY = '1'
                    and sof_pos_un > eof_blk_pos
                    ) then

                    div_tx_sof     <= '0';
                    RX_MFB_DST_RDY <= '0';
                end if;

            -- the input is stopped so two packets can be divided, the EOF value is cleared for the next
            -- clock cycle
            when PKT_DIVIDE =>
                div_tx_sof <= '1';
                div_tx_eof <= '0';
        end case;
    end process;

    --=============================================================================================================
    -- SKID BUFFER
    --=============================================================================================================
    -- handles the reception of packets into two registers from which the
    -- barrel shifter is connected
    skid_buffer_p : process (CLK) is
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then

                sb_rx_sof     <= (others => '0');
                sb_rx_eof     <= (others => '0');
                sb_rx_src_rdy <= (others => '0');

            else

                if (div_tx_dst_rdy = '1') then

                    sb_rx_align_block(0) <= div_tx_align_block;
                    sb_rx_data(0)        <= div_tx_data;
                    sb_rx_meta(0)        <= div_tx_meta;
                    sb_rx_sof(0)         <= div_tx_sof;
                    sb_rx_eof(0)         <= div_tx_eof;
                    sb_rx_sof_pos(0)     <= div_tx_sof_pos;
                    sb_rx_eof_pos(0)     <= div_tx_eof_pos;
                    sb_rx_src_rdy(0)     <= div_tx_src_rdy;

                end if;

                if (sb_1buff_tx_dst_rdy = '1') then

                    sb_rx_align_block(1) <= sb_rx_align_block(0);
                    sb_rx_data(1)        <= sb_rx_data(0);
                    sb_rx_meta(1)        <= sb_rx_meta(0);
                    sb_rx_sof(1)         <= sb_rx_sof(0);
                    sb_rx_eof(1)         <= sb_rx_eof(0);
                    sb_rx_sof_pos(1)     <= sb_rx_sof_pos(0);
                    sb_rx_eof_pos(1)     <= sb_rx_eof_pos(0);
                    sb_rx_src_rdy(1)     <= sb_rx_src_rdy(0);

                end if;
            end if;
        end if;
    end process;

    -- connection of DST_RDY signal from the second buffer of the skid buffer
    sb_1buff_tx_dst_rdy <= sb_tx_dst_rdy or (not sb_rx_src_rdy(1));
    -- connection of the buffers DST_RDY signal to the previous component, that is packet divider
    div_tx_dst_rdy      <= sb_1buff_tx_dst_rdy or (not sb_rx_src_rdy(0));

    --=============================================================================================================
    -- Simple interconnect between Skid buffer and Shifting FSM
    --=============================================================================================================
    sb_tx_align_block <= sb_rx_align_block(1);
    sb_tx_data        <= sb_rx_data(1);
    sb_tx_meta        <= sb_rx_meta(1);
    sb_tx_sof         <= sb_rx_sof(1);
    sb_tx_eof         <= sb_rx_eof(1);
    sb_tx_sof_pos     <= sb_rx_sof_pos(1);
    sb_tx_eof_pos     <= sb_rx_eof_pos(1);
    sb_tx_src_rdy     <= sb_rx_src_rdy(1);
    sb_tx_dst_rdy     <= sh_fsm_rx_dst_rdy;

    -- there is a need for these two signals because I have to know that EOF is coming in advance
    sb_mfb_eof_succ     <= sb_rx_eof(0);
    sb_mfb_eof_pos_succ <= sb_rx_eof_pos(0);
    sb_buff_full        <= and sb_rx_src_rdy;

    --=============================================================================================================
    -- SHIFTING FSM WITH BARREL SHIFTER
    --=============================================================================================================
    fsm_pst_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then

                sh_fsm_pst                <= PKT_START_DETECT;
                sh_fsm_sof_pos_stored     <= (others => '0');
                sh_fsm_align_block_stored <= (others => '0');

            elsif (TX_MFB_DST_RDY = '1') then

                sh_fsm_pst                <= sh_fsm_nst;
                sh_fsm_sof_pos_stored     <= sh_fsm_sof_pos_curr;
                sh_fsm_align_block_stored <= sh_fsm_align_block_curr;

            end if;
        end if;
    end process;

    fsm_nst_logic_p : process (all)
        variable sof_pos_un  : unsigned(RX_MFB_SOF_POS'high downto 0);
        variable blk_shift   : unsigned(RX_MFB_SOF_POS'high + 1 downto 0);
        variable eof_blk_pos : unsigned(RX_MFB_SOF_POS'range);
    begin

        sh_fsm_nst <= sh_fsm_pst;

        sof_pos_un  := unsigned(sb_tx_sof_pos);
        -- select only EOF's block position from the next
        eof_blk_pos := unsigned(sb_mfb_eof_pos_succ(sb_mfb_eof_pos_succ'high downto (sb_mfb_eof_pos_succ'high - (RX_MFB_SOF_POS'length - 1))));

        case sh_fsm_pst is

            -- the FSM wait for the detection of the SOF_POS in the Skid buffer
            when PKT_START_DETECT =>

                if (sb_tx_src_rdy = '1' and sb_tx_sof = '1') then

                    -- the packet needs to be shifted to the upper index block than in which it currently occurs.
                    -- The state machine stops the transmission because some data in the current word are not send
                    -- and need to be in the next cycle.
                    if (sof_pos_un < ('0' & unsigned(sb_tx_align_block))) then

                        eof_blk_pos := unsigned(sb_tx_eof_pos(sb_tx_eof_pos'high downto (sb_tx_eof_pos'high - (RX_MFB_SOF_POS'length - 1))));
                        -- calculate the amount of block by which the packet will be shifted
                        blk_shift   := ('0' & unsigned (sb_tx_align_block)) - sof_pos_un;

                        -- if after the shift of small packet the EOF still remains in the word,
                        -- then remain in the current state
                        if (sb_tx_eof = '1' and (('0' & eof_blk_pos) + blk_shift < REGION_SIZE)) then
                            sh_fsm_nst <= PKT_START_DETECT;
                        else
                            sh_fsm_nst <= PKT_START_BREAK;
                        end if;

                    -- no shift of the packet is needed, it already begins on the desired position
                    elsif (sof_pos_un = ('0' & unsigned(sb_tx_align_block))) then

                        -- also the EOF occurs in the current word, no transition to the next state is needed
                        if (sb_tx_eof = '1') then

                            sh_fsm_nst <= PKT_START_DETECT;

                        -- the next state consideres the situation when the packet ends or continues in the next
                        -- word but the waiting for this is controlled in the PKT_NO_SHIFT state so I dont have to
                        -- control if the Skid buffer is full
                        else
                            sh_fsm_nst <= PKT_NO_SHIFT;
                        end if;

                    -- the packet needs to be shifted to the lower index block than in which it currently occurs
                    else

                        -- if buffer is full but no EOF occurs in a last register, there is not a
                        -- small packet in a current word
                        if (sb_buff_full = '1' and sb_tx_eof = '0') then

                            blk_shift := sof_pos_un - ('0' & unsigned (sb_tx_align_block));

                            -- In case EOF accurs in the next word: when packet is shifted, its whole content
                            -- occurs in the current word and no transition is needed
                            if (sb_mfb_eof_succ = '1' and eof_blk_pos < blk_shift) then

                                sh_fsm_nst <= PKT_START_DETECT;

                            -- In case EOF occurs in the next word: When packet is shifted, its whole content does
                            -- not occur in the current word so the additional processing of the EOF is needed.
                            elsif (sb_mfb_eof_succ = '1' and eof_blk_pos >= blk_shift) then

                                sh_fsm_nst <= PKT_END;

                            else
                                sh_fsm_nst <= PKT_MIDDLE;
                            end if;

                        -- there is a small packet in a current word which is only shifted to the
                        -- specified ALIGN_BLOCK position
                        elsif (sb_tx_eof = '1') then

                            sh_fsm_nst <= PKT_START_DETECT;

                        end if;
                    end if;
                end if;

            when PKT_START_BREAK =>

                if (sb_buff_full = '1' and sb_tx_eof = '0') then

                    if (sb_mfb_eof_succ = '1') then

                        sof_pos_un  := unsigned(sh_fsm_sof_pos_stored);
                        eof_blk_pos := unsigned(sb_mfb_eof_pos_succ(sb_mfb_eof_pos_succ'high downto (sb_mfb_eof_pos_succ'high - (RX_MFB_SOF_POS'length - 1))));

                        -- if a current shift causes the EOF (which is in the LATER word in the skid
                        -- buffer) to be shifted to the current output word, then no separate
                        -- sending of the packet's ending is needed
                        if (eof_blk_pos < (sof_pos_un - unsigned(sb_tx_align_block))) then
                            sh_fsm_nst <= PKT_START_DETECT;
                        else
                            sh_fsm_nst <= PKT_END;
                        end if;
                    else
                        sh_fsm_nst <= PKT_MIDDLE;
                    end if;

                -- if there is a small packet in a current word, simply send a rest of it and
                -- proceed to the beginning state
                elsif (sb_tx_eof = '1') then
                    sh_fsm_nst <= PKT_START_DETECT;
                end if;

            when PKT_NO_SHIFT =>

                if (sb_tx_eof = '1' and sb_tx_src_rdy = '1') then
                    sh_fsm_nst <= PKT_START_DETECT;
                end if;

            when PKT_MIDDLE =>

                if (sb_buff_full = '1' and sb_mfb_eof_succ = '1') then

                    if (eof_blk_pos < shift_sel((shift_sel'high - 1) downto 0)) then
                        sh_fsm_nst <= PKT_START_DETECT;
                    else
                        sh_fsm_nst <= PKT_END;
                    end if;
                end if;

            when PKT_END =>
                sh_fsm_nst <= PKT_START_DETECT;
        end case;
    end process;

    fsm_output_logic_p : process (all)
        variable sof_pos_un  : unsigned(RX_MFB_SOF_POS'range);
        variable blk_shift   : unsigned(RX_MFB_SOF_POS'high + 1 downto 0);
        variable eof_blk_pos : unsigned(RX_MFB_SOF_POS'range);
    begin

        sh_fsm_tx_sof     <= '0';
        sh_fsm_tx_eof     <= '0';
        sh_fsm_tx_eof_pos <= (others => '0');
        sh_fsm_tx_src_rdy <= '0';
        sh_fsm_rx_dst_rdy <= '0';

        shift_sel               <= (others => '0');
        sh_fsm_sof_pos_curr     <= sh_fsm_sof_pos_stored;
        sh_fsm_align_block_curr <= sh_fsm_align_block_stored;

        case sh_fsm_pst is

            when PKT_START_DETECT =>

                sh_fsm_sof_pos_curr <= sb_tx_sof_pos;

                sh_fsm_rx_dst_rdy <= TX_MFB_DST_RDY;

                if (sb_tx_src_rdy = '1' and sb_tx_sof = '1') then

                    sh_fsm_align_block_curr <= sb_tx_align_block;

                    sof_pos_un := unsigned(sb_tx_sof_pos);
                    shift_sel  <= ('0' & sof_pos_un) - ('0' & unsigned(sb_tx_align_block));

                    -- packet can be sent to the output but the Skid buffer needs to be stopped because there still
                    -- some beginning of the packet left
                    if (sof_pos_un < ('0' & unsigned(sb_tx_align_block))) then

                        sh_fsm_tx_sof     <= '1';
                        sh_fsm_tx_src_rdy <= '1';
                        sh_fsm_rx_dst_rdy <= '0';

                        eof_blk_pos := unsigned(sb_tx_eof_pos(sb_tx_eof_pos'high downto (sb_tx_eof_pos'high - (RX_MFB_SOF_POS'length - 1))));

                        blk_shift := ('0' & unsigned (sb_tx_align_block)) - sof_pos_un;

                        if (sb_tx_eof = '1' and (('0' & eof_blk_pos) + blk_shift < REGION_SIZE)) then

                            sh_fsm_tx_eof     <= '1';
                            sh_fsm_rx_dst_rdy <= TX_MFB_DST_RDY;

                            sh_fsm_tx_eof_pos(sh_fsm_tx_eof_pos'high downto (sh_fsm_tx_eof_pos'high - (RX_MFB_SOF_POS'length - 1)))
                                <= std_logic_vector(eof_blk_pos + blk_shift(blk_shift'high -1 downto 0));
                            sh_fsm_tx_eof_pos((sh_fsm_tx_eof_pos'high - RX_MFB_SOF_POS'length) downto 0)
                                <= sb_tx_eof_pos((sb_tx_eof_pos'high - RX_MFB_SOF_POS'length) downto 0);
                        end if;

                    -- packet is free to be sent to the output without stopping the Skid buffer
                    elsif (sof_pos_un = ('0' & unsigned(sb_tx_align_block))) then

                        sh_fsm_tx_sof     <= '1';
                        sh_fsm_tx_src_rdy <= '1';

                        -- if FSM is ready to send data then it should respect the TX_MFB_DST_RDY signal this
                        -- behavior is maintained throughoutthe whole design
                        sh_fsm_rx_dst_rdy <= TX_MFB_DST_RDY;

                        if (sb_tx_eof = '1') then
                            sh_fsm_tx_eof <= '1';
                            sh_fsm_tx_eof_pos <= sb_tx_eof_pos;
                        end if;

                    -- packet cannot be sent to the output until two valid words occur in the Skid buffer. If
                    -- second buffered word is invalid, the data shift causes the invalid data to occur on the
                    -- output. These data cannot be considered as valid.
                    else

                        sh_fsm_rx_dst_rdy <= '0';

                        if (sb_buff_full = '1' and sb_tx_eof = '0') then

                            sh_fsm_tx_sof     <= '1';
                            sh_fsm_tx_src_rdy <= '1';
                            sh_fsm_rx_dst_rdy <= TX_MFB_DST_RDY;

                            eof_blk_pos := unsigned(sb_mfb_eof_pos_succ(sb_mfb_eof_pos_succ'high downto (sb_mfb_eof_pos_succ'high - (RX_MFB_SOF_POS'length - 1))));
                            blk_shift := sof_pos_un - ('0' & unsigned (sb_tx_align_block));

                            if (sb_mfb_eof_succ = '1' and eof_blk_pos < blk_shift) then

                                sh_fsm_tx_eof <= '1';

                                sh_fsm_tx_eof_pos(sh_fsm_tx_eof_pos'high downto (sh_fsm_tx_eof_pos'high - (RX_MFB_SOF_POS'length - 1)))
                                    <= std_logic_vector(eof_blk_pos - blk_shift(blk_shift'high -1 downto 0));
                                sh_fsm_tx_eof_pos((sh_fsm_tx_eof_pos'high - RX_MFB_SOF_POS'length) downto 0)
                                    <= sb_mfb_eof_pos_succ((sb_mfb_eof_pos_succ'high - RX_MFB_SOF_POS'length) downto 0);
                            end if;

                        elsif (sb_tx_eof = '1') then

                            sh_fsm_tx_sof     <= '1';
                            sh_fsm_tx_eof     <= '1';
                            sh_fsm_tx_src_rdy <= '1';
                            sh_fsm_rx_dst_rdy <= TX_MFB_DST_RDY;

                            eof_blk_pos := unsigned(sb_tx_eof_pos(sb_tx_eof_pos'high downto (sb_tx_eof_pos'high - (RX_MFB_SOF_POS'length - 1))));
                            blk_shift := sof_pos_un - ('0' & unsigned (sb_tx_align_block));

                            sh_fsm_tx_eof_pos(sh_fsm_tx_eof_pos'high downto (sh_fsm_tx_eof_pos'high - (RX_MFB_SOF_POS'length - 1)))
                                <= std_logic_vector(eof_blk_pos - blk_shift(blk_shift'high -1 downto 0));
                            sh_fsm_tx_eof_pos((sh_fsm_tx_eof_pos'high - RX_MFB_SOF_POS'length) downto 0)
                                <= sb_tx_eof_pos((sb_tx_eof_pos'high - RX_MFB_SOF_POS'length) downto 0);

                        end if;
                    end if;
                end if;

            -- Although the SOF has already been propagated to the outpu, there are still some unread data in
            -- a current word
            when PKT_START_BREAK =>

                -- NOTE: Here could possibly be sb_tx_sof_pos because the skid buffer is stopped
                sof_pos_un := unsigned(sh_fsm_sof_pos_stored);
                shift_sel  <= (('0' & sof_pos_un) - ('0' & unsigned(sb_tx_align_block))) mod REGION_SIZE;

                sh_fsm_rx_dst_rdy <= '0';

                if (sb_buff_full = '1' and sb_tx_eof = '0') then

                    eof_blk_pos := unsigned(sb_mfb_eof_pos_succ(sb_mfb_eof_pos_succ'high downto (sb_mfb_eof_pos_succ'high - (RX_MFB_SOF_POS'length - 1))));

                    if (
                        sb_mfb_eof_succ = '1'
                        and eof_blk_pos < (sof_pos_un - unsigned(sb_tx_align_block))
                        ) then

                        sh_fsm_tx_eof <= '1';

                        sh_fsm_tx_eof_pos(sh_fsm_tx_eof_pos'high downto (sh_fsm_tx_eof_pos'high - (RX_MFB_SOF_POS'length - 1)))
                            <= std_logic_vector(eof_blk_pos - (sof_pos_un - unsigned(sb_tx_align_block)));
                        sh_fsm_tx_eof_pos((sh_fsm_tx_eof_pos'high - RX_MFB_SOF_POS'length) downto 0)
                            <= sb_mfb_eof_pos_succ((sb_mfb_eof_pos_succ'high - RX_MFB_SOF_POS'length) downto 0);
                    end if;

                    sh_fsm_tx_src_rdy <= '1';
                    sh_fsm_rx_dst_rdy <= TX_MFB_DST_RDY;

                elsif (sb_tx_eof = '1') then

                    sh_fsm_tx_eof     <= '1';
                    sh_fsm_tx_src_rdy <= '1';
                    sh_fsm_rx_dst_rdy <= TX_MFB_DST_RDY;

                    eof_blk_pos := unsigned(sb_tx_eof_pos(sb_tx_eof_pos'high downto (sb_tx_eof_pos'high - (RX_MFB_SOF_POS'length - 1))));

                    sh_fsm_tx_eof_pos(sh_fsm_tx_eof_pos'high downto (sh_fsm_tx_eof_pos'high - (RX_MFB_SOF_POS'length - 1)))
                        <= std_logic_vector(eof_blk_pos - (sof_pos_un - unsigned(sb_tx_align_block)));
                    sh_fsm_tx_eof_pos((sh_fsm_tx_eof_pos'high - RX_MFB_SOF_POS'length) downto 0)
                        <= sb_tx_eof_pos((sb_tx_eof_pos'high - RX_MFB_SOF_POS'length) downto 0);
                end if;

            -- special state where no shift of output data is needed and they are simply passed to the output
            when PKT_NO_SHIFT =>

                sh_fsm_tx_src_rdy <= sb_tx_src_rdy;
                sh_fsm_rx_dst_rdy <= TX_MFB_DST_RDY;

                -- when EOF occurs then move to the beginning state
                if (sb_tx_eof = '1' and sb_tx_src_rdy = '1') then

                    sh_fsm_tx_eof     <= '1';
                    sh_fsm_tx_eof_pos <= sb_tx_eof_pos;

                end if;

            -- state that is most used which is in the middle of a packet
            when PKT_MIDDLE =>

                -- shift select is calculated using the SOF_VALUE stored from time when packet arrived
                sof_pos_un := unsigned(sh_fsm_sof_pos_stored);
                shift_sel  <= (('0' & sof_pos_un) - ('0' & unsigned(sh_fsm_align_block_stored))) mod REGION_SIZE;

                sh_fsm_rx_dst_rdy <= '0';

                if (sb_buff_full = '1') then

                    -- this variable points to a block in which an EOF of a packet is located
                    eof_blk_pos := unsigned(sb_mfb_eof_pos_succ(sb_mfb_eof_pos_succ'high downto (sb_mfb_eof_pos_succ'high - (RX_MFB_SOF_POS'length - 1))));

                    -- one exception to the behavior in the middle of a packet is the situation when the EOF of the
                    -- packet occurs and current shift causes its EOF to appear in the current word
                    if (sb_mfb_eof_succ = '1' and (eof_blk_pos < shift_sel((shift_sel'high - 1) downto 0))) then

                        sh_fsm_tx_eof <= '1';

                        -- calculation of the new value of EOF_POS which should be propagated to the output, the EOF_POS is
                        -- calculated using the **next word** in the Skid buffer
                        sh_fsm_tx_eof_pos(sh_fsm_tx_eof_pos'high downto (sh_fsm_tx_eof_pos'high - (RX_MFB_SOF_POS'length - 1)))
                            <= std_logic_vector(eof_blk_pos - shift_sel((shift_sel'high - 1) downto 0));
                        sh_fsm_tx_eof_pos((sh_fsm_tx_eof_pos'high - RX_MFB_SOF_POS'length) downto 0)
                            <= sb_mfb_eof_pos_succ((sb_mfb_eof_pos_succ'high - RX_MFB_SOF_POS'length) downto 0);

                    end if;

                    sh_fsm_tx_src_rdy <= '1';
                    sh_fsm_rx_dst_rdy <= TX_MFB_DST_RDY;

                end if;

            -- sending the rest of a packet ending
            when PKT_END =>

                sof_pos_un := unsigned(sh_fsm_sof_pos_stored);
                shift_sel  <= (('0' & sof_pos_un) - ('0' & unsigned(sh_fsm_align_block_stored))) mod REGION_SIZE;

                sh_fsm_tx_eof <= '1';
                -- redefining this variable because I need to read the EOF_POS value in the current
                -- word, not in the previous one as previously
                eof_blk_pos   := unsigned(sb_tx_eof_pos(sb_tx_eof_pos'high downto (sb_tx_eof_pos'high - (RX_MFB_SOF_POS'length - 1))));

                -- calculation of the new value of EOF_POS which should be propagated to the output, the EOF_POS is
                -- calculated using the **current word** on the Skid buffer output
                sh_fsm_tx_eof_pos(sh_fsm_tx_eof_pos'high downto (sh_fsm_tx_eof_pos'high - (RX_MFB_SOF_POS'length - 1)))
                    <= std_logic_vector(eof_blk_pos - shift_sel((shift_sel'high - 1) downto 0));
                sh_fsm_tx_eof_pos((sh_fsm_tx_eof_pos'high - RX_MFB_SOF_POS'length) downto 0)
                    <= sb_tx_eof_pos((sb_tx_eof_pos'high - RX_MFB_SOF_POS'length) downto 0);

                sh_fsm_tx_src_rdy <= '1';
                sh_fsm_rx_dst_rdy <= TX_MFB_DST_RDY;

        end case;
    end process;

    data_out_shifter_i : entity work.BARREL_SHIFTER_GEN
        generic map (
            BLOCKS     => 2*REGION_SIZE,
            BLOCK_SIZE => BLOCK_SIZE*ITEM_WIDTH,
            SHIFT_LEFT => FALSE)
        port map (
            DATA_IN  => sb_rx_data(0) & sb_rx_data(1),
            DATA_OUT => bshifter_data_out,
            SEL      => std_logic_vector(shift_sel));

    TX_MFB_SOF_POS <= sh_fsm_align_block_stored;

    output_register_p : process (CLK) is
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then

                TX_MFB_DATA    <= (others => '0');
                TX_MFB_META    <= (others => '0');
                TX_MFB_EOF_POS <= (others => '0');
                TX_MFB_SOF     <= '0';
                TX_MFB_EOF     <= '0';
                TX_MFB_SRC_RDY <= '0';

            elsif (TX_MFB_DST_RDY = '1') then

                TX_MFB_DATA    <= bshifter_data_out(TX_MFB_DATA'range);
                TX_MFB_META    <= sb_tx_meta;
                TX_MFB_EOF_POS <= sh_fsm_tx_eof_pos;
                TX_MFB_SOF     <= sh_fsm_tx_sof;
                TX_MFB_EOF     <= sh_fsm_tx_eof;
                TX_MFB_SRC_RDY <= sh_fsm_tx_src_rdy;

            end if;
        end if;
    end process;
end architecture;
