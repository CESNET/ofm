-- ptc_pcie2dma_hdr_transform_full.vhd: DMA to PCIe header transform for PTC component - architecture
-- Copyright (C) 2018 CESNET z. s. p. o.
-- Author(s): Jan Kubalek <xkubal11@stud.fit.vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.math_pack.all;
use work.type_pack.all;
use work.dma_bus_pack.all; -- contains definitions for DMA MVB header fields

-- ----------------------------------------------------------------------------
--                             Architecture
-- ----------------------------------------------------------------------------

architecture full of PTC_PCIE2DMA_HDR_TRANSFORM is

    ---------------------------------------------------------------------------
    -- Constants
    ---------------------------------------------------------------------------

    constant DMA_LEN_WIDTH : integer := DMA_COMPLETION_LENGTH'high+1-DMA_COMPLETION_LENGTH'low;

    ---------------------------------------------------------------------------

    ---------------------------------------------------------------------------
    -- Signals
    ---------------------------------------------------------------------------

    -- Input register
    signal rx_mvb_data_reg0     : std_logic_vector(MVB_ITEMS*PCIE_DOWNHDR_WIDTH-1 downto 0);
    signal rx_mvb_vld_reg0      : std_logic_vector(MVB_ITEMS-1 downto 0);

    -- Field selection from input headers
    signal rx_mvb_low_addr   : slv_array_t(MVB_ITEMS-1 downto 0)(PCIE_LOW_ADDR_WIDTH-1 downto 0);
    signal rx_mvb_len        : slv_array_t(MVB_ITEMS-1 downto 0)(DMA_COMPLETION_LENGTH);
    signal rx_mvb_pcie_tag   : slv_array_t(MVB_ITEMS-1 downto 0)(PCIE_TAG_WIDTH-1 downto 0);
    signal rx_mvb_complete   : std_logic_vector(MVB_ITEMS-1 downto 0);

    constant REMAINING_BYTES_WIDTH : natural := 12;
    signal rx_mvb_rem_bytes_vld : u_array_t(MVB_ITEMS-1 downto 0)(REMAINING_BYTES_WIDTH-1 downto 0);
    signal rx_mvb_rem_bytes_all : u_array_t(MVB_ITEMS-1 downto 0)(REMAINING_BYTES_WIDTH-1 downto 0);

    -- Registers for waiting to Tag manager response
    signal wait_mvb_len_reg0      : slv_array_t(MVB_ITEMS-1 downto 0)(DMA_COMPLETION_LENGTH);
    signal wait_mvb_complete_reg0 : std_logic_vector(MVB_ITEMS-1 downto 0);
    signal wait_mvb_reg0_vld      : std_logic_vector(MVB_ITEMS-1 downto 0);

    signal wait_mvb_len_reg1      : slv_array_t(MVB_ITEMS-1 downto 0)(DMA_COMPLETION_LENGTH);
    signal wait_mvb_complete_reg1 : std_logic_vector(MVB_ITEMS-1 downto 0);
    signal wait_mvb_reg1_vld      : std_logic_vector(MVB_ITEMS-1 downto 0);

    signal wait_mvb_len_reg2      : slv_array_t(MVB_ITEMS-1 downto 0)(DMA_COMPLETION_LENGTH);
    signal wait_mvb_complete_reg2 : std_logic_vector(MVB_ITEMS-1 downto 0);
    signal wait_mvb_reg2_vld      : std_logic_vector(MVB_ITEMS-1 downto 0);

    -- Output register
    signal out_mvb_len_reg      : slv_array_t(MVB_ITEMS-1 downto 0)(DMA_COMPLETION_LENGTH);
    signal out_mvb_complete_reg : std_logic_vector(MVB_ITEMS-1 downto 0);
    signal out_mvb_dma_tag_reg  : slv_array_t(MVB_ITEMS-1 downto 0)(DMA_TAG_WIDTH-1 downto 0);
    signal out_mvb_id_reg       : slv_array_t(MVB_ITEMS-1 downto 0)(DMA_ID_WIDTH -1 downto 0);
    signal out_mvb_reg_vld      : std_logic_vector(MVB_ITEMS-1 downto 0);

    ---------------------------------------------------------------------------

begin

    assert (DEVICE = "STRATIX10" OR DEVICE = "AGILEX" OR DEVICE = "ULTRASCALE" OR DEVICE = "7SERIES")
        report "PTC_PCIE2DMA_HDR_TRANSFORM: unsupported device!" severity failure;

    -- -------------------------------------------------------------------------
    -- Input MVB register for better timing
    -- -------------------------------------------------------------------------

    rx_mvb_reg_pr : process (CLK)
    begin
        if (rising_edge(CLK)) then
                rx_mvb_data_reg0 <= RX_MVB_DATA;
                rx_mvb_vld_reg0  <= RX_MVB_VLD and RX_MVB_SRC_RDY;
            if (RESET='1') then
                rx_mvb_vld_reg0 <= (others => '0');
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------

    -- -------------------------------------------------------------------------
    -- Selecting fields from RX headers; creating input to Tag manager
    -- -------------------------------------------------------------------------

    xilinx_header_tansform : if (DEVICE="ULTRASCALE" or DEVICE="7SERIES") generate
        rx_sel_gen : for i in 0 to MVB_ITEMS-1 generate

            rx_mvb_low_addr(i) <= rx_mvb_data_reg0(PCIE_DOWNHDR_WIDTH*i   +PCIE_LOW_ADDR_WIDTH-1 downto PCIE_DOWNHDR_WIDTH*i   );
            rx_mvb_len     (i) <= rx_mvb_data_reg0(PCIE_DOWNHDR_WIDTH*i+32+11                 -1 downto PCIE_DOWNHDR_WIDTH*i+32);
            rx_mvb_pcie_tag(i) <= rx_mvb_data_reg0(PCIE_DOWNHDR_WIDTH*i+64+PCIE_TAG_WIDTH     -1 downto PCIE_DOWNHDR_WIDTH*i+64);
            rx_mvb_complete(i) <= rx_mvb_data_reg0(PCIE_DOWNHDR_WIDTH*i+30);

        end generate;
    end generate;

    intel_header_tansform : if (DEVICE="STRATIX10" or DEVICE="AGILEX") generate
        rx_sel_gen : for i in 0 to MVB_ITEMS-1 generate

            rx_mvb_low_addr(i) <=       rx_mvb_data_reg0(PCIE_DOWNHDR_WIDTH*i+PCIE_LOW_ADDR_WIDTH+64-1 downto PCIE_DOWNHDR_WIDTH*i+64);
            rx_mvb_len     (i) <= "0" & rx_mvb_data_reg0(PCIE_DOWNHDR_WIDTH*i+10                    -1 downto PCIE_DOWNHDR_WIDTH*i   );

            -- Numer of remaining VALID bytes (according to request BE)
            rx_mvb_rem_bytes_vld(i) <= unsigned(rx_mvb_data_reg0(PCIE_DOWNHDR_WIDTH*i+REMAINING_BYTES_WIDTH+32-1 downto PCIE_DOWNHDR_WIDTH*i+32));
            -- Numer of remaining bytes (including those disabled by request BE)
            rx_mvb_rem_bytes_all(i) <= round_up(rx_mvb_rem_bytes_vld(i)+unsigned(rx_mvb_low_addr(i)(2-1 downto 0)),log2(4));

            --                    '1' when (dword count in all remaining completion parts (including bytes disabled by BE))=(              dword count in this completion part                 ) else '0';
            rx_mvb_complete(i) <= '1' when (  std_logic_vector(rx_mvb_rem_bytes_all(i)(REMAINING_BYTES_WIDTH-1 downto 2)) )=(rx_mvb_data_reg0(PCIE_DOWNHDR_WIDTH*i+10-1 downto PCIE_DOWNHDR_WIDTH*i)) else '0';

        end generate;

        -- In case of 10-bit Tag, the Tag must be extracted from 3 different places in the header
        pcie_tag_pr : process (rx_mvb_data_reg0)
            variable tag_low : std_logic_vector(8-1 downto 0);
            variable tag_8   : std_logic;
            variable tag_9   : std_logic;
        begin
            for i in 0 to MVB_ITEMS-1 loop
                tag_low := rx_mvb_data_reg0(PCIE_DOWNHDR_WIDTH*i+8+72-1 downto PCIE_DOWNHDR_WIDTH*i+72);
                tag_8   := rx_mvb_data_reg0(PCIE_DOWNHDR_WIDTH*i+19);
                tag_9   := rx_mvb_data_reg0(PCIE_DOWNHDR_WIDTH*i+23);

                if (PCIE_TAG_WIDTH=10) then
                     rx_mvb_pcie_tag(i) <= tag_9 & tag_8 & tag_low;
                else
                     rx_mvb_pcie_tag(i) <= std_logic_vector(resize_left(unsigned(tag_low),PCIE_TAG_WIDTH));
                end if;
            end loop;
        end process;

    end generate;

    rx_sel_gen : for i in 0 to MVB_ITEMS-1 generate
        tag_rel_reg_pr : process (CLK)
        begin
            if (CLK'event and CLK='1') then
                for i in 0 to MVB_ITEMS-1 loop
                    TAG(PCIE_TAG_WIDTH*(i+1)-1 downto PCIE_TAG_WIDTH*i)                          <= rx_mvb_pcie_tag(i);
                    TAG_COMPL_LOW_ADDR(PCIE_LOW_ADDR_WIDTH*(i+1)-1 downto PCIE_LOW_ADDR_WIDTH*i) <= rx_mvb_low_addr(i);
                    TAG_COMPL_LEN(DMA_LEN_WIDTH*(i+1)-1 downto DMA_LEN_WIDTH*i)                  <= rx_mvb_len(i);
                    TAG_RELEASE(i)                                                               <= rx_mvb_complete(i) and rx_mvb_vld_reg0(i);
                    TAG_VLD(i)                                                                   <= rx_mvb_vld_reg0(i);
                end loop;
            end if;
        end process;
    end generate;

    -- -------------------------------------------------------------------------

    -- -------------------------------------------------------------------------
    -- Wait for Tag manager response register
    -- -------------------------------------------------------------------------

    wait_reg_pr : process (CLK)
    begin
        if (CLK'event and CLK='1') then
            for i in 0 to MVB_ITEMS-1 loop
                wait_mvb_reg0_vld     (i) <= rx_mvb_vld_reg0(i);
                wait_mvb_len_reg0     (i) <= rx_mvb_len(i);
                wait_mvb_complete_reg0(i) <= rx_mvb_complete(i);

                wait_mvb_reg1_vld     (i) <= wait_mvb_reg0_vld(i);
                wait_mvb_len_reg1     (i) <= wait_mvb_len_reg0(i);
                wait_mvb_complete_reg1(i) <= wait_mvb_complete_reg0(i);

                wait_mvb_reg2_vld     (i) <= wait_mvb_reg1_vld(i);
                wait_mvb_len_reg2     (i) <= wait_mvb_len_reg1(i);
                wait_mvb_complete_reg2(i) <= wait_mvb_complete_reg1(i);
            end loop;

            if (RESET='1') then
                wait_mvb_reg0_vld <= (others => '0');
                wait_mvb_reg1_vld <= (others => '0');
                wait_mvb_reg2_vld <= (others => '0');
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------

    -- -------------------------------------------------------------------------
    -- Output register
    -- -------------------------------------------------------------------------

    out_reg_pr : process (CLK)
    begin
        if (CLK'event and CLK='1') then
            for i in 0 to MVB_ITEMS-1 loop
                out_mvb_reg_vld     (i) <= wait_mvb_reg2_vld(i);
                out_mvb_len_reg     (i) <= wait_mvb_len_reg2(i);
                out_mvb_complete_reg(i) <= wait_mvb_complete_reg2(i);
                out_mvb_dma_tag_reg (i) <= DMA_DOWN_HDR_TAG(DMA_TAG_WIDTH*(i+1)-1 downto DMA_TAG_WIDTH*i);
                out_mvb_id_reg      (i) <= DMA_DOWN_HDR_ID(DMA_ID_WIDTH*(i+1)-1 downto DMA_ID_WIDTH*i);
            end loop;

            if (RESET='1') then
                out_mvb_reg_vld <= (others => '0');
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------

    -- -------------------------------------------------------------------------
    -- Output generation
    -- -------------------------------------------------------------------------

    tx_gen : for i in 0 to MVB_ITEMS-1 generate
        TX_MVB_DATA(DMA_DOWNHDR_WIDTH*i+DMA_COMPLETION_LENGTH'low+DMA_LEN_WIDTH-1 downto DMA_DOWNHDR_WIDTH*i+DMA_COMPLETION_LENGTH'low) <= out_mvb_len_reg(i);
        TX_MVB_DATA(DMA_DOWNHDR_WIDTH*i+DMA_COMPLETION_COMPLETED'low) <= out_mvb_complete_reg(i);
        TX_MVB_DATA(DMA_DOWNHDR_WIDTH*i+DMA_COMPLETION_TAG'low+DMA_TAG_WIDTH-1 downto DMA_DOWNHDR_WIDTH*i+DMA_COMPLETION_TAG'low) <= out_mvb_dma_tag_reg(i);
        TX_MVB_DATA(DMA_DOWNHDR_WIDTH*i+DMA_COMPLETION_UNITID'low+DMA_ID_WIDTH-1 downto DMA_DOWNHDR_WIDTH*i+DMA_COMPLETION_UNITID'low) <= out_mvb_id_reg(i);

        TX_MVB_VLD(i) <= out_mvb_reg_vld(i);
    end generate;

    TX_MVB_SRC_RDY <= (or out_mvb_reg_vld);

    -- -------------------------------------------------------------------------

end architecture;
