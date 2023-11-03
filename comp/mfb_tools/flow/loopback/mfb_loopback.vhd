-- mfb_loopback.vhd: this module provides the capability to loopback data between the RX and TX
-- interfaces on the MFB bus
-- Copyright (C) 2023 CESNET z. s. p. o.
-- Author(s): Vladislav Valek <valekv@cesnet.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.type_pack.all;
use work.math_pack.all;

-- This component provides the capability to set loopback on MFB interfaces. Both near-end and
-- far-end type is possible. The module is controlled by the :ref:`MI interface <mi_bus>` where
-- address space is set as follows:
--
-- .. code-block::
--
--   0x00      -- TX to RX loopback (0 -> disable, 1 -> enable)
--   0x04      -- RX to TX loopback (0 -> disable, 1 -> enable)
--
entity MFB_LOOPBACK is
    generic (
        DEVICE        : string := "ULTRASCALE";
        -- Number of regions in a data word
        REGIONS       : natural := 1;
        -- Number of blocks in a region
        REGION_SIZE   : natural := 8;
        -- Number of items in a block
        BLOCK_SIZE    : natural := 8;
        -- Number of bits in an item
        ITEM_WIDTH    : natural := 8;
        -- Size of metadata in bits
        META_WIDTH    : natural := 24;
        -- When true, simple interconnect from input to output is inserted, the loopback logic is
        -- not applied
        FAKE_LOOPBACK : boolean := FALSE;
        -- When true, the MI bus and the internal logic use the same clock, otherwise the
        -- asynchronous crossing is inserted
        SAME_CLK      : boolean := TRUE
        );
    port (
        -- =========================================================================================
        -- MI32 interface
        -- =========================================================================================
        MI_CLK   : in std_logic;
        MI_RESET : in std_logic;

        MI_DWR  : in  std_logic_vector(32-1 downto 0);
        MI_ADDR : in  std_logic_vector(32-1 downto 0);
        MI_RD   : in  std_logic;
        MI_WR   : in  std_logic;
        MI_ARDY : out std_logic;
        MI_DRD  : out std_logic_vector(32-1 downto 0);
        MI_DRDY : out std_logic;

        -- =========================================================================================
        -- Internal clock and reset for all interfaces besides MI32
        -- =========================================================================================
        CLK   : in std_logic;
        RESET : in std_logic;

        -- =========================================================================================
        -- Input of the RX MFB interface
        -- =========================================================================================
        RX_DATA_IN    : in  std_logic_vector(REGIONS*REGION_SIZE*BLOCK_SIZE*ITEM_WIDTH -1 downto 0);
        RX_META_IN    : in  std_logic_vector(META_WIDTH -1 downto 0);
        RX_SOF_IN     : in  std_logic_vector(REGIONS -1 downto 0);
        RX_EOF_IN     : in  std_logic_vector(REGIONS -1 downto 0);
        RX_SOF_POS_IN : in  std_logic_vector(REGIONS*max(1, log2(REGION_SIZE)) -1 downto 0);
        RX_EOF_POS_IN : in  std_logic_vector(REGIONS*max(1, log2(REGION_SIZE*BLOCK_SIZE)) -1 downto 0);
        RX_SRC_RDY_IN : in  std_logic;
        RX_DST_RDY_IN : out std_logic;

        -- =========================================================================================
        -- Output of the RX MFB interface
        -- =========================================================================================
        RX_DATA_OUT    : out std_logic_vector(REGIONS*REGION_SIZE*BLOCK_SIZE*ITEM_WIDTH -1 downto 0);
        RX_META_OUT    : out std_logic_vector(META_WIDTH -1 downto 0);
        RX_SOF_OUT     : out std_logic_vector(REGIONS -1 downto 0);
        RX_EOF_OUT     : out std_logic_vector(REGIONS -1 downto 0);
        RX_SOF_POS_OUT : out std_logic_vector(REGIONS*max(1, log2(REGION_SIZE)) -1 downto 0);
        RX_EOF_POS_OUT : out std_logic_vector(REGIONS*max(1, log2(REGION_SIZE*BLOCK_SIZE)) -1 downto 0);
        RX_SRC_RDY_OUT : out std_logic;
        RX_DST_RDY_OUT : in  std_logic;

        -- =========================================================================================
        -- Output of the TX MFB interface
        -- =========================================================================================
        TX_DATA_OUT    : out std_logic_vector(REGIONS*REGION_SIZE*BLOCK_SIZE*ITEM_WIDTH -1 downto 0);
        TX_META_OUT    : out std_logic_vector(META_WIDTH -1 downto 0);
        TX_SOF_OUT     : out std_logic_vector(REGIONS -1 downto 0);
        TX_EOF_OUT     : out std_logic_vector(REGIONS -1 downto 0);
        TX_SOF_POS_OUT : out std_logic_vector(REGIONS*max(1, log2(REGION_SIZE)) -1 downto 0);
        TX_EOF_POS_OUT : out std_logic_vector(REGIONS*max(1, log2(REGION_SIZE*BLOCK_SIZE)) -1 downto 0);
        TX_SRC_RDY_OUT : out std_logic;
        TX_DST_RDY_OUT : in  std_logic;

        -- =========================================================================================
        -- Input of the TX MFB interface
        -- =========================================================================================
        TX_DATA_IN    : in  std_logic_vector(REGIONS*REGION_SIZE*BLOCK_SIZE*ITEM_WIDTH -1 downto 0);
        TX_META_IN    : in  std_logic_vector(META_WIDTH -1 downto 0);
        TX_SOF_IN     : in  std_logic_vector(REGIONS -1 downto 0);
        TX_EOF_IN     : in  std_logic_vector(REGIONS -1 downto 0);
        TX_SOF_POS_IN : in  std_logic_vector(REGIONS*max(1, log2(REGION_SIZE)) -1 downto 0);
        TX_EOF_POS_IN : in  std_logic_vector(REGIONS*max(1, log2(REGION_SIZE*BLOCK_SIZE)) -1 downto 0);
        TX_SRC_RDY_IN : in  std_logic;
        TX_DST_RDY_IN : out std_logic
        );
end entity;

architecture FULL of MFB_LOOPBACK is

    constant mi_split_addr_base : slv_array_t(2-1 downto 0)(32-1 downto 0) :=
        (X"00000040", X"00000000");

    signal mi_sync_dwr  : std_logic_vector(32-1 downto 0);
    signal mi_sync_addr : std_logic_vector(32-1 downto 0);
    signal mi_sync_rd   : std_logic;
    signal mi_sync_wr   : std_logic;
    signal mi_sync_ardy : std_logic;
    signal mi_sync_drd  : std_logic_vector(32-1 downto 0);
    signal mi_sync_drdy : std_logic;

    signal mi_sync_addr_local : unsigned(6-1 downto 0);

    signal tx2rx_loop_mux_sel_reg : std_logic;
    signal rx2tx_loop_mux_sel_reg : std_logic;

    signal rx_mfb_dst_rdy_in_int : std_logic;
    signal tx_mfb_dst_rdy_in_int : std_logic;

    -- Quartus
    attribute maxfan                               : integer;
    attribute maxfan of tx2rx_loop_mux_sel_reg     : signal is 32;
    attribute maxfan of rx2tx_loop_mux_sel_reg     : signal is 32;
    -- Vivado
    attribute max_fanout                           : integer;
    attribute max_fanout of tx2rx_loop_mux_sel_reg : signal is 32;
    attribute max_fanout of rx2tx_loop_mux_sel_reg : signal is 32;

begin

    fake_loopback_g : if (FAKE_LOOPBACK) generate
        MI_ARDY <= MI_RD or MI_WR;
        MI_DRDY <= MI_RD;
        MI_DRD  <= (others => '0');

        TX_DATA_OUT    <= TX_DATA_IN;
        TX_META_OUT    <= TX_META_IN;
        TX_SOF_OUT     <= TX_SOF_IN;
        TX_EOF_OUT     <= TX_EOF_IN;
        TX_SOF_POS_OUT <= TX_SOF_POS_IN;
        TX_EOF_POS_OUT <= TX_EOF_POS_IN;
        TX_SRC_RDY_OUT <= TX_SRC_RDY_IN;
        TX_DST_RDY_IN  <= TX_DST_RDY_OUT;

        RX_DATA_OUT    <= RX_DATA_IN;
        RX_META_OUT    <= RX_META_IN;
        RX_SOF_OUT     <= RX_SOF_IN;
        RX_EOF_OUT     <= RX_EOF_IN;
        RX_SOF_POS_OUT <= RX_SOF_POS_IN;
        RX_EOF_POS_OUT <= RX_EOF_POS_IN;
        RX_SRC_RDY_OUT <= RX_SRC_RDY_IN;
        RX_DST_RDY_IN  <= RX_DST_RDY_OUT;
    end generate;

    not_fake_switch_g : if (not FAKE_LOOPBACK) generate

        -- =========================================================================================
        -- MI32 Asynch
        -- =========================================================================================
        mi_clk_diff_g : if (not SAME_CLK) generate

            mi_async_i : entity work.MI_ASYNC
                generic map(
                    DEVICE => DEVICE
                    )
                port map(
                    -- Master interface
                    CLK_M     => MI_CLK,
                    RESET_M   => MI_RESET,
                    MI_M_DWR  => MI_DWR,
                    MI_M_ADDR => MI_ADDR,
                    MI_M_RD   => MI_RD,
                    MI_M_WR   => MI_WR,
                    MI_M_BE   => (others => '1'),
                    MI_M_DRD  => MI_DRD,
                    MI_M_ARDY => MI_ARDY,
                    MI_M_DRDY => MI_DRDY,

                    -- Slave interface
                    CLK_S     => CLK,
                    RESET_S   => RESET,
                    MI_S_DWR  => mi_sync_dwr,
                    MI_S_ADDR => mi_sync_addr,
                    MI_S_RD   => mi_sync_rd,
                    MI_S_WR   => mi_sync_wr,
                    MI_S_BE   => open,
                    MI_S_DRD  => mi_sync_drd,
                    MI_S_ARDY => mi_sync_ardy,
                    MI_S_DRDY => mi_sync_drdy
                    );

        else generate

            mi_sync_dwr  <= MI_DWR;
            mi_sync_addr <= MI_ADDR;
            mi_sync_rd   <= MI_RD;
            mi_sync_wr   <= MI_WR;

            MI_DRD  <= mi_sync_drd;
            MI_ARDY <= mi_sync_ardy;
            MI_DRDY <= mi_sync_drdy;

        end generate;

        -- =========================================================================================
        -- Local MI connection
        -- =========================================================================================
        mi_sync_addr_local <= unsigned(mi_sync_addr(mi_sync_addr_local'high downto 0));

        mi_rd_p : process (CLK)
        begin
            if (rising_edge(CLK)) then
                if (RESET = '1') then
                    mi_sync_drdy <= '0';
                else
                    case to_integer(mi_sync_addr_local) is
                        -- MUX Selects
                        when 16#00# => mi_sync_drd <= (0 => tx2rx_loop_mux_sel_reg, others => '0');
                        when 16#04# => mi_sync_drd <= (0 => rx2tx_loop_mux_sel_reg, others => '0');
                        -- Others
                        when others => mi_sync_drd <= X"DEAD1440";
                    end case;

                    mi_sync_drdy <= mi_sync_rd;
                end if;
            end if;
        end process;

        mi_sync_ardy <= mi_sync_rd or mi_sync_wr;

        -- =========================================================================================
        -- MUX SEL registers
        -- =========================================================================================
        mux_sel_reg_pr : process (CLK)
        begin
            if (rising_edge(CLK)) then
                if (RESET = '1') then

                    tx2rx_loop_mux_sel_reg <= '0';
                    rx2tx_loop_mux_sel_reg <= '0';

                elsif (mi_sync_wr = '1') then

                    if (mi_sync_addr_local = 16#00#) then
                        tx2rx_loop_mux_sel_reg <= mi_sync_dwr(0);
                    end if;

                    if (mi_sync_addr_local = 16#04#) then
                        rx2tx_loop_mux_sel_reg <= mi_sync_dwr(0);
                    end if;
                end if;
            end if;
        end process;

        -- =========================================================================================
        -- TX -> RX Loopback MUX
        -- =========================================================================================

        RX_DATA_OUT    <= RX_DATA_IN                                     when tx2rx_loop_mux_sel_reg = '0' else TX_DATA_IN;
        RX_META_OUT    <= RX_META_IN                                     when tx2rx_loop_mux_sel_reg = '0' else TX_META_IN;
        RX_SOF_OUT     <= RX_SOF_IN                                      when tx2rx_loop_mux_sel_reg = '0' else TX_SOF_IN;
        RX_EOF_OUT     <= RX_EOF_IN                                      when tx2rx_loop_mux_sel_reg = '0' else TX_EOF_IN;
        RX_SOF_POS_OUT <= RX_SOF_POS_IN                                  when tx2rx_loop_mux_sel_reg = '0' else TX_SOF_POS_IN;
        RX_EOF_POS_OUT <= RX_EOF_POS_IN                                  when tx2rx_loop_mux_sel_reg = '0' else TX_EOF_POS_IN;
        RX_SRC_RDY_OUT <= RX_SRC_RDY_IN and (not rx2tx_loop_mux_sel_reg) when tx2rx_loop_mux_sel_reg = '0' else TX_SRC_RDY_IN;

        rx_mfb_dst_rdy_in_int <= RX_DST_RDY_OUT    when tx2rx_loop_mux_sel_reg = '0' else '1';
        RX_DST_RDY_IN     <= rx_mfb_dst_rdy_in_int when rx2tx_loop_mux_sel_reg = '0' else TX_DST_RDY_OUT;

        -- =========================================================================================
        -- RX -> TX Loopback MUX
        -- =========================================================================================
        TX_DATA_OUT    <= TX_DATA_IN                                     when rx2tx_loop_mux_sel_reg = '0' else RX_DATA_IN;
        TX_META_OUT    <= TX_META_IN                                     when rx2tx_loop_mux_sel_reg = '0' else RX_META_IN;
        TX_SOF_OUT     <= TX_SOF_IN                                      when rx2tx_loop_mux_sel_reg = '0' else RX_SOF_IN;
        TX_EOF_OUT     <= TX_EOF_IN                                      when rx2tx_loop_mux_sel_reg = '0' else RX_EOF_IN;
        TX_SOF_POS_OUT <= TX_SOF_POS_IN                                  when rx2tx_loop_mux_sel_reg = '0' else RX_SOF_POS_IN;
        TX_EOF_POS_OUT <= TX_EOF_POS_IN                                  when rx2tx_loop_mux_sel_reg = '0' else RX_EOF_POS_IN;
        -- when TX->RX loopback is activated, assign this port to 0 because there is no point to send
        -- valid data when backpressure signal is disconnected
        TX_SRC_RDY_OUT <= TX_SRC_RDY_IN and (not tx2rx_loop_mux_sel_reg) when rx2tx_loop_mux_sel_reg = '0' else RX_SRC_RDY_IN;

        tx_mfb_dst_rdy_in_int <= TX_DST_RDY_OUT        when rx2tx_loop_mux_sel_reg = '0' else '1';
        TX_DST_RDY_IN         <= tx_mfb_dst_rdy_in_int when tx2rx_loop_mux_sel_reg = '0' else RX_DST_RDY_OUT;

    end generate;
end architecture;
