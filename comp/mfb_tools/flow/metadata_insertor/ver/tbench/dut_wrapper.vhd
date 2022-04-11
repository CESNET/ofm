-- metadata_insertor.vhd: DUT Wrapper
-- Copyright (C) 2020 CESNET z. s. p. o.
-- Author(s): Daniel Kříž <xkrizd01@vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.math_pack.all;
use work.type_pack.all;

entity DUT_WRAPPER is
    generic(
        -- MVB characteristics
        MVB_ITEMS       : integer := 2;
        MVB_ITEM_WIDTH  : integer := 128;
        -- MFB characteristics
        MFB_REGIONS     : integer := 2;
        MFB_REGION_SIZE : integer := 1;
        MFB_BLOCK_SIZE  : integer := 8;
        MFB_ITEM_WIDTH  : integer := 32;
    
        -- Width of default MFB metadata
        MFB_META_WIDTH  : integer := 0;
    
        -- Metadata insertion mode
        INSERT_MODE     : integer := 0
    );
    port(
        ---------------------------------------------------------------------------
        -- Clock and Reset
        ---------------------------------------------------------------------------
    
        CLK             : in  std_logic;
        RESET           : in  std_logic;
    
        ---------------------------------------------------------------------------
    
        ---------------------------------------------------------------------------
        -- RX MVB
        ---------------------------------------------------------------------------
    
        RX_MVB_DATA     : in  std_logic_vector(MVB_ITEMS*MVB_ITEM_WIDTH-1 downto 0);
        RX_MVB_VLD      : in  std_logic_vector(MVB_ITEMS               -1 downto 0);
        RX_MVB_SRC_RDY  : in  std_logic;
        RX_MVB_DST_RDY  : out std_logic;
    
        ---------------------------------------------------------------------------
    
        ---------------------------------------------------------------------------
        -- RX MFB
        ---------------------------------------------------------------------------
    
        RX_MFB_DATA     : in  std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
        RX_MFB_META     : in  std_logic_vector(MFB_REGIONS*MFB_META_WIDTH-1 downto 0) := (others => '0'); -- Gets propagated to TX MFB without change
        RX_MFB_SOF      : in  std_logic_vector(MFB_REGIONS-1 downto 0);
        RX_MFB_EOF      : in  std_logic_vector(MFB_REGIONS-1 downto 0);
        RX_MFB_SOF_POS  : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
        RX_MFB_EOF_POS  : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
        RX_MFB_SRC_RDY  : in  std_logic;
        RX_MFB_DST_RDY  : out std_logic;
    
        ---------------------------------------------------------------------------
    
        ---------------------------------------------------------------------------
        -- TX MFB
        ---------------------------------------------------------------------------
    
        TX_MFB_DATA     : out std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
        TX_MFB_META     : out std_logic_vector(MFB_REGIONS*(MVB_ITEM_WIDTH+MFB_META_WIDTH)-1 downto 0); -- Original Metadata from RX MFB
        TX_MFB_SOF      : out std_logic_vector(MFB_REGIONS-1 downto 0);
        TX_MFB_EOF      : out std_logic_vector(MFB_REGIONS-1 downto 0);
        TX_MFB_SOF_POS  : out std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
        TX_MFB_EOF_POS  : out std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
        TX_MFB_SRC_RDY  : out std_logic;
        TX_MFB_DST_RDY  : in  std_logic
    
        ---------------------------------------------------------------------------
    );
end entity;

architecture FULL of DUT_WRAPPER is

    constant NEW_META_WIDTH   : natural := MVB_ITEM_WIDTH+MFB_META_WIDTH;

    signal mvb_data_arr_deser : slv_array_t(MFB_REGIONS-1 downto 0)(MVB_ITEM_WIDTH-1 downto 0);
    signal mfb_meta_arr_deser : slv_array_t(MFB_REGIONS-1 downto 0)(MFB_META_WIDTH-1 downto 0);
    signal mfb_new_meta_arr   : slv_array_t(MFB_REGIONS-1 downto 0)(NEW_META_WIDTH-1 downto 0);
    signal mfb_new_meta_ser   : std_logic_vector(MFB_REGIONS*NEW_META_WIDTH-1 downto 0);

    signal mfb_meta           : std_logic_vector(MFB_REGIONS*MFB_META_WIDTH-1 downto 0);
    signal mfb_meta_new       : std_logic_vector(MFB_REGIONS*MVB_ITEM_WIDTH-1 downto 0);

begin

    mfb_meta_arr_deser <= slv_array_deser(mfb_meta,MFB_REGIONS,MFB_META_WIDTH);
    mvb_data_arr_deser <= slv_array_deser(mfb_meta_new,MFB_REGIONS,MVB_ITEM_WIDTH);

    meta_g : for i in 0 to MFB_REGIONS-1 generate
        mfb_new_meta_arr(i) <= mfb_meta_arr_deser(i) & mvb_data_arr_deser(i);
    end generate;

    mfb_new_meta_ser <= slv_array_ser(mfb_new_meta_arr,MFB_REGIONS,NEW_META_WIDTH);
    TX_MFB_META <= mfb_new_meta_ser;

    dut_i : entity work.METADATA_INSERTOR
    generic map(
        MVB_ITEMS       => MVB_ITEMS,
        MVB_ITEM_WIDTH  => MVB_ITEM_WIDTH,
    
        MFB_REGIONS     => MFB_REGIONS,
        MFB_REGION_SIZE => MFB_REGION_SIZE,
        MFB_BLOCK_SIZE  => MFB_BLOCK_SIZE,
        MFB_ITEM_WIDTH  => MFB_ITEM_WIDTH,
    
        MFB_META_WIDTH  => MFB_META_WIDTH,
        INSERT_MODE     => INSERT_MODE
    )
    port map(
        CLK             => CLK,
        RESET           => RESET,
  
        RX_MVB_DATA     => RX_MVB_DATA,
        RX_MVB_VLD      => RX_MVB_VLD,
        RX_MVB_SRC_RDY  => RX_MVB_SRC_RDY,
        RX_MVB_DST_RDY  => RX_MVB_DST_RDY,
  
        RX_MFB_DATA     => RX_MFB_DATA,
        RX_MFB_META     => RX_MFB_META,
        RX_MFB_SOF      => RX_MFB_SOF,
        RX_MFB_EOF      => RX_MFB_EOF,
        RX_MFB_SOF_POS  => RX_MFB_SOF_POS,
        RX_MFB_EOF_POS  => RX_MFB_EOF_POS,
        RX_MFB_SRC_RDY  => RX_MFB_SRC_RDY,
        RX_MFB_DST_RDY  => RX_MFB_DST_RDY,
        
        TX_MFB_DATA     => TX_MFB_DATA,
        TX_MFB_META     => mfb_meta,
        TX_MFB_META_NEW => mfb_meta_new,
        TX_MFB_SOF      => TX_MFB_SOF,
        TX_MFB_EOF      => TX_MFB_EOF,
        TX_MFB_SOF_POS  => TX_MFB_SOF_POS,
        TX_MFB_EOF_POS  => TX_MFB_EOF_POS,
        TX_MFB_SRC_RDY  => TX_MFB_SRC_RDY,
        TX_MFB_DST_RDY  => TX_MFB_DST_RDY
    );

end architecture;
