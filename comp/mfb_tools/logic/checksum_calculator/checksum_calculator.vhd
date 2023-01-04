-- checksum_calculator.vhd: A top-level component that can calculate the IPv4, TCP, or UDP checksum.
-- Copyright (C) 2022 CESNET z. s. p. o.
-- Author(s): Daniel Kondys <kondys@cesnet.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.math_pack.all;
use work.type_pack.all;


-- ============================================================================
--  Description
-- ============================================================================

-- This component calculates checksum for the IPv4, TCP, and UDP protocols.
-- Along with the frame data (from which the checksums are calculated), it
-- expects additional information (valid with SOF) as input. This includes the
-- length of the L2 header (i.e., the offset of the L3 header), length of the
-- L3 header (i.e., the offset of the L4 header), and flags (see
-- :vhdl:portsignal:`RX_FLAGS <checksum_calculator.rx_flags>` port).
--
entity CHECKSUM_CALCULATOR is
generic(
    -- Number of Regions within a data word, must be power of 2.
    MFB_REGIONS           : natural := 4;
    -- Region size (in Blocks).
    MFB_REGION_SIZE       : natural := 8;
    -- Block size (in Items).
    MFB_BLOCK_SIZE        : natural := 8;
    -- Item width (in bits), must be 8.
    MFB_ITEM_WIDTH        : natural := 8;

    -- FPGA device name.
    -- Options: ULTRASCALE, STRATIX10, AGILEX, ...
    DEVICE                : string := "STRATIX10"
);
port(
    -- ========================================================================
    -- Clock and Reset
    -- ========================================================================

    CLK              : in  std_logic;
    RESET            : in  std_logic;

    -- ========================================================================
    -- RX STREAM
    --
    -- #. Input packets (MFB),
    -- #. Meta information (header lengths, flags) valid with SOF.
    -- ========================================================================

    RX_MFB_DATA      : in  std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
    RX_MFB_SOF_POS   : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    RX_MFB_EOF_POS   : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    RX_MFB_SOF       : in  std_logic_vector(MFB_REGIONS-1 downto 0);
    RX_MFB_EOF       : in  std_logic_vector(MFB_REGIONS-1 downto 0);
    RX_MFB_SRC_RDY   : in  std_logic;
    RX_MFB_DST_RDY   : out std_logic;

    -- L3 header offset.
    RX_L2_HDR_LENGTH : in  std_logic_vector(MFB_REGIONS*7-1 downto 0);
    -- L4 header offset.
    RX_L3_HDR_LENGTH : in  std_logic_vector(MFB_REGIONS*9-1 downto 0);
    -- Flag items:
    --
    -- - RX_FLAGS[3]: L4 protocol, 1 = TCP, 0 = UDP
    -- - RX_FLAGS[2]: L3 protocol, 1 = IPv4, 0 = IPv6
    -- - RX_FLAGS[1]: TCP/UDP checksum enable
    -- - RX_FLAGS[0]: IPv4 checksum enable
    --
    RX_FLAGS         : in  std_logic_vector(MFB_REGIONS*4-1 downto 0);

    -- ========================================================================
    -- TX MVB STREAM
    --
    -- Calculated checksums.
    -- ========================================================================

    -- The calculated checksum.
    TX_L3_MVB_DATA     : out std_logic_vector(MFB_REGIONS*16-1 downto 0);
    -- Bypass checksum insertion (=> checksum caluculation is not desired).
    TX_L3_CHSUM_BYPASS : out std_logic_vector(MFB_REGIONS-1 downto 0);
    TX_L3_MVB_VLD      : out std_logic_vector(MFB_REGIONS-1 downto 0);
    TX_L3_MVB_SRC_RDY  : out std_logic := '0';
    TX_L3_MVB_DST_RDY  : in  std_logic := '1';

    -- The calculated checksum.
    TX_L4_MVB_DATA     : out std_logic_vector(MFB_REGIONS*16-1 downto 0);
    -- Bypass checksum insertion (=> checksum caluculation is not desired).
    TX_L4_CHSUM_BYPASS : out std_logic_vector(MFB_REGIONS-1 downto 0);
    TX_L4_MVB_VLD      : out std_logic_vector(MFB_REGIONS-1 downto 0);
    TX_L4_MVB_SRC_RDY  : out std_logic := '0';
    TX_L4_MVB_DST_RDY  : in  std_logic := '1'
);
end entity;

architecture FULL of CHECKSUM_CALCULATOR is

    -- ========================================================================
    --                                CONSTANTS
    -- ========================================================================

    constant L2_HDR_LENGTH_W : natural := 7;
    constant L3_HDR_LENGTH_W : natural := 9;

    constant CHECKSUM_W      : natural := 16;

    constant MFB_DATA_W       : natural := MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH;
    constant MFB_DATA_ITEMS   : natural := MFB_DATA_W/MFB_ITEM_WIDTH;
    constant MFB_REGION_ITEMS : natural := MFB_DATA_ITEMS/MFB_REGIONS;

    -- ========================================================================
    --                                 SIGNALS
    -- ========================================================================

    signal rx_flags_arr          : slv_array_t     (MFB_REGIONS-1 downto 0)(4-1 downto 0);
    signal l3_chs_en_flags       : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l4_chs_en_flags       : std_logic_vector(MFB_REGIONS-1 downto 0);

    -- checksum enable fifoxm signals
    signal chs_en_fifoxm_full    : std_logic;

    signal l3_chs_en_fifoxm_din   : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l3_chs_en_fifoxm_wr    : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l3_chs_en_fifoxm_full  : std_logic;
    signal l3_chs_en_fifoxm_dout  : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l3_chs_en_fifoxm_rd    : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l3_chs_en_fifoxm_empty : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l3_chs_en_fifoxm_vo    : std_logic_vector(MFB_REGIONS-1 downto 0);

    signal l4_chs_en_fifoxm_din   : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l4_chs_en_fifoxm_wr    : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l4_chs_en_fifoxm_full  : std_logic;
    signal l4_chs_en_fifoxm_dout  : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l4_chs_en_fifoxm_rd    : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l4_chs_en_fifoxm_empty : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l4_chs_en_fifoxm_out_rdy : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l4_chs_en_fifoxm_vo    : std_logic_vector(MFB_REGIONS-1 downto 0);

    -- input register
    signal rx_ext_data           : std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
    signal rx_ext_sof_pos        : std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    signal rx_ext_eof_pos        : std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    signal rx_ext_sof            : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal rx_ext_eof            : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal rx_ext_src_rdy        : std_logic;
    signal rx_ext_dst_rdy        : std_logic;
    signal rx_ext_l2_len         : std_logic_vector(MFB_REGIONS*7-1 downto 0);
    signal rx_ext_l3_len         : std_logic_vector(MFB_REGIONS*9-1 downto 0);

    -- Layer 3 checksum signals
    signal tx_l3_ext_data        : std_logic_vector(MFB_DATA_W-1 downto 0);
    signal tx_l3_ext_odd         : std_logic_vector(MFB_DATA_ITEMS-1 downto 0);
    signal tx_l3_ext_vld         : std_logic_vector(MFB_DATA_ITEMS-1 downto 0);
    signal tx_l3_ext_end         : std_logic_vector(MFB_DATA_ITEMS-1 downto 0);
    signal tx_l3_ext_src_rdy     : std_logic;
    signal tx_l3_ext_dst_rdy     : std_logic;

    signal rx_l3_rchsum_data     : slv_array_t     (MFB_REGIONS-1 downto 0)(MFB_DATA_W/MFB_REGIONS-1 downto 0);
    signal rx_l3_rchsum_odd      : slv_array_t     (MFB_REGIONS-1 downto 0)(MFB_REGION_ITEMS-1 downto 0);
    signal rx_l3_rchsum_end      : slv_array_t     (MFB_REGIONS-1 downto 0)(MFB_REGION_ITEMS-1 downto 0);
    signal rx_l3_rchsum_vld      : slv_array_t     (MFB_REGIONS-1 downto 0)(MFB_REGION_ITEMS-1 downto 0);
    signal rx_l3_rchsum_src_rdy  : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal rx_l3_rchsum_dst_rdy  : std_logic_vector(MFB_REGIONS-1 downto 0);

    signal tx_l3_rchsum_data     : slv_array_t     (MFB_REGIONS-1 downto 0)(2*CHECKSUM_W-1 downto 0);
    signal tx_l3_rchsum_end      : slv_array_t     (MFB_REGIONS-1 downto 0)(2-1 downto 0);
    signal tx_l3_rchsum_vld      : slv_array_t     (MFB_REGIONS-1 downto 0)(2-1 downto 0);
    signal tx_l3_rchsum_src_rdy  : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal tx_l3_rchsum_dst_rdy  : std_logic_vector(MFB_REGIONS-1 downto 0);

    signal rx_l3_fchsum_data     : std_logic_vector(MFB_REGIONS*2*CHECKSUM_W-1 downto 0);
    signal rx_l3_fchsum_end      : std_logic_vector(MFB_REGIONS*2-1 downto 0);
    signal rx_l3_fchsum_vld      : std_logic_vector(MFB_REGIONS*2-1 downto 0);
    signal rx_l3_fchsum_src_rdy  : std_logic;
    signal rx_l3_fchsum_dst_rdy  : std_logic;

    signal tx_l3_fchsum_data     : std_logic_vector(MFB_REGIONS*2*CHECKSUM_W-1 downto 0);
    signal tx_l3_fchsum_vld      : std_logic_vector(MFB_REGIONS*2-1 downto 0);
    signal tx_l3_fchsum_src_rdy  : std_logic;
    signal tx_l3_fchsum_dst_rdy  : std_logic;

    signal l3_fifoxm_datain      : std_logic_vector(MFB_REGIONS*2*CHECKSUM_W-1 downto 0);
    signal l3_fifoxm_wr          : std_logic_vector(MFB_REGIONS*2-1 downto 0);
    signal l3_fifoxm_full        : std_logic;

    signal l3_fifoxm_dataout     : std_logic_vector(MFB_REGIONS*CHECKSUM_W-1 downto 0);
    signal l3_fifoxm_rd          : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l3_fifoxm_empty       : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l3_fifoxm_vo          : std_logic_vector(MFB_REGIONS-1 downto 0);

    -- Layer 4 checksum signals
    signal tx_l4_ext_data        : std_logic_vector(MFB_DATA_W-1 downto 0);
    signal tx_l4_ext_odd         : std_logic_vector(MFB_DATA_ITEMS-1 downto 0);
    signal tx_l4_ext_vld         : std_logic_vector(MFB_DATA_ITEMS-1 downto 0);
    signal tx_l4_ext_end         : std_logic_vector(MFB_DATA_ITEMS-1 downto 0);
    signal tx_l4_ext_src_rdy     : std_logic;
    signal tx_l4_ext_dst_rdy     : std_logic;

    signal rx_l4_rchsum_data     : slv_array_t     (MFB_REGIONS-1 downto 0)(MFB_DATA_W/MFB_REGIONS-1 downto 0);
    signal rx_l4_rchsum_odd      : slv_array_t     (MFB_REGIONS-1 downto 0)(MFB_REGION_ITEMS-1 downto 0);
    signal rx_l4_rchsum_end      : slv_array_t     (MFB_REGIONS-1 downto 0)(MFB_REGION_ITEMS-1 downto 0);
    signal rx_l4_rchsum_vld      : slv_array_t     (MFB_REGIONS-1 downto 0)(MFB_REGION_ITEMS-1 downto 0);
    signal rx_l4_rchsum_src_rdy  : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal rx_l4_rchsum_dst_rdy  : std_logic_vector(MFB_REGIONS-1 downto 0);

    signal tx_l4_rchsum_data     : slv_array_t     (MFB_REGIONS-1 downto 0)(2*CHECKSUM_W-1 downto 0);
    signal tx_l4_rchsum_end      : slv_array_t     (MFB_REGIONS-1 downto 0)(2-1 downto 0);
    signal tx_l4_rchsum_vld      : slv_array_t     (MFB_REGIONS-1 downto 0)(2-1 downto 0);
    signal tx_l4_rchsum_src_rdy  : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal tx_l4_rchsum_dst_rdy  : std_logic_vector(MFB_REGIONS-1 downto 0);

    signal rx_l4_fchsum_data     : std_logic_vector(MFB_REGIONS*2*CHECKSUM_W-1 downto 0);
    signal rx_l4_fchsum_end      : std_logic_vector(MFB_REGIONS*2-1 downto 0);
    signal rx_l4_fchsum_vld      : std_logic_vector(MFB_REGIONS*2-1 downto 0);
    signal rx_l4_fchsum_src_rdy  : std_logic;
    signal rx_l4_fchsum_dst_rdy  : std_logic;

    signal tx_l4_fchsum_data     : std_logic_vector(MFB_REGIONS*2*CHECKSUM_W-1 downto 0);
    signal tx_l4_fchsum_vld      : std_logic_vector(MFB_REGIONS*2-1 downto 0);
    signal tx_l4_fchsum_src_rdy  : std_logic;
    signal tx_l4_fchsum_dst_rdy  : std_logic;

    signal l4_fifoxm_datain      : std_logic_vector(MFB_REGIONS*2*CHECKSUM_W-1 downto 0);
    signal l4_fifoxm_wr          : std_logic_vector(MFB_REGIONS*2-1 downto 0);
    signal l4_fifoxm_full        : std_logic;

    signal l4_fifoxm_dataout     : std_logic_vector(MFB_REGIONS*CHECKSUM_W-1 downto 0);
    signal l4_fifoxm_rd          : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l4_fifoxm_empty       : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l4_fifoxm_out_rdy     : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l4_fifoxm_vo          : std_logic_vector(MFB_REGIONS-1 downto 0);

begin

    RX_MFB_DST_RDY <= rx_ext_dst_rdy and not chs_en_fifoxm_full;

    -- ========================================================================
    --  Checksum enable flags synchronization
    -- ========================================================================

    rx_flags_arr <= slv_array_deser(RX_FLAGS, MFB_REGIONS);
    flags_g : for r in 0 to MFB_REGIONS-1 generate
        l3_chs_en_flags(r) <= rx_flags_arr(r)(0);
        l4_chs_en_flags(r) <= rx_flags_arr(r)(1);
    end generate;

    chs_en_fifoxm_full   <= l3_chs_en_fifoxm_full or l4_chs_en_fifoxm_full;

    -- L3
    l3_chs_en_fifoxm_din <= l3_chs_en_flags;
    l3_chs_en_fifoxm_wr  <= (RX_MFB_SOF and RX_MFB_SRC_RDY) and RX_MFB_DST_RDY;

    l3_chs_en_fifoxm_i : entity work.FIFOX_MULTI(shakedown)
    generic map(
        DATA_WIDTH          => 1,
        ITEMS               => 512,
        WRITE_PORTS         => MFB_REGIONS,
        READ_PORTS          => MFB_REGIONS,
        RAM_TYPE            => "AUTO",
        DEVICE              => DEVICE,
        ALMOST_FULL_OFFSET  => 0,
        ALMOST_EMPTY_OFFSET => 0,
        ALLOW_SINGLE_FIFO   => true,
        SAFE_READ_MODE      => false
    )
    port map(
        CLK   => CLK,
        RESET => RESET,

        DI    => l3_chs_en_fifoxm_din   ,
        WR    => l3_chs_en_fifoxm_wr    ,
        FULL  => l3_chs_en_fifoxm_full  ,
        AFULL => open                   ,

        DO     => l3_chs_en_fifoxm_dout ,
        RD     => l3_chs_en_fifoxm_rd   ,
        EMPTY  => l3_chs_en_fifoxm_empty,
        AEMPTY => open
    );

    -- valid out
    l3_chs_en_fifoxm_vo <= not l3_chs_en_fifoxm_empty;
    l3_chs_en_fifoxm_read_g : for r in 0 to MFB_REGIONS-1 generate
        l3_chs_en_fifoxm_rd(r) <= (and l3_chs_en_fifoxm_vo(r downto 0)) and (and l3_fifoxm_vo(r downto 0)) and TX_L3_MVB_DST_RDY;
    end generate;

    -- L4
    l4_chs_en_fifoxm_din <= l4_chs_en_flags;
    l4_chs_en_fifoxm_wr  <= (RX_MFB_SOF and RX_MFB_SRC_RDY) and RX_MFB_DST_RDY;

    l4_chs_en_fifoxm_i : entity work.FIFOX_MULTI(shakedown)
    generic map(
        DATA_WIDTH          => 1,
        ITEMS               => 512,
        WRITE_PORTS         => MFB_REGIONS,
        READ_PORTS          => MFB_REGIONS,
        RAM_TYPE            => "AUTO",
        DEVICE              => DEVICE,
        ALMOST_FULL_OFFSET  => 0,
        ALMOST_EMPTY_OFFSET => 0,
        ALLOW_SINGLE_FIFO   => true,
        SAFE_READ_MODE      => false
    )
    port map(
        CLK   => CLK,
        RESET => RESET,

        DI    => l4_chs_en_fifoxm_din   ,
        WR    => l4_chs_en_fifoxm_wr    ,
        FULL  => l4_chs_en_fifoxm_full  ,
        AFULL => open                   ,

        DO     => l4_chs_en_fifoxm_dout ,
        RD     => l4_chs_en_fifoxm_rd   ,
        EMPTY  => l4_chs_en_fifoxm_empty,
        AEMPTY => open
    );

    -- valid out
    l4_chs_en_fifoxm_vo <= not l4_chs_en_fifoxm_empty;
    l4_chs_en_fifoxm_read_g : for r in 0 to MFB_REGIONS-1 generate
        l4_chs_en_fifoxm_out_rdy(r) <= and l4_chs_en_fifoxm_vo(r downto 0);
        l4_chs_en_fifoxm_rd(r) <= l4_chs_en_fifoxm_out_rdy(r) and l4_fifoxm_out_rdy(r) and TX_L4_MVB_DST_RDY;
    end generate;

    process(clk)
    begin
        if rising_edge(clk) then
            if (TX_L4_MVB_SRC_RDY = '1') and (TX_L4_MVB_DST_RDY = '1') then
                assert (unsigned(l4_chs_en_fifoxm_rd) = unsigned(l4_fifoxm_rd)) report "ERROR: l4_chs_en_fifoxm_i" severity failure;
            end if;
        end if;
    end process;

    -- ========================================================================
    --  Input register
    -- ========================================================================

    process(CLK)
    begin
        if rising_edge(CLK) then
            if (rx_ext_dst_rdy = '1') then
                rx_ext_data      <= RX_MFB_DATA;
                rx_ext_sof_pos   <= RX_MFB_SOF_POS;
                rx_ext_eof_pos   <= RX_MFB_EOF_POS;
                rx_ext_sof       <= RX_MFB_SOF;
                rx_ext_eof       <= RX_MFB_EOF;
                rx_ext_src_rdy   <= RX_MFB_SRC_RDY and not chs_en_fifoxm_full;

                rx_ext_l2_len    <= RX_L2_HDR_LENGTH;
                rx_ext_l3_len    <= RX_L3_HDR_LENGTH;
            end if;

            if (RESET = '1') then
                rx_ext_src_rdy <= '0';
            end if;
        end if;
    end process;

    -- ========================================================================
    --  Checksum data extraction and validation
    -- ========================================================================

    chsum_data_ext_i : entity work.CHSUM_DATA_EXT
    generic map(
        MFB_REGIONS     => MFB_REGIONS    ,
        MFB_REGION_SIZE => MFB_REGION_SIZE,
        MFB_BLOCK_SIZE  => MFB_BLOCK_SIZE ,
        MFB_ITEM_WIDTH  => MFB_ITEM_WIDTH ,

        L2_HDR_LENGTH_W => L2_HDR_LENGTH_W,
        L3_HDR_LENGTH_W => L3_HDR_LENGTH_W
    )
    port map(
        CLK   => CLK,
        RESET => RESET,

        RX_MFB_DATA       => rx_ext_data   ,
        RX_MFB_SOF_POS    => rx_ext_sof_pos,
        RX_MFB_EOF_POS    => rx_ext_eof_pos,
        RX_MFB_SOF        => rx_ext_sof    ,
        RX_MFB_EOF        => rx_ext_eof    ,
        RX_MFB_SRC_RDY    => rx_ext_src_rdy,
        RX_MFB_DST_RDY    => rx_ext_dst_rdy,

        RX_L2_HDR_LENGTH  => rx_ext_l2_len,
        RX_L3_HDR_LENGTH  => rx_ext_l3_len,

        TX_L3_DATA    => tx_l3_ext_data,
        TX_L3_ODD     => tx_l3_ext_odd,
        TX_L3_END     => tx_l3_ext_end,
        TX_L3_VLD     => tx_l3_ext_vld,
        TX_L3_SRC_RDY => tx_l3_ext_src_rdy,
        TX_L3_DST_RDY => tx_l3_ext_dst_rdy,

        TX_L4_DATA    => tx_l4_ext_data,
        TX_L4_ODD     => tx_l4_ext_odd,
        TX_L4_END     => tx_l4_ext_end,
        TX_L4_VLD     => tx_l4_ext_vld,
        TX_L4_SRC_RDY => tx_l4_ext_src_rdy,
        TX_L4_DST_RDY => tx_l4_ext_dst_rdy
    );

    tx_l3_ext_dst_rdy <= and rx_l3_rchsum_dst_rdy;
    tx_l4_ext_dst_rdy <= and rx_l4_rchsum_dst_rdy;

    -- ========================================================================
    --  Layer 3
    -- ========================================================================

    -- --------------------------------
    -- Per-region checksum calculation
    -- --------------------------------

    rx_l3_rchsum_data <= slv_array_deser(tx_l3_ext_data, MFB_REGIONS);
    rx_l3_rchsum_odd  <= slv_array_deser(tx_l3_ext_odd , MFB_REGIONS);
    rx_l3_rchsum_end  <= slv_array_deser(tx_l3_ext_end , MFB_REGIONS);
    rx_l3_rchsum_vld  <= slv_array_deser(tx_l3_ext_vld , MFB_REGIONS);

    l3_chsum_regional_g : for r in 0 to MFB_REGIONS-1 generate

        rx_l3_rchsum_src_rdy(r) <= or rx_l3_rchsum_vld(r);

        l3_chsum_regional_i : entity work.CHSUM_REGIONAL
        generic map(
            ITEMS          => MFB_REGION_ITEMS,
            ITEM_WIDTH     => MFB_ITEM_WIDTH  ,
            CHECKSUM_WIDTH => CHECKSUM_W
        )
        port map(
            CLK   => CLK,
            RESET => RESET,

            RX_CHSUM_DATA => rx_l3_rchsum_data   (r),
            RX_CHSUM_ODD  => rx_l3_rchsum_odd    (r),
            RX_CHSUM_END  => rx_l3_rchsum_end    (r),
            RX_VALID      => rx_l3_rchsum_vld    (r),
            RX_SRC_RDY    => rx_l3_rchsum_src_rdy(r),
            RX_DST_RDY    => rx_l3_rchsum_dst_rdy(r),

            TX_CHSUM_REGION => tx_l3_rchsum_data   (r),
            TX_CHSUM_END    => tx_l3_rchsum_end    (r),
            TX_CHSUM_VLD    => tx_l3_rchsum_vld    (r),
            TX_SRC_RDY      => tx_l3_rchsum_src_rdy(r),
            TX_DST_RDY      => tx_l3_rchsum_dst_rdy(r)
        );

    end generate;

    tx_l3_rchsum_dst_rdy <= (others => rx_l4_fchsum_dst_rdy);

    -- --------------------------------
    -- Checksum calculation finalization
    -- --------------------------------

    rx_l3_fchsum_data    <= slv_array_ser(tx_l3_rchsum_data);
    -- rx_l3_fchsum_swap    <= not slv_array_ser(tx_l3_rchsum_meta); -- not odd
    rx_l3_fchsum_end     <= slv_array_ser(tx_l3_rchsum_end );
    rx_l3_fchsum_vld     <= slv_array_ser(tx_l3_rchsum_vld );
    rx_l3_fchsum_src_rdy <= or tx_l3_rchsum_src_rdy;

    l3_chsum_finalizer_i : entity work.CHSUM_FINALIZER
    generic map(
        REGIONS        => MFB_REGIONS,
        CHECKSUM_WIDTH => CHECKSUM_W
    )
    port map(
        CLK   => CLK,
        RESET => RESET,

        RX_CHSUM_REGION => rx_l3_fchsum_data   ,
        -- RX_SWAP_BYTES   => rx_l3_fchsum_swap   ,
        RX_CHSUM_END    => rx_l3_fchsum_end    ,
        RX_CHSUM_VLD    => rx_l3_fchsum_vld    ,
        RX_SRC_RDY      => rx_l3_fchsum_src_rdy,
        RX_DST_RDY      => rx_l3_fchsum_dst_rdy,

        TX_CHECKSUM => tx_l3_fchsum_data   ,
        TX_VALID    => tx_l3_fchsum_vld    ,
        TX_SRC_RDY  => tx_l3_fchsum_src_rdy,
        TX_DST_RDY  => tx_l3_fchsum_dst_rdy
    );

    -- --------------------------------
    -- Output FIFOX MULTI (shakedown)
    -- --------------------------------

    l3_fifoxm_datain <= tx_l3_fchsum_data;
    l3_fifoxm_wr     <= tx_l3_fchsum_vld and not l3_fifoxm_full;
    tx_l3_fchsum_dst_rdy <= not l3_fifoxm_full;

    l3_fifoxm_i : entity work.FIFOX_MULTI
    generic map(
        DATA_WIDTH          => CHECKSUM_W,
        ITEMS               => 512,
        WRITE_PORTS         => MFB_REGIONS*2,
        READ_PORTS          => MFB_REGIONS,
        RAM_TYPE            => "AUTO",
        DEVICE              => DEVICE,
        ALMOST_FULL_OFFSET  => 0,
        ALMOST_EMPTY_OFFSET => 0,
        ALLOW_SINGLE_FIFO   => true,
        SAFE_READ_MODE      => true
    )
    port map(
        CLK   => CLK,
        RESET => RESET,

        DI    => l3_fifoxm_datain,
        WR    => l3_fifoxm_wr    ,
        FULL  => l3_fifoxm_full  ,
        AFULL => open            ,

        DO     => l3_fifoxm_dataout,
        RD     => l3_fifoxm_rd     ,
        EMPTY  => l3_fifoxm_empty  ,
        AEMPTY => open
    );

    l3_fifoxm_vo <= not l3_fifoxm_empty;
    l3_fifoxm_dout_g : for r in 0 to MFB_REGIONS-1 generate
        l3_fifoxm_rd(r) <= (and l3_chs_en_fifoxm_vo(r downto 0)) and (and l3_fifoxm_vo(r downto 0)) and TX_L3_MVB_DST_RDY;
    end generate;

    -- ========================================================================
    --  Layer 4
    -- ========================================================================

    rx_l4_rchsum_data <= slv_array_deser(tx_l4_ext_data, MFB_REGIONS);
    rx_l4_rchsum_odd  <= slv_array_deser(tx_l4_ext_odd , MFB_REGIONS);
    rx_l4_rchsum_end  <= slv_array_deser(tx_l4_ext_end , MFB_REGIONS);
    rx_l4_rchsum_vld  <= slv_array_deser(tx_l4_ext_vld , MFB_REGIONS);

    l4_chsum_regional_g : for r in 0 to MFB_REGIONS-1 generate
        
        rx_l4_rchsum_src_rdy(r) <= or rx_l4_rchsum_vld(r);

        l4_chsum_regional_i : entity work.CHSUM_REGIONAL
        generic map(
            ITEMS          => MFB_REGION_ITEMS,
            ITEM_WIDTH     => MFB_ITEM_WIDTH  ,
            CHECKSUM_WIDTH => CHECKSUM_W
        )
        port map(
            CLK   => CLK,
            RESET => RESET,

            RX_CHSUM_DATA => rx_l4_rchsum_data   (r),
            RX_CHSUM_ODD  => rx_l4_rchsum_odd    (r),
            RX_CHSUM_END  => rx_l4_rchsum_end    (r),
            RX_VALID      => rx_l4_rchsum_vld    (r),
            RX_SRC_RDY    => rx_l4_rchsum_src_rdy(r),
            RX_DST_RDY    => rx_l4_rchsum_dst_rdy(r),

            TX_CHSUM_REGION => tx_l4_rchsum_data   (r),
            TX_CHSUM_END    => tx_l4_rchsum_end    (r),
            TX_CHSUM_VLD    => tx_l4_rchsum_vld    (r),
            TX_SRC_RDY      => tx_l4_rchsum_src_rdy(r),
            TX_DST_RDY      => tx_l4_rchsum_dst_rdy(r)
        );

    end generate;

    tx_l4_rchsum_dst_rdy <= (others => rx_l4_fchsum_dst_rdy);

    -- --------------------------------
    -- Checksum calculation finalization
    -- --------------------------------

    rx_l4_fchsum_data    <= slv_array_ser(tx_l4_rchsum_data);
    rx_l4_fchsum_end     <= slv_array_ser(tx_l4_rchsum_end );
    rx_l4_fchsum_vld     <= slv_array_ser(tx_l4_rchsum_vld );
    rx_l4_fchsum_src_rdy <= or tx_l4_rchsum_src_rdy;

    l4_chsum_finalizer_i : entity work.CHSUM_FINALIZER
    generic map(
        REGIONS        => MFB_REGIONS,
        CHECKSUM_WIDTH => CHECKSUM_W
    )
    port map(
        CLK   => CLK,
        RESET => RESET,

        RX_CHSUM_REGION => rx_l4_fchsum_data   ,
        RX_CHSUM_END    => rx_l4_fchsum_end    ,
        RX_CHSUM_VLD    => rx_l4_fchsum_vld    ,
        RX_SRC_RDY      => rx_l4_fchsum_src_rdy,
        RX_DST_RDY      => rx_l4_fchsum_dst_rdy,

        TX_CHECKSUM => tx_l4_fchsum_data   ,
        TX_VALID    => tx_l4_fchsum_vld    ,
        TX_SRC_RDY  => tx_l4_fchsum_src_rdy,
        TX_DST_RDY  => tx_l4_fchsum_dst_rdy
    );

    -- --------------------------------
    -- Output FIFOX MULTI (shakedown)
    -- --------------------------------

    l4_fifoxm_datain <= tx_l4_fchsum_data;
    l4_fifoxm_wr     <= tx_l4_fchsum_vld and not l4_fifoxm_full;
    tx_l4_fchsum_dst_rdy <= not l4_fifoxm_full;

    l4_fifoxm_i : entity work.FIFOX_MULTI
    generic map(
        DATA_WIDTH          => CHECKSUM_W,
        ITEMS               => 512,
        WRITE_PORTS         => MFB_REGIONS*2,
        READ_PORTS          => MFB_REGIONS,
        RAM_TYPE            => "AUTO",
        DEVICE              => DEVICE,
        ALMOST_FULL_OFFSET  => 0,
        ALMOST_EMPTY_OFFSET => 0,
        ALLOW_SINGLE_FIFO   => true,
        SAFE_READ_MODE      => false
    )
    port map(
        CLK   => CLK,
        RESET => RESET,

        DI    => l4_fifoxm_datain,
        WR    => l4_fifoxm_wr    ,
        FULL  => l4_fifoxm_full  ,
        AFULL => open            ,

        DO     => l4_fifoxm_dataout,
        RD     => l4_fifoxm_rd     ,
        EMPTY  => l4_fifoxm_empty  ,
        AEMPTY => open
    );

    -- valid out
    l4_fifoxm_vo <= not l4_fifoxm_empty;
    l4_fifoxm_dout_g : for r in 0 to MFB_REGIONS-1 generate
        l4_fifoxm_out_rdy(r) <= and l4_fifoxm_vo(r downto 0);
        l4_fifoxm_rd(r) <= l4_chs_en_fifoxm_out_rdy(r) and l4_fifoxm_out_rdy(r) and TX_L4_MVB_DST_RDY;
    end generate;

    -- ========================================================================
    -- Output assignment
    -- ========================================================================

    TX_L3_MVB_DATA     <= l3_fifoxm_dataout;
    TX_L3_CHSUM_BYPASS <= not l3_chs_en_fifoxm_dout;
    TX_L3_MVB_VLD      <= (not l3_fifoxm_empty) and (not l3_chs_en_fifoxm_empty);
    TX_L3_MVB_SRC_RDY  <= or ((not l3_fifoxm_empty) and (not l3_chs_en_fifoxm_empty));

    TX_L4_MVB_DATA     <= l4_fifoxm_dataout;
    TX_L4_CHSUM_BYPASS <= not l4_chs_en_fifoxm_dout;
    TX_L4_MVB_VLD      <= (not l4_fifoxm_empty) and (not l4_chs_en_fifoxm_empty);
    TX_L4_MVB_SRC_RDY  <= or ((not l4_fifoxm_empty) and (not l4_chs_en_fifoxm_empty));

end architecture;
