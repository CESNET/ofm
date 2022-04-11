-- testbench.vhd: Testbench
-- Copyright (C) 2019 CESNET z. s. p. o.
-- Author(s): Jan Kubalek <xkubal11@stud.fit.vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause

library IEEE;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.math_pack.all;
use work.type_pack.all;
use std.env.stop;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------

entity testbench is
end entity testbench;

-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------

architecture behavioral of testbench is

    -- Constants declaration ---------------------------------------------------
    -- Synchronization
    constant C_CLK_PER  : time := 5.0 ns;
    constant C_RST_TIME : time := 10 * C_CLK_PER + 1 ns;
    constant VER_LENGTH : natural := 100000;

    constant USE_SHAKEDOWN_ARCH : boolean := false;

    constant s_DATA_WIDTH           : integer := 4;
    constant s_WRITE_PORTS          : integer := 3;
    constant s_READ_PORTS           : integer := 8;
    constant s_ITEMS                : integer := 128;
    constant s_ALMOST_FULL_OFFSET   : integer := 5;
    constant s_ALMOST_EMPTY_OFFSET  : integer := 5;
    constant s_SAFE_READ_MODE       : boolean := true;

    -- Synchronization
    signal clk   : std_logic;
    signal reset : std_logic;

    -- uut I/O
    signal s_data_in  : std_logic_vector(s_WRITE_PORTS*s_DATA_WIDTH-1 downto 0);
    signal s_we       : std_logic_vector(s_WRITE_PORTS-1 downto 0) := (others => '0');
    signal s_full     : std_logic;
    signal s_afull    : std_logic;
    signal s_data_out : std_logic_vector(s_READ_PORTS*s_DATA_WIDTH-1 downto 0);
    signal s_re       : std_logic_vector(s_READ_PORTS-1 downto 0) := (others => '0');
    signal s_empty    : std_logic_vector(s_READ_PORTS-1 downto 0);
    signal s_aempty   : std_logic;

    -- test signals
    signal s_fake_fifo        : slv_array_t(0 to s_ITEMS*8-1)(s_DATA_WIDTH-1 downto 0) := (others => (others => '0'));
    signal s_fake_fifo_wr_ptr : unsigned(log2(s_ITEMS*8)-1 downto 0) := (others => '0');
    signal s_fake_fifo_rd_ptr : unsigned(log2(s_ITEMS*8)-1 downto 0) := (others => '0');
    signal s_read_items       : integer := 0;

-- ----------------------------------------------------------------------------
--                            Architecture body
-- ----------------------------------------------------------------------------

begin

    -- -------------------------------------------------------------------------
    -- UUT
    -- -------------------------------------------------------------------------

    full_gen : if (not USE_SHAKEDOWN_ARCH) generate
        uut: entity work.FIFOX_MULTI(FULL)
        generic map(
            DATA_WIDTH          => s_DATA_WIDTH,
            WRITE_PORTS         => s_WRITE_PORTS,
            READ_PORTS          => s_READ_PORTS,
            ITEMS               => s_ITEMS,
            ALMOST_FULL_OFFSET  => s_ALMOST_FULL_OFFSET,
            ALMOST_EMPTY_OFFSET => s_ALMOST_EMPTY_OFFSET,
            SAFE_READ_MODE      => s_SAFE_READ_MODE
        )
        port map(
            CLK   => clk,
            RESET => reset,

            DI     => s_data_in,
            WR     => s_we,
            FULL   => s_full,
            AFULL  => s_afull,

            DO     => s_data_out,
            RD     => s_re,
            EMPTY  => s_empty,
            AEMPTY => s_aempty
        );
    end generate;
    
    shake_gen : if (USE_SHAKEDOWN_ARCH) generate
        uut: entity work.FIFOX_MULTI(SHAKEDOWN)
        generic map(
            DATA_WIDTH          => s_DATA_WIDTH,
            WRITE_PORTS         => s_WRITE_PORTS,
            READ_PORTS          => s_READ_PORTS,
            ITEMS               => s_ITEMS,
            ALMOST_FULL_OFFSET  => s_ALMOST_FULL_OFFSET,
            ALMOST_EMPTY_OFFSET => s_ALMOST_EMPTY_OFFSET,
            SAFE_READ_MODE      => s_SAFE_READ_MODE
        )
        port map(
            CLK   => clk,
            RESET => reset,

            DI     => s_data_in,
            WR     => s_we,
            FULL   => s_full,
            AFULL  => s_afull,

            DO     => s_data_out,
            RD     => s_re,
            EMPTY  => s_empty,
            AEMPTY => s_aempty
        );
    end generate;

    -- -------------------------------------------------------------------------
    --                        clk and reset generators
    -- -------------------------------------------------------------------------

    -- generating clk
    clk_gen: process
    begin
        for i in 0 to VER_LENGTH-1 loop
            clk <= '1';
            wait for C_CLK_PER / 2;
            clk <= '0';
            wait for C_CLK_PER / 2;
        end loop;
        report "Verification finished successfully!";
        stop;
        wait;
    end process clk_gen;

    -- generating reset
    rst_gen: process
    begin
        reset <= '1';
        wait for C_RST_TIME;
        reset <= '0';
        wait;
    end process rst_gen;

    -- -------------------------------------------------------------------------
    -- test process
    -- -------------------------------------------------------------------------

    test : process
        variable seed1 : positive := s_ITEMS;
        variable seed2 : positive := s_WRITE_PORTS;

        variable rand : real;
        variable X    : integer;

        variable wr_ch : integer := 60; -- %
        variable rd_ch : integer := 60; -- %

        variable read_items : integer := 0;

        variable ch_ch : integer := 15; -- %

        variable wr_ptr : unsigned(log2(s_ITEMS*8)-1 downto 0) := (others => '0');
        variable rd_ptr : unsigned(log2(s_ITEMS*8)-1 downto 0) := (others => '0');

        variable data : unsigned(log2(s_ITEMS*8)-1 downto 0) := (others => '0');

        variable wrc : integer := 0;
        variable wrc0 : integer := 0;
        variable wrc1 : integer := 0;

        variable e : integer := 0;
    begin
        wait for C_CLK_PER/2;
        if (reset='1') then
            wait until reset='0';
        end if;

        assert (e=0) severity failure;

        s_data_in <= (others => '0');
        s_we <= (others => '0');
        s_re <= (others => '0');

        wrc := 0;

        wr_ptr := s_fake_fifo_wr_ptr;
        rd_ptr := s_fake_fifo_rd_ptr;
        read_items := s_read_items;

        for i in 0 to s_WRITE_PORTS-1 loop
            uniform(seed1,seed2,rand);
            X := integer(rand*99.0);
            if (X<wr_ch) then
                s_we(i) <= '1';
                if (s_full='0') then
                    s_data_in(s_DATA_WIDTH*(i+1)-1 downto s_DATA_WIDTH*i) <= std_logic_vector(resize(data,s_DATA_WIDTH));
                    s_fake_fifo(to_integer(wr_ptr)) <= std_logic_vector(resize(data,s_DATA_WIDTH));
                    data := data+1;
                    wr_ptr := resize((wr_ptr+1) mod (s_ITEMS*8),log2(s_ITEMS*8));
                    wrc := wrc + 1 ;
                end if;
            end if;
        end loop;

        for i in 0 to s_READ_PORTS-1 loop
            uniform(seed1,seed2,rand);
            X := integer(rand*99.0);

            if (X<rd_ch) then
                if (s_empty(i)='0' or s_SAFE_READ_MODE=true) then
                    s_re(i) <= '1';
                    if (s_empty(i)='0') then
                        if (s_fake_fifo(to_integer(rd_ptr))/=s_data_out(s_DATA_WIDTH*(i+1)-1 downto s_DATA_WIDTH*i)) then
                            report "Incorrect data read!" severity error;
                            e := 1;
                        end if;
                        rd_ptr := resize((rd_ptr+1) mod (s_ITEMS*8),log2(s_ITEMS*8));
                        read_items := read_items+1;
                    end if;
                end if;
            else
                exit;
            end if;
        end loop;

        s_fake_fifo_wr_ptr <= wr_ptr;
        s_fake_fifo_rd_ptr <= rd_ptr;
        s_read_items <= read_items;

        if (s_full='0') then
            wrc1 := wrc0;
            wrc0 := wrc;
        end if;

        uniform(seed1,seed2,rand);
        X := integer(rand*99.0);

        if (X<ch_ch) then
            uniform(seed1,seed2,rand);
            wr_ch := integer(rand*100.0);
            uniform(seed1,seed2,rand);
            rd_ch := integer(rand*100.0);
        end if;

        wait for C_CLK_PER/2;
    end process;

end architecture behavioral;
