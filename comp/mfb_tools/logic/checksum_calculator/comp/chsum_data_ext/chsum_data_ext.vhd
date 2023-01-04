-- chsum_data_ext.vhd: A component that extracts data for checksum calculation.
-- Copyright (C) 2022 CESNET z. s. p. o.
-- Author(s): Daniel Kondys <kondys@cesnet.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.type_pack.all;
use work.math_pack.all;


-- ============================================================================
--  Description
-- ============================================================================

-- 
entity CHSUM_DATA_EXT is
generic(
    -- Number of Regions within a data word, must be power of 2.
    MFB_REGIONS           : natural := 4;
    -- Region size (in Blocks).
    MFB_REGION_SIZE       : natural := 8;
    -- Block size (in Items).
    MFB_BLOCK_SIZE        : natural := 8;
    -- Item width (in bits), must be 8.
    MFB_ITEM_WIDTH        : natural := 8;

    -- Length of the L2_LENGTH signal (in bits).
    L2_HDR_LENGTH_W       : natural := 7;
    -- Length of the L3_LENGTH signal (in bits).
    L3_HDR_LENGTH_W       : natural := 9
);
port(
    -- ========================================================================
    -- Clock and Reset
    -- ========================================================================

    CLK              : in  std_logic;
    RESET            : in  std_logic;

    -- ========================================================================
    -- RX MFB STREAM
    --
    -- #. Input packets (MFB),
    -- #. Meta information (header lengths).
    -- ========================================================================

    RX_MFB_DATA      : in  std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
    RX_MFB_SOF_POS   : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    RX_MFB_EOF_POS   : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    RX_MFB_SOF       : in  std_logic_vector(MFB_REGIONS-1 downto 0);
    RX_MFB_EOF       : in  std_logic_vector(MFB_REGIONS-1 downto 0);
    RX_MFB_SRC_RDY   : in  std_logic;
    RX_MFB_DST_RDY   : out std_logic;

    -- Length of the L2 header (in Items), valid with SOF.
    RX_L2_HDR_LENGTH : in  std_logic_vector(MFB_REGIONS*L2_HDR_LENGTH_W-1 downto 0);
    -- Length of the L3 header (in Items), valid with SOF.
    RX_L3_HDR_LENGTH : in  std_logic_vector(MFB_REGIONS*L3_HDR_LENGTH_W-1 downto 0);

    -- ========================================================================
    -- TX MVB STREAM
    --
    -- Extracted and validated data.
    -- ========================================================================

    -- Extracted data for the checksum calculation.
    TX_L3_DATA       : out std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
    -- Indicates whether the data begin on an odd Item or not - valid with End.
    TX_L3_ODD        : out std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE-1 downto 0);
    -- Indicates the last item of valid checksum data.
    TX_L3_END        : out std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE-1 downto 0);
    -- Valid per each Item.
    TX_L3_VLD        : out std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE-1 downto 0);
    TX_L3_SRC_RDY    : out std_logic := '0';
    TX_L3_DST_RDY    : in  std_logic;

    -- Extracted data for the checksum calculation.
    TX_L4_DATA       : out std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
    -- Indicates whether the data begin on an odd Item or not - valid with End.
    TX_L4_ODD        : out std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE-1 downto 0);
    -- Indicates the last item of valid checksum data.
    TX_L4_END        : out std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE-1 downto 0);
    -- Valid per each Item.
    TX_L4_VLD        : out std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE-1 downto 0);
    TX_L4_SRC_RDY    : out std_logic := '0';
    TX_L4_DST_RDY    : in  std_logic
);
end entity;

architecture FULL of CHSUM_DATA_EXT is

    -- ========================================================================
    --                           FUNCTION DECLARATIONS
    -- ========================================================================

   function or_slv_array(slv_array : slv_array_t; items : integer) return std_logic_vector;
   function or_u_array(u_array : u_array_t; items : integer) return unsigned;
   function int_odd(int : integer) return std_logic;

    -- ========================================================================
    --                                CONSTANTS
    -- ========================================================================

    -- MFB data width.
    constant MFB_DATA_W     : natural := MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH;
    constant MFB_REGION_W   : natural := MFB_DATA_W/MFB_REGIONS;
    constant MFB_DATA_ITEMS : natural := MFB_DATA_W/MFB_ITEM_WIDTH;

    constant MVB_ITEMS      : natural := MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE;
    -- MVB Item width.
    constant MVB_ITEM_WIDTH : natural := MFB_ITEM_WIDTH;
    
    -- SOF POS width (for one Region).
    constant SOF_POS_W      : natural := max(1,log2(MFB_REGION_SIZE));
    -- SOF POS width (for the whole word).
    constant SOF_POS_WORD_W : natural := log2(MFB_REGIONS) + SOF_POS_W;
    -- SOF POS width (for the whole word and in Items).
    constant SOF_POS_WORD_ITEMS_W : natural := SOF_POS_WORD_W + log2(MFB_BLOCK_SIZE);

    -- Width of the RX EOF POS signals.
    constant EOF_POS_W      : natural := max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE));

    -- L3 constants
    constant L2_EOF_POS_LONG_W : natural := max(log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE), L2_HDR_LENGTH_W) + 1;
    constant L3_SOF_POS_LONG_W : natural := max(log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE), L2_HDR_LENGTH_W) + 1;

    constant L3_TARGET_WORD_W  : natural := L3_SOF_POS_LONG_W - SOF_POS_WORD_ITEMS_W;

    constant L3_EOF_POS_OFFSET_W : natural :=  max(L2_HDR_LENGTH_W, L3_HDR_LENGTH_W) + 1;

    -- L4 constants
    constant L3_EOF_POS_LONG_W : natural := max(log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE), L3_HDR_LENGTH_W) + 1;
    constant L4_SOF_POS_LONG_W : natural := max(log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE), L3_HDR_LENGTH_W) + 1;

    constant L4_TARGET_WORD_W  : natural := L4_SOF_POS_LONG_W - SOF_POS_WORD_ITEMS_W;

    --
    constant AGGREGATE_IMPL : string := "prefixsum"; -- "serial", "parallel", "prefixsum"

    -- ========================================================================
    --                                FUNCTIONS
    -- ========================================================================

    function or_slv_array(slv_array : slv_array_t; items : integer) return std_logic_vector is
        variable v : std_logic_vector(slv_array(0)'high downto 0) := (others => '0');
    begin
        for i in 0 to items-1 loop
            v := v or slv_array(i);
        end loop;
        return v;
    end;

    function or_u_array(u_array : u_array_t; items : integer) return unsigned is
        variable v : unsigned(u_array(0)'high downto 0) := (others => '0');
    begin
        for i in 0 to items-1 loop
            v := v or u_array(i);
        end loop;
        return v;
    end;

    function int_odd(int : integer) return std_logic is
        variable uns : std_logic_vector(32-1 downto 0);
        variable odd : std_logic;
    begin
        uns := std_logic_vector(to_unsigned(int, 32));
        odd := uns(0);
        return odd;
    end;

    -- ========================================================================
    --                                 SIGNALS
    -- ========================================================================


    signal l3_sof_dst_rdy            : std_logic;
    signal l3_eof_dst_rdy            : std_logic;
    signal l3_dst_rdy                : std_logic;
    signal l4_dst_rdy                : std_logic;

    signal rx_mfb_sof_pos_arr        : u_array_t(MFB_REGIONS-1 downto 0)(SOF_POS_W-1 downto 0);
    signal rx_mfb_eof_pos_arr        : u_array_t(MFB_REGIONS-1 downto 0)(EOF_POS_W-1 downto 0);
    signal rx_l2_hdr_length_arr      : u_array_t(MFB_REGIONS-1 downto 0)(L2_HDR_LENGTH_W-1 downto 0);
    signal rx_l3_hdr_length_arr      : u_array_t(MFB_REGIONS-1 downto 0)(L3_HDR_LENGTH_W-1 downto 0);

    signal rx_data_reg0              : std_logic_vector(MFB_DATA_W-1 downto 0);
    signal rx_sof_pos_reg0           : std_logic_vector(MFB_REGIONS*SOF_POS_W-1 downto 0);
    signal rx_eof_pos_reg0           : std_logic_vector(MFB_REGIONS*EOF_POS_W-1 downto 0);
    signal rx_sof_reg0               : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal rx_eof_reg0               : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal rx_src_rdy_reg0           : std_logic;
    signal rx_dst_rdy_reg0           : std_logic;
    
    -- L3 XOF conversion signals
    signal l3_sof_pos_multihot       : std_logic_vector(2**SOF_POS_WORD_ITEMS_W-1 downto 0);
    signal l3_sof_src_rdy            : std_logic;
    
    signal l4_sof_pos_offset_arr     : u_array_t       (MFB_REGIONS-1 downto 0)(L3_EOF_POS_OFFSET_W-1 downto 0);
    signal l4_sof_pos_offset         : std_logic_vector(MFB_REGIONS*            L3_EOF_POS_OFFSET_W-1 downto 0);
    -- signal l4_sof_pos_multihot       : std_logic_vector(2**SOF_POS_WORD_ITEMS_W-1 downto 0);
    -- signal l4_sof_src_rdy            : std_logic;
    signal l3_eof_pos_multihot       : std_logic_vector(2**SOF_POS_WORD_ITEMS_W-1 downto 0);

    -- L3 MVB Last Valid signals
    signal odd_item                  : unsigned        (MVB_ITEMS-1 downto 0);
    signal l3_sof_pos_odd            : std_logic_vector(MVB_ITEMS-1 downto 0);

    signal rx_l3_lv_data_arr         : slv_array_t     (MVB_ITEMS-1 downto 0)(2-1 downto 0);
    signal rx_l3_lv_data             : std_logic_vector(MVB_ITEMS*            2-1 downto 0);
    signal rx_l3_lv_vld              : std_logic_vector(MVB_ITEMS-1 downto 0);
    signal rx_l3_lv_src_rdy          : std_logic;
    signal rx_l3_lv_dst_rdy          : std_logic;

    signal tx_l3_lv_data             : std_logic_vector(MVB_ITEMS*            2-1 downto 0);
    signal tx_l3_lv_data_arr         : slv_array_t     (MVB_ITEMS-1 downto 0)(2-1 downto 0);
    signal tx_l3_lv_odd              : std_logic_vector(MVB_ITEMS-1 downto 0);
    signal tx_l3_lv_vld              : std_logic_vector(MVB_ITEMS-1 downto 0);
    signal tx_l3_lv_src_rdy          : std_logic;
    signal tx_l3_lv_dst_rdy          : std_logic;

    -- L4 XOF conversion signals
    signal l4_sof_pos_multihot       : std_logic_vector(2**SOF_POS_WORD_ITEMS_W-1 downto 0);
    signal l4_sof_src_rdy            : std_logic;

    signal l4_eof_pos_addr_en        : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal l4_eof_pos_addr           : slv_array_t     (MFB_REGIONS-1 downto 0)(EOF_POS_W-1 downto 0);
    signal l4_eof_pos_onehot         : slv_array_t     (MFB_REGIONS-1 downto 0)(2**EOF_POS_W-1 downto 0);
    signal l4_eof_pos_onehot_ser     : std_logic_vector(MFB_DATA_ITEMS-1 downto 0);
    signal l4_eof_pos_onehot_fix_arr : std_logic_vector(MFB_DATA_ITEMS   downto 0);

    signal l4_eof_pos_multihot       : std_logic_vector(MFB_DATA_ITEMS-1 downto 0);
    signal l4_eof_src_rdy            : std_logic;

    -- L4 MVB Last Valid signals
    signal l4_sof_pos_odd            : std_logic_vector(MVB_ITEMS-1 downto 0);

    signal rx_l4_lv_data_arr         : slv_array_t     (MVB_ITEMS-1 downto 0)(2-1 downto 0);
    signal rx_l4_lv_data             : std_logic_vector(MVB_ITEMS*            2-1 downto 0);
    signal rx_l4_lv_vld              : std_logic_vector(MVB_ITEMS-1 downto 0);
    signal rx_l4_lv_src_rdy          : std_logic;
    signal rx_l4_lv_dst_rdy          : std_logic;
    
    signal tx_l4_lv_data             : std_logic_vector(MVB_ITEMS*            2-1 downto 0);
    signal tx_l4_lv_data_arr         : slv_array_t     (MVB_ITEMS-1 downto 0)(2-1 downto 0);
    signal tx_l4_lv_odd              : std_logic_vector(MVB_ITEMS-1 downto 0);
    signal tx_l4_lv_vld              : std_logic_vector(MVB_ITEMS-1 downto 0);
    signal tx_l4_lv_src_rdy          : std_logic;
    signal tx_l4_lv_dst_rdy          : std_logic;

begin

    RX_MFB_DST_RDY <= l4_dst_rdy and l3_dst_rdy;

    rx_l2_hdr_length_arr <= slv_arr_to_u_arr(slv_array_deser(RX_L2_HDR_LENGTH, MFB_REGIONS));
    rx_l3_hdr_length_arr <= slv_arr_to_u_arr(slv_array_deser(RX_L3_HDR_LENGTH, MFB_REGIONS));

    -- --------------------------------
    -- Input register
    -- --------------------------------
    process(CLK)
    begin
        if rising_edge(CLK) then
            if (RX_MFB_DST_RDY = '1') then
                rx_data_reg0    <= RX_MFB_DATA;
                rx_sof_pos_reg0 <= RX_MFB_SOF_POS;
                rx_eof_pos_reg0 <= RX_MFB_EOF_POS;
                rx_sof_reg0     <= RX_MFB_SOF;
                rx_eof_reg0     <= RX_MFB_EOF;
                rx_src_rdy_reg0 <= RX_MFB_SRC_RDY;

            end if;

            if (RESET = '1') then
                rx_src_rdy_reg0 <= '0';
            end if;
        end if;
    end process;
    
    -- ========================================================================
    -- Layer 3
    -- ========================================================================

    l3_dst_rdy <= l3_sof_dst_rdy and l3_eof_dst_rdy;

    -- --------------------------------
    -- Convert L3 SOF POS to Onehot format
    -- Latency = 1
    -- --------------------------------
    l3_sof_to_item_vld_conv_i : entity work.XOF_TO_ITEM_VLD_CONV
    generic map(
        MFB_REGIONS     => MFB_REGIONS    ,
        MFB_REGION_SIZE => MFB_REGION_SIZE,
        MFB_BLOCK_SIZE  => MFB_BLOCK_SIZE ,
        MFB_ITEM_WIDTH  => MFB_ITEM_WIDTH ,
        SOF_OFFSET_W    => L2_HDR_LENGTH_W
    )
    port map(
        CLK   => CLK,
        RESET => RESET,

        RX_SOF_POS    => RX_MFB_SOF_POS,
        RX_SOF_OFFSET => RX_L2_HDR_LENGTH,
        RX_SOF        => RX_MFB_SOF,
        RX_SRC_RDY    => RX_MFB_SRC_RDY,
        RX_DST_RDY    => l3_sof_dst_rdy,

        TX_ITEM_VLD   => l3_sof_pos_multihot,
        TX_SRC_RDY    => l3_sof_src_rdy,
        TX_DST_RDY    => rx_l3_lv_dst_rdy
    );

    process(CLK)
    begin
        if rising_edge(CLK) then
            if (TX_L3_DST_RDY = '1') then
                assert (rx_src_rdy_reg0 = l3_sof_src_rdy)
                    report "ERROR!"
                    severity failure;
            end if;
        end if;
    end process;

    -- --------------------------------
    -- Convert L3 EOF POS to Onehot format
    -- Latency = 1
    -- --------------------------------
    l3_eof_pos_offset_g : for r in 0 to MFB_REGIONS-1 generate
        l4_sof_pos_offset_arr(r) <= resize(rx_l2_hdr_length_arr(r), L3_EOF_POS_OFFSET_W) +
                                    resize(rx_l3_hdr_length_arr(r), L3_EOF_POS_OFFSET_W);
    end generate;

    -- This is actually an L4 SOF POS, L3 EOF POS is on the previous Item.
    -- The output signal l4_sof_pos_multihot is used for:
    -- 1) indicating the end   of the L3 checksum data and
    -- 2) indicating the start of the L4 checksum data
    l4_sof_pos_offset <= slv_array_ser(u_arr_to_slv_arr(l4_sof_pos_offset_arr));

    l3_eof_to_item_vld_conv_i : entity work.XOF_TO_ITEM_VLD_CONV
    generic map(
        MFB_REGIONS     => MFB_REGIONS    ,
        MFB_REGION_SIZE => MFB_REGION_SIZE,
        MFB_BLOCK_SIZE  => MFB_BLOCK_SIZE ,
        MFB_ITEM_WIDTH  => MFB_ITEM_WIDTH ,
        SOF_OFFSET_W    => L3_EOF_POS_OFFSET_W
    )
    port map(
        CLK   => CLK,
        RESET => RESET,

        RX_SOF_POS    => RX_MFB_SOF_POS,
        RX_SOF_OFFSET => l4_sof_pos_offset,
        RX_SOF        => RX_MFB_SOF,
        RX_SRC_RDY    => RX_MFB_SRC_RDY,
        RX_DST_RDY    => l3_eof_dst_rdy,

        TX_ITEM_VLD   => l4_sof_pos_multihot,
        TX_SRC_RDY    => l4_sof_src_rdy,
        TX_DST_RDY    => rx_l3_lv_dst_rdy
    );

    process(CLK)
    begin
        if rising_edge(CLK) then
            if (TX_L3_DST_RDY = '1') then
                assert (rx_src_rdy_reg0 = l4_sof_src_rdy)
                    report "ERROR!"
                    severity failure;
            end if;
        end if;
    end process;

    -- --------------------------------
    -- L3 EOF POS
    -- --------------------------------
    -- l4_sof_pos_multihot shifting one Item lower (closer) to get indication of the end of the L3 EOF

    -- This fails when rx_l4_lv_src_rdy drops while it is inside a packet
    process(CLK)
    begin
        if rising_edge(CLK) then
            if (rx_l4_lv_src_rdy = '1') and (rx_l4_lv_dst_rdy = '1') then
                l3_eof_pos_multihot(MFB_DATA_ITEMS-2 downto 0) <= l4_sof_pos_multihot(MFB_DATA_ITEMS-1 downto 1);
            end if;
            if (RESET = '1') then
                l3_eof_pos_multihot(MFB_DATA_ITEMS-2 downto 0) <= (others => '0');
            end if;
        end if;
    end process;

    l3_eof_pos_multihot(MFB_DATA_ITEMS-1) <= l4_sof_pos_multihot(0);

    -- --------------------------------
    -- Item validation
    -- --------------------------------
    rx_l3_lv_data_g : for i in 0 to MVB_ITEMS-1 generate
        odd_item(i) <= int_odd(i);
        l3_sof_pos_odd(i) <= '1' when (l3_sof_pos_multihot(i) = '1') and (odd_item(i) = '1') else '0';
        rx_l3_lv_data_arr(i) <= l3_sof_pos_odd(i) & l3_sof_pos_multihot(i);
    end generate;

    rx_l3_lv_data    <= slv_array_ser(rx_l3_lv_data_arr);
    rx_l3_lv_vld     <= l3_sof_pos_multihot or l4_sof_pos_multihot;
    rx_l3_lv_src_rdy <= rx_src_rdy_reg0 and l3_sof_src_rdy and l4_sof_src_rdy;

    l3_last_vld_i : entity work.MVB_AGGREGATE_LAST_VLD
    generic map(
        ITEMS          => MVB_ITEMS     ,
        ITEM_WIDTH     => 1+1           ,
        IMPLEMENTATION => AGGREGATE_IMPL,
        INTERNAL_REG   => True
    )
    port map(
        CLK   => CLK,
        RESET => RESET,

        RX_DATA    => rx_l3_lv_data   ,
        RX_VLD     => rx_l3_lv_vld    ,
        RX_SRC_RDY => rx_l3_lv_src_rdy,
        RX_DST_RDY => rx_l3_lv_dst_rdy,

        REG_IN_DATA  => (others => '0'),
        REG_IN_VLD   => '0',
        REG_OUT_DATA => open,
        REG_OUT_VLD  => open,
        REG_OUT_WR   => open,

        TX_DATA         => tx_l3_lv_data,
        TX_VLD          => open,
        TX_PRESCAN_DATA => open,
        TX_PRESCAN_VLD  => open,
        TX_SRC_RDY      => tx_l3_lv_src_rdy,
        TX_DST_RDY      => tx_l3_lv_dst_rdy
    );

    tx_l3_lv_data_arr <= slv_array_deser(tx_l3_lv_data, MVB_ITEMS);

    tx_l3_lv_data_g : for i in 0 to MVB_ITEMS-1 generate
        -- tx_l3_lv_bypass(i) <= rx_l3_lv_data(i)(2);
        tx_l3_lv_odd(i) <= tx_l3_lv_data_arr(i)(1);
        tx_l3_lv_vld(i) <= tx_l3_lv_data_arr(i)(0); -- propagated l3_sof_pos_multihot is the TX valid
    end generate;

    -- ========================================================================
    -- Layer 4
    -- ========================================================================

    l4_dst_rdy <= rx_l4_lv_dst_rdy;

    -- --------------------------------
    -- SOF
    -- --------------------------------
    -- signals l4_sof_pos_multihot and l4_sof_src_rdy are already prepared;

    -- --------------------------------
    -- EOF
    -- --------------------------------
    l4_eof_pos_addr_en <= rx_eof_reg0 and rx_src_rdy_reg0;
    l4_eof_pos_addr    <= slv_array_deser(rx_eof_pos_reg0, MFB_REGIONS);

    l3_sof_pos_bin2hot_g : for r in 0 to MFB_REGIONS-1 generate

        bin2hot_i : entity work.BIN2HOT
        generic map(
            DATA_WIDTH => log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE)
        )
        port map(
            EN     => l4_eof_pos_addr_en(r),
            INPUT  => l4_eof_pos_addr   (r),
            OUTPUT => l4_eof_pos_onehot (r)
        );

    end generate;

    l4_eof_pos_onehot_ser <= slv_array_ser(l4_eof_pos_onehot);

    -- l4_eof_pos_onehot_ser shifting one Item further
    l4_eof_pos_onehot_fix_g : for i in 0 to MFB_DATA_ITEMS-1 generate
        l4_eof_pos_onehot_fix_arr(i+1) <= l4_eof_pos_onehot_ser(i);
    end generate;

    process(CLK)
    begin
        if rising_edge(CLK) then
            if (rx_l4_lv_src_rdy = '1') and (rx_l4_lv_dst_rdy = '1') then
                l4_eof_pos_onehot_fix_arr(0) <= l4_eof_pos_onehot_fix_arr(MFB_DATA_ITEMS);
            end if;
            if (RESET = '1') then
                l4_eof_pos_onehot_fix_arr(0) <= '0';
            end if;
        end if;
    end process;

    l4_eof_pos_multihot <= l4_eof_pos_onehot_fix_arr(MFB_DATA_ITEMS-1 downto 0);
    l4_eof_src_rdy      <= rx_src_rdy_reg0;

    -- --------------------------------
    -- Item validation
    -- --------------------------------
    rx_l4_lv_data_g : for i in 0 to MVB_ITEMS-1 generate
        -- odd_item(i) <= int_odd(i);
        l4_sof_pos_odd(i) <= '1' when (l4_sof_pos_multihot(i) = '1') and (odd_item(i) = '1') else '0';
        rx_l4_lv_data_arr(i) <= l4_sof_pos_odd(i) & l4_sof_pos_multihot(i);
    end generate;

    rx_l4_lv_data    <= slv_array_ser(rx_l4_lv_data_arr);
    rx_l4_lv_vld     <= l4_sof_pos_multihot or l4_eof_pos_multihot;
    rx_l4_lv_src_rdy <= l4_sof_src_rdy and l4_eof_src_rdy;

    l4_last_vld_i : entity work.MVB_AGGREGATE_LAST_VLD
    generic map(
        ITEMS          => MVB_ITEMS     ,
        ITEM_WIDTH     => 1+1           ,
        IMPLEMENTATION => AGGREGATE_IMPL,
        INTERNAL_REG   => True
    )
    port map(
        CLK   => CLK,
        RESET => RESET,

        RX_DATA    => rx_l4_lv_data   ,
        RX_VLD     => rx_l4_lv_vld    ,
        RX_SRC_RDY => rx_l4_lv_src_rdy,
        RX_DST_RDY => rx_l4_lv_dst_rdy,

        REG_IN_DATA  => (others => '0'),
        REG_IN_VLD   => '0',
        REG_OUT_DATA => open,
        REG_OUT_VLD  => open,
        REG_OUT_WR   => open,

        TX_DATA         => tx_l4_lv_data,
        TX_VLD          => open,
        TX_PRESCAN_DATA => open,
        TX_PRESCAN_VLD  => open,
        TX_SRC_RDY      => tx_l4_lv_src_rdy,
        TX_DST_RDY      => tx_l4_lv_dst_rdy
    );

    tx_l4_lv_data_arr <= slv_array_deser(tx_l4_lv_data, MVB_ITEMS);

    tx_l4_lv_data_g : for i in 0 to MVB_ITEMS-1 generate
        -- tx_l4_lv_bypass(i) <= rx_l4_lv_data(i)(2);
        tx_l4_lv_odd(i) <= tx_l4_lv_data_arr(i)(1);
        tx_l4_lv_vld(i) <= tx_l4_lv_data_arr(i)(0); -- propagated l3_sof_pos_multihot is the TX valid
    end generate;

    -- ========================================================================
    -- Output assignment
    -- ========================================================================

    process(CLK)
    begin
        if rising_edge(CLK) then
            if (tx_l3_lv_dst_rdy = '1') then
                TX_L3_DATA    <= rx_data_reg0;
                TX_L3_ODD     <= tx_l3_lv_odd;
                TX_L3_VLD     <= tx_l3_lv_vld and tx_l3_lv_src_rdy;
                TX_L3_SRC_RDY <= tx_l3_lv_src_rdy;
            end if;

            if (RESET = '1') then
                TX_L3_SRC_RDY <= '0';
            end if;
        end if;
    end process;
    TX_L3_END <= l3_eof_pos_multihot;

    tx_l3_lv_dst_rdy <= TX_L3_DST_RDY;

    process(CLK)
    begin
        if rising_edge(CLK) then
            if (tx_l4_lv_dst_rdy = '1') then
                TX_L4_DATA    <= rx_data_reg0;
                TX_L4_ODD     <= tx_l4_lv_odd;
                TX_L4_END     <= l4_eof_pos_onehot_ser;
                TX_L4_VLD     <= tx_l4_lv_vld and tx_l4_lv_src_rdy;
                TX_L4_SRC_RDY <= tx_l4_lv_src_rdy;
            end if;

            if (RESET = '1') then
                TX_L4_SRC_RDY <= '0';
            end if;
        end if;
    end process;

    tx_l4_lv_dst_rdy <= TX_L4_DST_RDY;

end architecture;
