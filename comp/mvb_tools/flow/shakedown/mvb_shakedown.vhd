-- mvb_shakedown.vhd:
-- Copyright (C) 2019 CESNET z. s. p. o.
-- Author(s): Jakub Cabal <cabal@cesnet.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.math_pack.all;
use work.type_pack.all;

entity MVB_SHAKEDOWN is
    generic(
        RX_ITEMS    : natural := 2;
        TX_ITEMS    : natural := 4;
        ITEM_WIDTH  : natural := 128;
        SHAKE_PORTS : natural := 2 -- allowed values: 1, 2, 3
    );
    port(
        -- =====================================================================
        -- CLOCK AND RESET
        -- =====================================================================
        CLK        : in  std_logic;
        RESET      : in  std_logic;

        -- =====================================================================
        --  INPUT MVB INTERFACE
        -- =====================================================================
        RX_DATA    : in  std_logic_vector(RX_ITEMS*ITEM_WIDTH-1 downto 0);
        RX_VLD     : in  std_logic_vector(RX_ITEMS-1 downto 0);
        RX_SRC_RDY : in  std_logic;
        RX_DST_RDY : out std_logic;

        -- =====================================================================
        --  OUTPUT MULTI MVB INTERFACE
        -- =====================================================================
        TX_DATA    : out std_logic_vector(TX_ITEMS*ITEM_WIDTH-1 downto 0);
        TX_VLD     : out std_logic_vector(TX_ITEMS-1 downto 0);
        TX_NEXT    : in  std_logic_vector(TX_ITEMS-1 downto 0)
    );
end entity;

architecture FULL of MVB_SHAKEDOWN is

    -- ============================
    -- Unequal RX/TX ITEMS interface wrapper
    -- ============================

    constant ITEMS       : integer := max(RX_ITEMS,TX_ITEMS);
    signal eq_RX_DATA    : std_logic_vector(ITEMS*ITEM_WIDTH-1 downto 0);
    signal eq_RX_VLD     : std_logic_vector(ITEMS-1 downto 0);
    signal eq_TX_DATA    : std_logic_vector(ITEMS*ITEM_WIDTH-1 downto 0);
    signal eq_TX_VLD     : std_logic_vector(ITEMS-1 downto 0);
    signal eq_TX_NEXT    : std_logic_vector(ITEMS-1 downto 0);

    -- ============================

    signal s_rx_dst_rdy             : std_logic;
    signal s_rx_vld_reg             : std_logic_vector(ITEMS-1 downto 0);
    signal s_rx_data_reg            : std_logic_vector(ITEMS*ITEM_WIDTH-1 downto 0);

    signal s_sh_din                 : std_logic_vector(SHAKE_PORTS*ITEMS*ITEM_WIDTH-1 downto 0);
    signal s_sh_din_vld             : std_logic_vector(SHAKE_PORTS*ITEMS-1 downto 0);

    signal s_sh_dout                : std_logic_vector(SHAKE_PORTS*ITEMS*ITEM_WIDTH-1 downto 0);
    signal s_sh_dout_vld            : std_logic_vector(SHAKE_PORTS*ITEMS-1 downto 0);

    signal s_sh_dout_reg            : std_logic_vector(SHAKE_PORTS*ITEMS*ITEM_WIDTH-1 downto 0);
    signal s_sh_dout_vld_reg        : std_logic_vector(SHAKE_PORTS*ITEMS-1 downto 0);
    signal s_sh_dout_vld_reg_masked : std_logic_vector(SHAKE_PORTS*ITEMS-1 downto 0);

    signal s_tx_data_reg            : std_logic_vector(ITEMS*ITEM_WIDTH-1 downto 0);
    signal s_tx_vld_reg             : std_logic_vector(ITEMS-1 downto 0);

begin

    -- ============================
    -- Unequal RX/TX ITEMS interface wrapper
    -- ============================

    eq_RX_DATA <= std_logic_vector(resize(unsigned(RX_DATA),ITEMS*ITEM_WIDTH));
    eq_RX_VLD  <= std_logic_vector(resize(unsigned(RX_VLD),ITEMS));

    TX_DATA    <= std_logic_vector(resize(unsigned(eq_TX_DATA),TX_ITEMS*ITEM_WIDTH));
    TX_VLD     <= std_logic_vector(resize(unsigned(eq_TX_VLD),TX_ITEMS));
    eq_TX_NEXT <= std_logic_vector(resize(unsigned(TX_NEXT),ITEMS));

    -- ============================

    RX_DST_RDY <= s_rx_dst_rdy;

    -- =========================================================================
    --  INPUT REGISTERS
    -- =========================================================================

    in_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (s_rx_dst_rdy = '1') then
                s_rx_data_reg <= eq_RX_DATA;
            end if;
        end if;
    end process;

    in_vld_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RESET = '1') then
                s_rx_vld_reg <= (others => '0');
            elsif (s_rx_dst_rdy = '1') then
                s_rx_vld_reg <= eq_RX_VLD and RX_SRC_RDY;
            end if;
        end if;
    end process;

    -- =========================================================================
    --  INPUT LOGIC
    -- =========================================================================

    sh_din_p : process (all)
    begin
        s_sh_din     <= s_sh_dout_reg;
        s_sh_din_vld <= s_sh_dout_vld_reg_masked;
        if (s_rx_dst_rdy = '1') then
            s_sh_din(SHAKE_PORTS*ITEMS*ITEM_WIDTH-1 downto (SHAKE_PORTS-1)*ITEMS*ITEM_WIDTH) <= s_rx_data_reg;
            s_sh_din_vld(SHAKE_PORTS*ITEMS-1 downto (SHAKE_PORTS-1)*ITEMS)                   <= s_rx_vld_reg;
        end if;
    end process;

    -- =========================================================================
    --  SHAKEDOWN MODULE
    -- =========================================================================

    shakedown_i : entity work.SHAKEDOWN
    generic map(
        INPUTS     => SHAKE_PORTS*ITEMS,
        OUTPUTS    => SHAKE_PORTS*ITEMS,
        DATA_WIDTH => ITEM_WIDTH
    )
    port map(
        DIN      => s_sh_din,
        DIN_VLD  => s_sh_din_vld,
        DOUT     => s_sh_dout,
        DOUT_VLD => s_sh_dout_vld
    );

    -- =========================================================================
    --  REGISTERS AND VALID MASKING
    -- =========================================================================

    sh_dout_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            s_sh_dout_reg <= s_sh_dout;
        end if;
    end process;

    sh_dout_vld_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RESET = '1') then
                s_sh_dout_vld_reg <= (others => '0');
            else
                s_sh_dout_vld_reg <= s_sh_dout_vld;
            end if;
        end if;
    end process;

    rx_dst_rdy_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RESET = '1') then
                s_rx_dst_rdy <= '0';
            else
                s_rx_dst_rdy <= not s_sh_dout_vld((SHAKE_PORTS-1)*ITEMS);
            end if;
        end if;
    end process;

    s_sh_dout_vld_reg_masked(SHAKE_PORTS*ITEMS-1 downto ITEMS) <= s_sh_dout_vld_reg(SHAKE_PORTS*ITEMS-1 downto ITEMS);
    s_sh_dout_vld_reg_masked(ITEMS-1 downto 0) <= s_sh_dout_vld_reg(ITEMS-1 downto 0) and (not eq_TX_NEXT);

    -- =========================================================================
    --  OUTPUT LOGIC
    -- =========================================================================

    eq_TX_DATA <= s_sh_dout_reg(ITEMS*ITEM_WIDTH-1 downto 0);
    eq_TX_VLD  <= s_sh_dout_vld_reg(ITEMS-1 downto 0);

end architecture;
