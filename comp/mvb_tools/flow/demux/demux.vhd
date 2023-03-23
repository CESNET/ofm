-- demux.vhd: General width item MVB DEMUX
-- Copyright (C) 2023 CESNET z. s. p. o.
-- Author(s): Oliver Gurka <xgurka00@stud.fit.vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause
--


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.math_pack.all;
use work.type_pack.all;

-- Multi-value bus item demultiplexer. For each item, there is a select signal,
-- which determines to which TX port the item will be transmitted.
-- Transaction on RX MVB is executed, when all ports, to which at least one item will be transmitted,
-- have DST_RDY asserted. Ports, which will not receive any item, do not have to have DST_RDY asserted.
entity GEN_MVB_DEMUX is
    generic (
        -- Any positive value
        MVB_ITEMS       : natural := 1;
        -- Any positive value
        DATA_WIDTH      : natural := 64;
        -- TX interfaces count
        DEMUX_WIDTH     : natural := 2;
        DEVICE          : string  := "7SERIES";

        -- When False, all RX_DATA are copied to TX_DATA signal,
        -- when True, RX_DATA are demultiplexed and other items
        -- are zeroed.
        DATA_DEMUX      : boolean := False
    );
    port (
        -- Clock signal
        CLK             : in    std_logic;
        -- Synchronous reset with CLK
        RESET           : in    std_logic;

        -- ================================================
        -- RX MVB interface
        --
        -- Receive MVB interface with items to demultiplex.
        -- ================================================

        -- This signal contains items, which will be demultiplexed
        RX_DATA         : in    std_logic_vector(MVB_ITEMS * DATA_WIDTH - 1 downto 0);
        -- This signal contains select signal for each item.
        RX_SEL          : in    std_logic_vector(MVB_ITEMS * max(1, log2(DEMUX_WIDTH)) - 1 downto 0);
        RX_VLD          : in    std_logic_vector(MVB_ITEMS - 1 downto 0);
        RX_SRC_RDY      : in    std_logic;
        RX_DST_RDY      : out   std_logic;

        -- ================================================
        -- TX MVB interfaces
        --
        -- DEMUX_WIDTH (amount) of transmit interfaces.
        -- ================================================

        -- This signal contains demultiplexed items.
        TX_DATA         : out   std_logic_vector(DEMUX_WIDTH * MVB_ITEMS * DATA_WIDTH - 1 downto 0);
        TX_VLD          : out   std_logic_vector(DEMUX_WIDTH * MVB_ITEMS - 1 downto 0);
        TX_SRC_RDY      : out   std_logic_vector(DEMUX_WIDTH - 1 downto 0);
        TX_DST_RDY      : in    std_logic_vector(DEMUX_WIDTH - 1 downto 0)
    );
end entity;

architecture behavioral of GEN_MVB_DEMUX is

    constant SEL_WIDTH          : natural := max(1, log2(DEMUX_WIDTH));

    signal rx_data_arr          : slv_array_t(MVB_ITEMS - 1 downto 0)(DATA_WIDTH - 1 downto 0);
    signal rx_sel_arr           : slv_array_t(MVB_ITEMS - 1 downto 0)(SEL_WIDTH - 1 downto 0);

    signal tx_data_2d_arr       : slv_array_2d_t(DEMUX_WIDTH - 1 downto 0)(MVB_ITEMS - 1 downto 0)(DATA_WIDTH - 1 downto 0);
    signal tx_data_arr          : slv_array_t(MVB_ITEMS - 1 downto 0)(DEMUX_WIDTH * DATA_WIDTH - 1 downto 0);
    signal tx_vld_2d_arr        : slv_array_2d_t(DEMUX_WIDTH - 1 downto 0)(MVB_ITEMS - 1 downto 0)(0 downto 0);
    signal tx_vld_arr           : slv_array_t(MVB_ITEMS - 1 downto 0)(DEMUX_WIDTH - 1 downto 0);

    signal tx_active_mvbs_i     : slv_array_t(MVB_ITEMS - 1 downto 0)(DEMUX_WIDTH - 1 downto 0);
    signal tx_active_mvbs       : std_logic_vector(DEMUX_WIDTH - 1 downto 0);
    signal tx_inactive_mvbs     : std_logic_vector(DEMUX_WIDTH - 1 downto 0);
    signal tx_active_drdy_arr   : std_logic_vector(DEMUX_WIDTH - 1 downto 0);
    signal tx_active_drdy       : std_logic;

    signal rx_data_all_int      : std_logic_vector(MVB_ITEMS * (DATA_WIDTH + SEL_WIDTH) - 1 downto 0);
    signal rx_data_int          : std_logic_vector(MVB_ITEMS * DATA_WIDTH - 1 downto 0);
    signal rx_sel_int           : std_logic_vector(MVB_ITEMS * SEL_WIDTH - 1 downto 0);
    signal rx_vld_int           : std_logic_vector(MVB_ITEMS - 1 downto 0);
    signal rx_src_rdy_int       : std_logic;
    signal rx_dst_rdy_int       : std_logic;

begin  -- architecture behavioral
    pipe_i : entity work.MVB_PIPE
    generic map (
        ITEMS       => MVB_ITEMS,
        ITEM_WIDTH  => DATA_WIDTH + SEL_WIDTH,
        DEVICE      => DEVICE
    ) port map (
        CLK         => CLK,
        RESET       => RESET,

        RX_DATA     => RX_SEL & RX_DATA,
        RX_VLD      => RX_VLD,
        RX_SRC_RDY  => RX_SRC_RDY,
        RX_DST_RDY  => RX_DST_RDY,

        TX_DATA     => rx_data_all_int,
        TX_VLD      => rx_vld_int,
        TX_SRC_RDY  => rx_src_rdy_int,
        TX_DST_RDY  => rx_dst_rdy_int
    );

    rx_data_int <= rx_data_all_int(MVB_ITEMS * DATA_WIDTH - 1 downto 0);
    rx_sel_int <= rx_data_all_int(MVB_ITEMS * (DATA_WIDTH + SEL_WIDTH) - 1 downto MVB_ITEMS * DATA_WIDTH);

    rx_sel_arr <= slv_array_deser(rx_sel_int, MVB_ITEMS);
    rx_data_arr <= slv_array_deser(rx_data_int, MVB_ITEMS);

    tx_active_dec_g : for i in 0 to MVB_ITEMS - 1 generate
    begin

        tx_active_dec_i : entity work.DEC1FN
        generic map (
            ITEMS   => DEMUX_WIDTH
        ) port map (
            ADDR    => rx_sel_arr(i),
            DO      => tx_active_mvbs_i(i)
        );

    end generate;

    tx_active_mvbs_p : process(all)
        variable tx_active_mvbs_v : std_logic_vector(DEMUX_WIDTH - 1 downto 0);
        variable tx_active_vld_v  : std_logic_vector(DEMUX_WIDTH - 1 downto 0);
    begin
        tx_active_mvbs_v := (others => '0');
        for i in 0 to MVB_ITEMS - 1 loop
            tx_active_vld_v := (others => rx_vld_int(i));
            tx_active_mvbs_v := tx_active_mvbs_v or (tx_active_mvbs_i(i) and tx_active_vld_v);
        end loop;  -- i
        tx_active_mvbs <= tx_active_mvbs_v;
    end process;

    tx_inactive_mvbs <= not tx_active_mvbs;

    data_demux_g : if DATA_DEMUX generate
        tx_item_sel_g : for i in 0 to MVB_ITEMS - 1 generate
        begin
            tx_item_mux_i : entity work.GEN_DEMUX
                generic map (
                    DATA_WIDTH  => DATA_WIDTH,
                    DEMUX_WIDTH => DEMUX_WIDTH
                ) port map (
                    DATA_IN     => rx_data_arr(i),
                    SEL         => rx_sel_arr(i),
                    DATA_OUT    => tx_data_arr(i)
                );
        end generate;

        tx_vld_assign_p : process(all)
        begin
            for i in 0 to MVB_ITEMS - 1 loop
                for j in 0 to DEMUX_WIDTH - 1 loop
                    tx_data_2d_arr(j)(i) <= tx_data_arr(i)((j+1) * DATA_WIDTH - 1 downto j * DATA_WIDTH);
                end loop;
            end loop;
        end process;
    end generate;

    not_data_demux_g : if not DATA_DEMUX generate
        tx_item_assign_g : for i in 0 to DEMUX_WIDTH - 1 generate
            tx_data_2d_arr(i) <= rx_data_arr;
        end generate;
    end generate;

    tx_vld_sel_g : for i in 0 to MVB_ITEMS - 1 generate
        signal tx_vld_mvb_out : std_logic_vector(DEMUX_WIDTH - 1 downto 0);
    begin
        tx_item_mux_i : entity work.GEN_DEMUX
        generic map (
            DATA_WIDTH  => 1,
            DEMUX_WIDTH => DEMUX_WIDTH
        ) port map (
            DATA_IN     => rx_vld_int(i downto i),
            SEL         => rx_sel_arr(i),
            DATA_OUT    => tx_vld_arr(i)
        );
    end generate;

    tx_vld_assign_p : process(all)
    begin
        for i in 0 to MVB_ITEMS - 1 loop
            for j in 0 to DEMUX_WIDTH - 1 loop
                tx_vld_2d_arr(j)(i)(0) <= tx_vld_arr(i)(j);
            end loop;
        end loop;
    end process;

    tx_active_drdy_arr <= tx_inactive_mvbs or TX_DST_RDY;
    rx_dst_rdy_int <= and(tx_active_drdy_arr);

    tx_src_rdy_g: for i in 0 to DEMUX_WIDTH - 1 generate
        TX_SRC_RDY(i) <= rx_src_rdy_int and tx_active_mvbs(i) and (and(tx_active_drdy_arr));
    end generate tx_src_rdy_g;

    TX_DATA <= slv_array_2d_ser(tx_data_2d_arr);
    TX_VLD <= slv_array_2d_ser(tx_vld_2d_arr);

end architecture behavioral;
