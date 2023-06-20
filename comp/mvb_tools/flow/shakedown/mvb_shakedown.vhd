-- mvb_shakedown.vhd:
-- Copyright (C) 2023 CESNET z. s. p. o.
-- Author(s): Jakub Cabal  <cabal@cesnet.cz>
--            Oliver Gurka <oliver.gurka@cesnet.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.math_pack.all;
use work.type_pack.all;

-- Converts ``RX_ITEMS`` item input MVB to ``TX_ITEMS`` amount of single item MVB interfaces.
-- Items can be read independetly and in order (out of order is not tested, UVM verification needed).
entity MVB_SHAKEDOWN is
    generic(
        -- RX MVB item count
        RX_ITEMS    : natural := 4;
        -- TX MVB independent interfaces count (can be merged to one MVB with MERGE component)
        TX_ITEMS    : natural := 1;
        -- Data item width
        ITEM_WIDTH  : natural := 128;
        -- Shake ports, when 1, ``RX_ITEMS`` must be read from TX interface to accept next transaction
        -- on RX MVB. When 2, ``RX_ITEMS/2`` must be read, etc. Scale this number carefully, consumes
        -- lot of resources. When one needs value of 3, consider using ``MULTI_FIFOX`` for such use case.
        -- Ingored when using *SHIFT_REG* implemetation.
        SHAKE_PORTS : natural := 2; -- allowed values: 1, 2, 3
        
        -- Used only when TX_ITEMS=1, you can set it to `true` and MVB_SHAKEDOWN will be implemented using shift registers,
        -- resulting in much lower resources consumption. For more savings, see ``SHIFT_USE_SHAKEDOWN``.
        USE_SHIFT_REGS : boolean := True;
        
        -- When using shift register implementation, you can set this parameter to increase throughput to 100% of output MVB,
        -- however, setting this to ``true`` will increase resources used slightly.
        SHIFT_USE_SHAKEDOWN : boolean := False
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
        -- Transmit data (one item per MVB)
        TX_DATA    : out std_logic_vector(TX_ITEMS*ITEM_WIDTH-1 downto 0);
        -- Item valid, can be interpreted as ``SRC_RDY``
        TX_VLD     : out std_logic_vector(TX_ITEMS-1 downto 0);
        -- Next item request, can be interpreted as ``DST_RDY``
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

    -- =====================================
    -- Shift register implemetation signals
    -- =====================================
    
    signal sh_regs            : slv_array_t(ITEMS+2-1 downto 0)(ITEM_WIDTH-1 downto 0);
    signal sh_regs_vld        : std_logic_vector(ITEMS+2-1 downto 0);
    signal sh_regs_new        : slv_array_t(ITEMS+2-1 downto 0)(ITEM_WIDTH-1 downto 0);

    signal sh_regs_vld_new    : std_logic_vector(ITEMS+2-1 downto 0);
    signal sh_reg_get_higher  : std_logic_vector(ITEMS+2-1 downto 0);
    signal sh_reg_get_new     : std_logic_vector(ITEMS+2-1 downto 0);

    signal rx_data_int        : std_logic_vector(ITEMS*ITEM_WIDTH-1 downto 0);
    signal rx_vld_int         : std_logic_vector(ITEMS-1 downto 0);
    signal rx_src_rdy_int     : std_logic;
    signal rx_dst_rdy_int     : std_logic;


begin
    mvb_shakedown_g : if not USE_SHIFT_REGS or (TX_ITEMS /= 1) generate
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
            CLK      => CLK,
            RESET    => RESET,

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
    end generate;
    
    -- Implement effective N to 1 MVB shakedown
    shift_shakedown_g : if USE_SHIFT_REGS and (TX_ITEMS = 1) generate
        constant last_rdy : std_logic_vector(ITEMS-1 downto 0) := std_logic_vector(to_unsigned(1, ITEMS));
    begin
        -- Use shakedown for higher throughput, should be 100%.
        shakedown_g : if SHIFT_USE_SHAKEDOWN generate
            shakedown_i : entity work.SHAKEDOWN
            generic map (
                INPUTS        => RX_ITEMS,
                OUTPUTS       => RX_ITEMS,
                DATA_WIDTH    => ITEM_WIDTH,
                OUTPUT_REG    => False
            ) port map (
                CLK           => CLK,
                RESET         => RESET,

                DIN           => RX_DATA,
                DIN_VLD       => RX_VLD,
                DIN_SRC_RDY   => RX_SRC_RDY,
                DIN_DST_RDY   => RX_DST_RDY,

                DOUT          => rx_data_int,
                DOUT_VLD      => rx_vld_int,
                DOUT_SRC_RDY  => rx_src_rdy_int,
                DOUT_DST_RDY  => rx_dst_rdy_int
            );
        else generate
            rx_data_int     <= RX_DATA;
            rx_vld_int      <= RX_VLD;
            rx_src_rdy_int  <= RX_SRC_RDY;
            RX_DST_RDY      <= rx_dst_rdy_int;
        end generate;

        -- =======================================
        -- INPUT/OUTPUT LOGIC
        -- =======================================

        rx_dst_rdy_int <= '1' when (or(sh_regs_vld(ITEMS downto 1)) = '0') or ((sh_regs_vld(ITEMS downto 0) = last_rdy) and sh_reg_get_higher(0) = '1') else '0';
        sh_reg_get_new(ITEMS downto 1) <= (others => '1') when (rx_dst_rdy_int = '1' and rx_src_rdy_int = '1') else (others => '0');
        sh_reg_get_new(0) <= '0';
        sh_regs_new(ITEMS downto 1) <= slv_array_deser(rx_data_int, ITEMS);
        sh_regs_vld_new(ITEMS downto 1) <= rx_vld_int;
        sh_regs_vld_new(ITEMS+1) <= '0';
        sh_regs_vld_new(0) <= '0';

        sh_reg_get_higher(0) <= '1' when TX_NEXT(0) = '1' or (TX_VLD(0) = '0' and TX_NEXT(0) = '0') else '0';
        sh_reg_get_higher_g : for i in 1 to ITEMS generate
            sh_reg_get_higher(i) <= sh_reg_get_higher(i-1) or not sh_regs_vld(i);
        end generate sh_reg_get_higher_g;
        
        -- ========================================================================
        --  SHIFT REGISTERS
        -- ========================================================================

        sh_regs(ITEMS+1) <= (others => '0');
        sh_reg_g : for i in 0 to ITEMS generate
            process(CLK)
            begin
                if rising_edge(CLK) then
                    if sh_reg_get_new(i) = '1' then
                        sh_regs(i)      <= sh_regs_new(i);
                    elsif sh_reg_get_higher(i) = '1' then
                        sh_regs(i)      <= sh_regs(i+1);
                    end if;
                end if;
            end process;
        end generate;
        
        sh_regs_vld(ITEMS+1) <= '0';
        sh_reg_vld_g : for i in 0 to ITEMS generate
            process(CLK)
            begin
                if rising_edge(CLK) then
                    if RESET = '1' then
                        sh_regs_vld(i) <= '0';
                    else
                        if sh_reg_get_new(i) = '1' then
                            sh_regs_vld(i)  <= sh_regs_vld_new(i);
                        elsif sh_reg_get_higher(i) = '1' then
                            sh_regs_vld(i)  <= sh_regs_vld(i+1);
                        end if;
                    end if;
                end if;
            end process;
        end generate;

        TX_DATA <= sh_regs(0);
        TX_VLD <= sh_regs_vld(0 downto 0);
    end generate;
end architecture;
