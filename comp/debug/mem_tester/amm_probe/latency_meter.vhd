-- latency_meter.vhd: Component for measuring latency 
-- Copyright (C) 2021 CESNET z. s. p. o.
-- Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.math_pack.all;
use work.type_pack.all;

-- TODO: 
--  Ticks OVF do not work in HW
--  Add ticks sum ovf 

entity LATENCY_METER is
generic (
    -- Width of tick counters for measuring latency
    -- If latency is larger, TICKS_OVF will be asserted
    TICKS_WIDTH                     : integer := 8;
    SUM_WIDTH                       : integer := 32;
    -- Number of tick counters (it limits how much request can run in parallel)
    -- If parallel requests count exceed this value, COUNTER_OVF is asserted
    COUNTERS_CNT                    : integer := 50
);
port(
    -- Base
    CLK                             : in std_logic;
    RST                             : in std_logic;

    -- Measured input
    READ_REQ                        : in std_logic;
    READ_RESP                       : in std_logic;

    -- Output results
    -- Sum of all the ticks
    SUM_TICKS                       : out std_logic_vector(SUM_WIDTH - 1 downto 0);
    MIN_TICKS                       : out std_logic_vector(TICKS_WIDTH - 1 downto 0);
    MAX_TICKS                       : out std_logic_vector(TICKS_WIDTH - 1 downto 0);

    -- Error detection
    TICKS_OVF                       : out std_logic; 
    COUNTERS_OVF                    : out std_logic
);
end entity;

architecture FULL of LATENCY_METER is

    ---------------
    -- Constants --
    ---------------
    constant INDEX_CNTERS_LIM       : std_logic_vector(log2(COUNTERS_CNT) - 1 downto 0)
        := std_logic_vector(to_unsigned(COUNTERS_CNT - 1, log2(COUNTERS_CNT)));
    constant TICKS_CNTERS_LIM       : std_logic_vector(TICKS_WIDTH - 1 downto 0) := (others => '1');

    -------------
    -- Signals --
    -------------
    -- Cyclic pool of counters to measure ticks of multiple parallel requests
    signal tick_cnts                : slv_array_t(COUNTERS_CNT - 1 downto 0)(TICKS_WIDTH - 1 downto 0);
    signal tick_cnts_en             : std_logic_vector(COUNTERS_CNT - 1 downto 0);
    signal tick_cnts_en_set         : std_logic_vector(COUNTERS_CNT - 1 downto 0);
    signal tick_cnts_en_clr         : std_logic_vector(COUNTERS_CNT - 1 downto 0);
    signal tick_cnts_full           : std_logic_vector(COUNTERS_CNT - 1 downto 0);

    -- Ticks of currently finished request
    signal ticks_to_process         : std_logic_vector(TICKS_WIDTH - 1 downto 0);
    signal ticks_to_process_vld     : std_logic;

    -- Index counter which points to the tick counter (inside cyclic pool), 
    -- that will be used for measuring a new request
    signal newest_cnter             : std_logic_vector(log2(COUNTERS_CNT) - 1 downto 0);
    signal newest_cnter_onehot      : std_logic_vector(COUNTERS_CNT - 1 downto 0);
    signal newest_cnter_full        : std_logic;
    signal newest_cnter_en          : std_logic;
    -- Index counter which points to the index of the oldest request
    signal oldest_cnter             : std_logic_vector(log2(COUNTERS_CNT) - 1 downto 0);
    signal oldest_cnter_onehot      : std_logic_vector(COUNTERS_CNT - 1 downto 0);
    signal oldest_cnter_full        : std_logic;
    signal oldest_cnter_en          : std_logic;
    -- Delay oldest index counter to get correct tick count to process
    signal oldest_cnter_delayed     : std_logic_vector(log2(COUNTERS_CNT) - 1 downto 0);
    signal oldest_cnter_en_delayed  : std_logic;
    
    -- Indicates which index counter was recently incremented
    -- To determine if cyclic pool of counters was overflowed or is empty
    signal newest_incr              : std_logic;
    signal newest_incr_delayed      : std_logic;
    signal index_cnters_eq          : std_logic;

begin

    ----------------
    -- Components --
    ----------------
    newest_cnter_dec_i : entity work.DEC1FN
    generic map (
        ITEMS           => COUNTERS_CNT
    )
    port map (
        ADDR            => newest_cnter,
        DO              => newest_cnter_onehot
    );

    oldest_cnter_dec_i : entity work.DEC1FN
    generic map (
        ITEMS           => COUNTERS_CNT
    )
    port map (
        ADDR            => oldest_cnter,
        DO              => oldest_cnter_onehot
    );

    ------------------------
    -- Interconnect logic --
    ------------------------

    newest_cnter_en             <= READ_REQ;
    oldest_cnter_en             <= READ_RESP;

    newest_cnter_full           <= '1' when (newest_cnter = INDEX_CNTERS_LIM) else
                                   '0';                                   
    oldest_cnter_full           <= '1' when (oldest_cnter = INDEX_CNTERS_LIM) else
                                   '0';                                   
    cnters_full_g : for i in 0 to COUNTERS_CNT - 1 generate
        tick_cnts_full(i)       <= '1' when (tick_cnts(i) = TICKS_CNTERS_LIM) else
                                   '0';
        -- Enable tick counter for a new request
        tick_cnts_en_set(i)     <= newest_cnter_onehot(i) and newest_cnter_en;
        -- Disable tick counter of the finished request
        tick_cnts_en_clr(i)     <= oldest_cnter_onehot(i) and oldest_cnter_en;
    end generate;

    newest_incr                 <= newest_cnter_en  and (not oldest_cnter_en);
    index_cnters_eq             <= '1' when (unsigned(newest_cnter) = unsigned(oldest_cnter)) else
                                   '0';
    COUNTERS_OVF                <= newest_incr_delayed and index_cnters_eq;

    -- Check for overflow in one or more tick counters
    ticks_ovf_p : process(all)
        variable tmp : std_logic;
    begin
        tmp         := '0';
        for i in 0 to COUNTERS_CNT - 1 loop
            tmp     := tmp or (tick_cnts_full(i) and tick_cnts_en(i));
        end loop;
        TICKS_OVF   <= tmp;
    end process;

    ---------------
    -- Registers --
    ---------------

    newest_cnter_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1' or (newest_cnter_full = '1' and newest_cnter_en = '1')) then
                newest_cnter <= (others => '0');
            elsif (newest_cnter_en = '1') then
                newest_cnter <= std_logic_vector(unsigned(newest_cnter) + 1);
            end if;
        end if;
    end process;

    oldest_cnter_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1' or (oldest_cnter_full = '1' and oldest_cnter_en = '1')) then
                oldest_cnter <= (others => '0');
            elsif (oldest_cnter_en = '1') then
                oldest_cnter <= std_logic_vector(unsigned(oldest_cnter) + 1);
            end if;
        end if;
    end process;

    oldest_cnter_delayed_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            oldest_cnter_delayed <= oldest_cnter;
            oldest_cnter_en_delayed <= oldest_cnter_en;
        end if;
    end process;

    cnters_ens_g : for i in 0 to COUNTERS_CNT - 1 generate
        cnters_ens_p : process (CLK)
        begin
            if (rising_edge(CLK)) then
                if (RST = '1') then
                    tick_cnts_en(i)     <= '0';
                elsif (tick_cnts_en_clr(i) = '1') then
                    tick_cnts_en(i)     <= '0';
                elsif (tick_cnts_en_set(i) = '1') then
                    tick_cnts_en(i)     <= '1';
                end if;
            end if;
        end process;
    end generate;

    cnters_g : for i in 0 to COUNTERS_CNT - 1 generate
        cnters_p : process (CLK)
        begin
            if (rising_edge(CLK)) then
                if (RST = '1' or (tick_cnts_full(i) = '1' and tick_cnts_en(i) = '1')) then
                    tick_cnts(i)        <= (others => '0');
                elsif (tick_cnts_en(i) = '1') then
                    tick_cnts(i)        <= std_logic_vector(unsigned(tick_cnts(i)) + 1);
                elsif (tick_cnts_en(i) = '0') then
                    tick_cnts(i)        <= (others => '0');
                end if;
            end if;
        end process;
    end generate;

    ticks_to_process_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                ticks_to_process <= (others => '0');
            else
                ticks_to_process <= tick_cnts(to_integer(unsigned(oldest_cnter_delayed)));
            end if;
        end if;
    end process;

    ticks_to_process_vld_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            ticks_to_process_vld <= oldest_cnter_en_delayed;
        end if;
    end process;

    sum_ticks_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                SUM_TICKS       <= (others => '0');
            elsif (ticks_to_process_vld = '1') then
                SUM_TICKS       <= std_logic_vector(unsigned(SUM_TICKS) + unsigned(ticks_to_process));
            end if;
        end if;
    end process;

    min_ticks_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                MIN_TICKS       <= (others => '1');
            elsif (unsigned(MIN_TICKS) > unsigned (ticks_to_process) and ticks_to_process_vld = '1') then
                MIN_TICKS       <= ticks_to_process;
            end if;
        end if;
    end process;

    max_ticks_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                MAX_TICKS       <= (others => '0');
            elsif (unsigned(MAX_TICKS) < unsigned (ticks_to_process) and ticks_to_process_vld = '1') then
                MAX_TICKS       <= ticks_to_process;
            end if;
        end if;
    end process;

    newest_incr_delayed_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            newest_incr_delayed <= newest_incr;
        end if;
    end process;

end architecture;