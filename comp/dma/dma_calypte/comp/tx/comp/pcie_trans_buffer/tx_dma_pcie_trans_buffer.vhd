-- tx_dma_pcie_trans_buffer.vhd: this is a specially made component to buffer PCIe transactions
-- Copyright (C) 2023 CESNET z.s.p.o.
-- Author(s): Vladislav Valek  <xvalek14@vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Note:

use work.math_pack.all;
use work.type_pack.all;

entity TX_DMA_PCIE_TRANS_BUFFER is
    generic (
        DEVICE : string := "ULTRASCALE";

        -- Total number of DMA Channels within this DMA Endpoint
        CHANNELS : natural := 8;

        -- =========================================================================================
        -- Input PCIe interface parameters
        -- =========================================================================================
        MFB_REGIONS     : natural := 1;
        MFB_REGION_SIZE : natural := 1;
        MFB_BLOCK_SIZE  : natural := 8;
        MFB_ITEM_WIDTH  : natural := 32;

        -- determines the number of bytes that can be stored in the buffer
        POINTER_WIDTH : natural := 16);
    port (
        CLK   : in std_logic;
        RESET : in std_logic;

        PCIE_MFB_DATA    : in  std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
        PCIE_MFB_META    : in  std_logic_vector((MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH)/8+log2(CHANNELS)+62+1-1 downto 0);
        PCIE_MFB_SOF     : in  std_logic_vector(MFB_REGIONS -1 downto 0);
        PCIE_MFB_EOF     : in  std_logic_vector(MFB_REGIONS -1 downto 0);
        PCIE_MFB_SOF_POS : in  std_logic_vector(MFB_REGIONS*max(1, log2(MFB_REGION_SIZE)) -1 downto 0);
        PCIE_MFB_EOF_POS : in  std_logic_vector(MFB_REGIONS*max(1, log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE)) -1 downto 0);
        PCIE_MFB_SRC_RDY : in  std_logic;
        PCIE_MFB_DST_RDY : out std_logic := '1';

        RD_CHAN : in  std_logic_vector(log2(CHANNELS) -1 downto 0);
        RD_DATA : out std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
        RD_ADDR : in  std_logic_vector(POINTER_WIDTH -1 downto 0);
        RD_EN   : in  std_logic);
end entity;

architecture FULL of TX_DMA_PCIE_TRANS_BUFFER is

    constant MFB_LENGTH   : natural := MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH;
    constant BUFFER_DEPTH : natural := (2**POINTER_WIDTH)/(MFB_LENGTH/8);

    -- =============================================================================================
    -- Defining ranges for meta signal
    -- =============================================================================================
    constant META_IS_DMA_HDR_W : natural := 1;
    constant META_PCIE_ADDR_W  : natural := 62;
    constant META_CHAN_NUM_W   : natural := log2(CHANNELS);
    constant META_BE_W         : natural := MFB_LENGTH/8;

    constant META_IS_DMA_HDR_O : natural := 0;
    constant META_PCIE_ADDR_O  : natural := META_IS_DMA_HDR_O + META_IS_DMA_HDR_W;
    constant META_CHAN_NUM_O   : natural := META_PCIE_ADDR_O + META_PCIE_ADDR_W;
    constant META_BE_O         : natural := META_CHAN_NUM_O + META_CHAN_NUM_W;

    subtype META_IS_DMA_HDR is natural range META_IS_DMA_HDR_O + META_IS_DMA_HDR_W -1 downto META_IS_DMA_HDR_O;
    subtype META_PCIE_ADDR is natural range META_PCIE_ADDR_O + META_PCIE_ADDR_W -1 downto META_PCIE_ADDR_O;
    subtype META_CHAN_NUM is natural range META_CHAN_NUM_O + META_CHAN_NUM_W -1 downto META_CHAN_NUM_O;
    subtype META_BE is natural range META_BE_O + META_BE_W -1 downto META_BE_O;

    -- counter of the address for each valid word following the beginning of the transaction
    signal addr_cntr_pst : unsigned(PCIE_MFB_META(META_PCIE_ADDR)'length -1 downto 0);
    signal addr_cntr_nst : unsigned(PCIE_MFB_META(META_PCIE_ADDR)'length -1 downto 0);

    -- control of the amount of shift on the writing barrel shifters
    signal wr_shift_sel : std_logic_vector(log2(MFB_LENGTH/32) -1 downto 0);

    signal wr_be_bram_bshifter   : std_logic_vector((PCIE_MFB_DATA'length/8) -1 downto 0);
    signal wr_be_bram_demux      : slv_array_t(CHANNELS -1 downto 0)((PCIE_MFB_DATA'length/8) -1 downto 0);
    signal wr_addr_bram_by_shift : slv_array_t((PCIE_MFB_DATA'length/32) -1 downto 0)(log2(BUFFER_DEPTH) -1 downto 0);
    signal wr_data_bram_bshifter : std_logic_vector(MFB_LENGTH -1 downto 0);

    signal chan_num_pst : std_logic_vector(log2(CHANNELS) -1 downto 0);
    signal chan_num_nst : std_logic_vector(log2(CHANNELS) -1 downto 0);

    signal rd_en_bram_demux   : std_logic_vector(CHANNELS -1 downto 0);
    signal rd_data_bram_mux   : std_logic_vector(MFB_LENGTH -1 downto 0);
    signal rd_data_bram       : slv_array_t(CHANNELS -1 downto 0)(MFB_LENGTH -1 downto 0);
    signal rd_addr_bram_by_shift : slv_array_t((PCIE_MFB_DATA'length/8) -1 downto 0)(log2(BUFFER_DEPTH) -1 downto 0);
begin

    addr_cntr_reg_p : process (CLK) is
    begin
        if (rising_edge(CLK)) then
            if (RESET = '1') then
                addr_cntr_pst <= (others => '0');
            else
                addr_cntr_pst <= addr_cntr_nst;
            end if;
        end if;
    end process;

    addr_cntr_nst_logic_p : process (all) is
    begin
        addr_cntr_nst <= addr_cntr_pst;

        -- Increment the address for a next word by 8 (the number of DWs in the word) to be written
        -- to the BRAMs.
        if (PCIE_MFB_SRC_RDY = '1') then
            if (PCIE_MFB_SOF = "1" and PCIE_MFB_EOF = "0") then
                addr_cntr_nst <= unsigned(PCIE_MFB_META(META_PCIE_ADDR)) + 8;
            elsif (PCIE_MFB_SOF = "0" and PCIE_MFB_EOF = "0") then
                addr_cntr_nst <= addr_cntr_pst + 8;
            end if;
        end if;
    end process;

    -- This process controls the shift of the input word and the corresponding byte enable signal to
    -- it. When beginning of a transaction is captured, the shift is taken directly from the current
    -- address, but when it continues, then select shift from the counter of addresses.
    wr_bshifter_ctrl_p : process (all) is
        variable pcie_mfb_meta_addr_v : std_logic_vector(META_PCIE_ADDR_W -1 downto 0);
    begin
        wr_shift_sel <= (others => '0');

        if (PCIE_MFB_SRC_RDY = '1') then
            if (PCIE_MFB_SOF = "1") then
                pcie_mfb_meta_addr_v := PCIE_MFB_META(META_PCIE_ADDR);
                wr_shift_sel         <= pcie_mfb_meta_addr_v(2 downto 0);
            else
                wr_shift_sel <= std_logic_vector(addr_cntr_pst(2 downto 0));
            end if;
        end if;
    end process;

    wr_data_barrel_shifter_i : entity work.BARREL_SHIFTER_GEN
        generic map (
            BLOCKS     => 8,
            BLOCK_SIZE => 32,
            SHIFT_LEFT => TRUE)
        port map (
            DATA_IN  => PCIE_MFB_DATA,
            DATA_OUT => wr_data_bram_bshifter,
            SEL      => wr_shift_sel);

    wr_be_barrel_shifter_i : entity work.BARREL_SHIFTER_GEN
        generic map (
            BLOCKS     => 8,
            BLOCK_SIZE => 4,
            SHIFT_LEFT => TRUE)
        port map (
            DATA_IN  => PCIE_MFB_META(META_BE),
            DATA_OUT => wr_be_bram_bshifter,
            SEL      => wr_shift_sel);

    -- This process oncrements the address on the lowest DWords when shift occurs. That means that
    -- when data are shifted on the input, the rotation causes higher DWs to appear on the lower
    -- positions. Writing on the same address could cause the overwrite of data already stored in
    -- lower BRAMs.
    wr_addr_recalc_p : process (all) is
        variable pcie_mfb_meta_addr_v : std_logic_vector(META_PCIE_ADDR_W -1 downto 0);
    begin
        wr_addr_bram_by_shift <= (others => (others => '0'));

        if (PCIE_MFB_SRC_RDY = '1') then
            if (PCIE_MFB_SOF = "1") then
                pcie_mfb_meta_addr_v := PCIE_MFB_META(META_PCIE_ADDR);
                wr_addr_bram_by_shift <= (others => pcie_mfb_meta_addr_v(log2(BUFFER_DEPTH)+3 -1 downto 3));

                for i in 0 to ((MFB_LENGTH/32) -1) loop
                    if (i < unsigned(pcie_mfb_meta_addr_v(2 downto 0))) then
                        wr_addr_bram_by_shift(i) <= std_logic_vector(unsigned(pcie_mfb_meta_addr_v(log2(BUFFER_DEPTH)+3 -1 downto 3)) + 1);
                    end if;
                end loop;
            else
                wr_addr_bram_by_shift <= (others => std_logic_vector(addr_cntr_pst(log2(BUFFER_DEPTH)+3 -1 downto 3)));

                for i in 0 to ((MFB_LENGTH/32) -1) loop
                    if (i < addr_cntr_pst(2 downto 0)) then
                        wr_addr_bram_by_shift(i) <= std_logic_vector(addr_cntr_pst(log2(BUFFER_DEPTH)+3 -1 downto 3) + 1);
                    end if;
                end loop;
            end if;
        end if;
    end process;

    -- =============================================================================================
    -- Demultiplexers
    -- =============================================================================================
    chan_num_hold_reg_p : process (CLK) is
    begin
        if (rising_edge(CLK)) then
            if (RESET = '1') then
                chan_num_pst <= (others => '0');
            else
                chan_num_pst <= chan_num_nst;
            end if;
        end if;
    end process;

    -- this FSM stores the number of a channel in order to properly steer the demultiplexers
    chan_num_hold_nst_logic_p : process (all) is
    begin
        chan_num_nst <= chan_num_pst;

        if (PCIE_MFB_SRC_RDY = '1' and PCIE_MFB_SOF = "1") then
            chan_num_nst <= PCIE_MFB_META(META_CHAN_NUM);
        end if;
    end process;

    wr_bram_data_demux_p : process (all) is
    begin
        wr_be_bram_demux <= (others => (others => '0'));

        if (PCIE_MFB_SRC_RDY = '1') then
            if (PCIE_MFB_SOF = "1") then
                wr_be_bram_demux(to_integer(unsigned(PCIE_MFB_META(META_CHAN_NUM)))) <= wr_be_bram_bshifter;
            else
                wr_be_bram_demux(to_integer(unsigned(chan_num_pst))) <= wr_be_bram_bshifter;
            end if;
        end if;
    end process;

    brams_for_channels_g : for j in 0 to (CHANNELS -1) generate
        sdp_bram_be_g : for i in 0 to ((MFB_LENGTH/8) -1) generate
            sdp_bram_be_i : entity work.SDP_BRAM_BE
                generic map (
                    BLOCK_ENABLE   => false,
                    -- allow individual bytes to be assigned
                    BLOCK_WIDTH    => 8,
                    -- each BRAM allows to write a single DW
                    DATA_WIDTH     => 8,
                    -- the depth of the buffer
                    ITEMS          => BUFFER_DEPTH,
                    COMMON_CLOCK   => TRUE,
                    OUTPUT_REG     => FALSE,
                    METADATA_WIDTH => 0,
                    DEVICE         => DEVICE)
                port map (
                    WR_CLK  => CLK,
                    WR_RST  => RESET,
                    WR_EN   => wr_be_bram_demux(j)(i),
                    WR_BE   => (others => '1'),
                    WR_ADDR => wr_addr_bram_by_shift(i/4),
                    WR_DATA => wr_data_bram_bshifter(i*8 +7 downto i*8),

                    RD_CLK      => CLK,
                    RD_RST      => RESET,
                    RD_EN       => '1',
                    RD_PIPE_EN  => rd_en_bram_demux(j),
                    RD_META_IN  => (others => '0'),
                    RD_ADDR     => rd_addr_bram_by_shift(i),
                    RD_DATA     => rd_data_bram(j)(i*8 +7 downto i*8),
                    RD_META_OUT => open,
                    RD_DATA_VLD => open);
        end generate;
    end generate;

    rd_en_demux : process (all) is
    begin
        rd_en_bram_demux <= (others => '0');

        if (RD_EN = '1') then
            rd_en_bram_demux(to_integer(unsigned(RD_CHAN))) <= '1';
        end if;
    end process;

    rd_data_bram_mux <= rd_data_bram(to_integer(unsigned(RD_CHAN)));

    -- The Reading side is addressable by bytes so the number of blocks is 4 times more than on the
    -- reading side
    rd_data_barrel_shifter_i : entity work.BARREL_SHIFTER_GEN
        generic map (
            BLOCKS     => 32,
            BLOCK_SIZE => 8,
            SHIFT_LEFT => FALSE)
        port map (
            DATA_IN  => rd_data_bram_mux,
            DATA_OUT => RD_DATA,
            SEL      => RD_ADDR(4 downto 0));

    rd_addr_recalc_p : process (all) is
    begin
        rd_addr_bram_by_shift <= (others => RD_ADDR(log2(BUFFER_DEPTH)+5 -1 downto 5));

        for i in 0 to ((MFB_LENGTH/8) -1) loop
            if (i < unsigned(RD_ADDR(4 downto 0))) then
                rd_addr_bram_by_shift(i) <= std_logic_vector(unsigned(RD_ADDR(log2(BUFFER_DEPTH)+5 -1 downto 5)) + 1);
            end if;
        end loop;
    end process;
end architecture;
