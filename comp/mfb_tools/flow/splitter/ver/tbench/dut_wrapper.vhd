-- dut_wrapper.vhd:
-- Copyright (C) 2018 CESNET
-- Author(s): Jakub Cabal <cabal@cesnet.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.math_pack.all;

entity DUT_WRAPPER is
   generic(
      HDR_WIDTH       : natural := 128;
      MFB_REGIONS     : natural := 2;
      MFB_REGION_SIZE : natural := 1;
      MFB_BLOCK_SIZE  : natural := 8;
      MFB_ITEM_WIDTH  : natural := 32;
      MVB_ITEMS       : natural := 2;
      MVB_ITEM_WIDTH  : natural := HDR_WIDTH+2
   );
   port(
      -- =======================================================================
      -- CLOCK AND RESET
      -- =======================================================================
      CLK            : in  std_logic;
      RESET          : in  std_logic;
      -- =======================================================================
      -- INPUT MVB INTERFACE
      -- =======================================================================
      RX_MVB_DATA    : in  std_logic_vector(MVB_ITEMS*MVB_ITEM_WIDTH-1 downto 0);
      RX_MVB_VLD     : in  std_logic_vector(MVB_ITEMS-1 downto 0);
      RX_MVB_SRC_RDY : in  std_logic;
      RX_MVB_DST_RDY : out std_logic;
      -- =======================================================================
      -- INPUT MFB INTERFACE
      -- =======================================================================
      RX_MFB_DATA    : in  std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
      RX_MFB_SOF_POS : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
      RX_MFB_EOF_POS : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
      RX_MFB_SOF     : in  std_logic_vector(MFB_REGIONS-1 downto 0);
      RX_MFB_EOF     : in  std_logic_vector(MFB_REGIONS-1 downto 0);
      RX_MFB_SRC_RDY : in  std_logic;
      RX_MFB_DST_RDY : out std_logic;
      -- =======================================================================
      -- OUTPUT MVB0 INTERFACE
      -- =======================================================================
      TX0_MVB_DATA    : out std_logic_vector(MVB_ITEMS*HDR_WIDTH-1 downto 0);
      TX0_MVB_VLD     : out std_logic_vector(MVB_ITEMS-1 downto 0);
      TX0_MVB_SRC_RDY : out std_logic;
      TX0_MVB_DST_RDY : in  std_logic;
      -- =======================================================================
      -- OUTPUT MFB0 INTERFACE
      -- =======================================================================
      TX0_MFB_DATA    : out std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
      TX0_MFB_SOF_POS : out std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
      TX0_MFB_EOF_POS : out std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
      TX0_MFB_SOF     : out std_logic_vector(MFB_REGIONS-1 downto 0);
      TX0_MFB_EOF     : out std_logic_vector(MFB_REGIONS-1 downto 0);
      TX0_MFB_SRC_RDY : out std_logic;
      TX0_MFB_DST_RDY : in  std_logic;
      -- =======================================================================
      -- OUTPUT MVB1 INTERFACE
      -- =======================================================================
      TX1_MVB_DATA    : out std_logic_vector(MVB_ITEMS*HDR_WIDTH-1 downto 0);
      TX1_MVB_VLD     : out std_logic_vector(MVB_ITEMS-1 downto 0);
      TX1_MVB_SRC_RDY : out std_logic;
      TX1_MVB_DST_RDY : in  std_logic;
      -- =======================================================================
      -- OUTPUT MFB1 INTERFACE
      -- =======================================================================
      TX1_MFB_DATA    : out std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
      TX1_MFB_SOF_POS : out std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
      TX1_MFB_EOF_POS : out std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
      TX1_MFB_SOF     : out std_logic_vector(MFB_REGIONS-1 downto 0);
      TX1_MFB_EOF     : out std_logic_vector(MFB_REGIONS-1 downto 0);
      TX1_MFB_SRC_RDY : out std_logic;
      TX1_MFB_DST_RDY : in  std_logic
   );
end DUT_WRAPPER;

architecture FULL of DUT_WRAPPER is

   signal s_rx_hdr     : std_logic_vector(MVB_ITEMS*HDR_WIDTH-1 downto 0);
   signal s_rx_switch  : std_logic_vector(MVB_ITEMS-1 downto 0);
   signal s_rx_payload : std_logic_vector(MVB_ITEMS-1 downto 0);

begin

   mvb_unpack_g : for i in 0 to MVB_ITEMS-1 generate
      s_rx_hdr((i+1)*HDR_WIDTH-1 downto i*HDR_WIDTH) <= RX_MVB_DATA((i+1)*MVB_ITEM_WIDTH-1 downto i*MVB_ITEM_WIDTH+2);
      s_rx_switch(i)  <= RX_MVB_DATA(i*MVB_ITEM_WIDTH);
      s_rx_payload(i) <= RX_MVB_DATA(i*MVB_ITEM_WIDTH+1);
   end generate;

   dut_i : entity work.MFB_SPLITTER
   generic map(
      MVB_ITEMS      => MVB_ITEMS,
      MFB_REGIONS    => MFB_REGIONS,
      MFB_REG_SIZE   => MFB_REGION_SIZE,
      MFB_BLOCK_SIZE => MFB_BLOCK_SIZE,
      MFB_ITEM_WIDTH => MFB_ITEM_WIDTH,
      HDR_WIDTH      => HDR_WIDTH
   )
   port map(
      CLK        => CLK,
      RESET      => RESET,

      RX_MVB_HDR     => s_rx_hdr,
      RX_MVB_SWITCH  => s_rx_switch,
      RX_MVB_PAYLOAD => s_rx_payload,
      RX_MVB_VLD     => RX_MVB_VLD,
      RX_MVB_SRC_RDY => RX_MVB_SRC_RDY,
      RX_MVB_DST_RDY => RX_MVB_DST_RDY,

      RX_MFB_DATA    => RX_MFB_DATA,
      RX_MFB_SOF_POS => RX_MFB_SOF_POS,
      RX_MFB_EOF_POS => RX_MFB_EOF_POS,
      RX_MFB_SOF     => RX_MFB_SOF,
      RX_MFB_EOF     => RX_MFB_EOF,
      RX_MFB_SRC_RDY => RX_MFB_SRC_RDY,
      RX_MFB_DST_RDY => RX_MFB_DST_RDY,

      TX0_MVB_HDR     => TX0_MVB_DATA,
      TX0_MVB_VLD     => TX0_MVB_VLD,
      TX0_MVB_SRC_RDY => TX0_MVB_SRC_RDY,
      TX0_MVB_DST_RDY => TX0_MVB_DST_RDY,
      
      TX0_MFB_DATA    => TX0_MFB_DATA,
      TX0_MFB_SOF_POS => TX0_MFB_SOF_POS,
      TX0_MFB_EOF_POS => TX0_MFB_EOF_POS,
      TX0_MFB_SOF     => TX0_MFB_SOF,
      TX0_MFB_EOF     => TX0_MFB_EOF,
      TX0_MFB_SRC_RDY => TX0_MFB_SRC_RDY,
      TX0_MFB_DST_RDY => TX0_MFB_DST_RDY,

      TX1_MVB_HDR     => TX1_MVB_DATA,
      TX1_MVB_VLD     => TX1_MVB_VLD,
      TX1_MVB_SRC_RDY => TX1_MVB_SRC_RDY,
      TX1_MVB_DST_RDY => TX1_MVB_DST_RDY,

      TX1_MFB_DATA    => TX1_MFB_DATA,
      TX1_MFB_SOF_POS => TX1_MFB_SOF_POS,
      TX1_MFB_EOF_POS => TX1_MFB_EOF_POS,
      TX1_MFB_SOF     => TX1_MFB_SOF,
      TX1_MFB_EOF     => TX1_MFB_EOF,
      TX1_MFB_SRC_RDY => TX1_MFB_SRC_RDY,
      TX1_MFB_DST_RDY => TX1_MFB_DST_RDY
   );

end architecture;
