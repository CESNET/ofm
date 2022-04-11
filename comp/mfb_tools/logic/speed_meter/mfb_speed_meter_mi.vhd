-- mfb_speed_meter_mi.vhd: MFB speed meter encapsulation
-- Copyright (C) 2020 CESNET
-- Author(s): Daniel Kříž <xkrizd01@vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.math_pack.all;
use work.type_pack.all;

entity MFB_SPEED_METER_MI is
    generic(
        -- MFB CONFIGURATION
        -- =================
        REGIONS          : natural := 2;
        REGION_SIZE      : natural := 8;
        BLOCK_SIZE       : natural := 8;
        ITEM_WIDTH       : natural := 8;
        -- SPEED METER CONFIGURATION
        -- =========================
        -- Set time of speed test (time = (2^CNT_TICKS_WIDTH)-1 in clock ticks).
        CNT_TICKS_WIDTH  : natural := 24;
        -- Set width of valid bytes counter. Optimum and MINIMUM value is:
        -- log2(((2^CNT_TICKS_WIDTH)-1)*REGIONS*REGION_SIZE*BLOCK_SIZE)
        CNT_BYTES_WIDTH  : natural := 32;
        -- MI32 parameters
        MI_DATA_WIDTH    : natural := 32;
        MI_ADDRESS_WIDTH : natural := 32
    );
    port(
        -- CLOCK AND RESET
        CLK        : in  std_logic;
        RST        : in  std_logic;

        -- MI32 interface
        MI_DWR     : in  std_logic_vector(MI_DATA_WIDTH-1 downto 0);
        MI_ADDR    : in  std_logic_vector(MI_ADDRESS_WIDTH-1 downto 0);
        MI_BE      : in  std_logic_vector(3 downto 0); -- Not supported!
        MI_RD      : in  std_logic;
        MI_WR      : in  std_logic;
        MI_ARDY    : out std_logic;
        MI_DRD     : out std_logic_vector(MI_DATA_WIDTH-1 downto 0);
        MI_DRDY    : out std_logic;

        -- RX MFB CONTROL INTERFACE
        RX_SOF_POS : in  std_logic_vector(REGIONS*max(1,log2(REGION_SIZE))-1 downto 0);
        RX_EOF_POS : in  std_logic_vector(REGIONS*max(1,log2(REGION_SIZE*BLOCK_SIZE))-1 downto 0);
        RX_SOF     : in  std_logic_vector(REGIONS-1 downto 0);
        RX_EOF     : in  std_logic_vector(REGIONS-1 downto 0);
        RX_SRC_RDY : in  std_logic;
        RX_DST_RDY : in  std_logic
    );
end entity;

architecture FULL of MFB_SPEED_METER_MI is

    signal cnt_ticks_reg     : std_logic_vector(CNT_TICKS_WIDTH-1 downto 0);
    signal cnt_ticks_max_reg : std_logic;
    signal cnt_bytes_reg     : std_logic_vector(CNT_BYTES_WIDTH-1 downto 0);
    signal cnt_clear         : std_logic;
    signal cnt_clear_reg     : std_logic;

begin
    mfb_speed_meter_i : entity work.MFB_SPEED_METER
    generic map (
        REGIONS         => REGIONS,
        REGION_SIZE     => REGION_SIZE,
        BLOCK_SIZE      => BLOCK_SIZE,
        ITEM_WIDTH      => ITEM_WIDTH,
        CNT_TICKS_WIDTH => CNT_TICKS_WIDTH,
        CNT_BYTES_WIDTH => CNT_BYTES_WIDTH
    )
    port map (
        CLK             => CLK,
        RST             => RST,

        --MFB interface
        RX_SOF_POS      => RX_SOF_POS,
        RX_EOF_POS      => RX_EOF_POS,
        RX_SOF          => RX_SOF,
        RX_EOF          => RX_EOF,
        RX_SRC_RDY      => RX_SRC_RDY,
        RX_DST_RDY      => RX_DST_RDY,

        CNT_TICKS       => cnt_ticks_reg,
        CNT_TICKS_MAX   => cnt_ticks_max_reg,
        CNT_BYTES       => cnt_bytes_reg,
        CNT_CLEAR       => cnt_clear_reg
    );

    -- --------------------------------------------------------------------------
    --  MI BUS LOGIC
    -- --------------------------------------------------------------------------

    cnt_clear <= '1' when MI_WR = '1' and MI_ADDR(4-1 downto 0) = X"C" else '0';

    cnt_clear_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            cnt_clear_reg <= cnt_clear;
        end if;
    end process;

    logic_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            case MI_ADDR(4-1 downto 0) is
                when X"0"   => MI_DRD <= std_logic_vector(resize(unsigned(cnt_ticks_reg), MI_DATA_WIDTH));
                when X"4"   => MI_DRD <= (0 => cnt_ticks_max_reg, others => '0');
                when X"8"   => MI_DRD <= cnt_bytes_reg;
                when others => MI_DRD <= (others => '0');
            end case;
        end if;
    end process;
  
    MI_ARDY <= MI_RD or MI_WR;

    mi_drdy_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            MI_DRDY <= MI_RD;
            if (RST = '1') then
                MI_DRDY <= '0';
            end if; 
        end if;
    end process;

end architecture;