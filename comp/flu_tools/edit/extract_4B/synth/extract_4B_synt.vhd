-- packet_editor_synt.vhd: architecture of packet editor
-- Copyright (C) 2015 CESNET
-- Author(s): Mario Kuka <xkukam00@stud.fit.vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause
--
-- $Id$
--
-- TODO:
--

library IEEE;  
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

use work.math_pack.all;

entity EXTRACT_4B_SYNT is
   generic(
      DATA_WIDTH 	   : integer := 512;
      SOP_POS_WIDTH 	: integer := 3;
      OFFSET_WIDTH   : integer := 10
   );  
   port(
      CLK            : in std_logic;
      RESET          : in std_logic;
      OFFSET         : in std_logic_vector(OFFSET_WIDTH-1 downto 0);
      RX_DATA        : in std_logic_vector(DATA_WIDTH-1 downto 0);
      RX_SOP_POS     : in std_logic_vector(SOP_POS_WIDTH-1 downto 0);
      RX_EOP_POS     : in std_logic_vector(log2(DATA_WIDTH/8)-1 downto 0);
      RX_SOP         : in std_logic;
      RX_EOP         : in std_logic;
      RX_SRC_RDY     : in std_logic;
      RX_DST_RDY     : out std_logic;
      TX_DATA        : out std_logic_vector((8*4)-1 downto 0);
      TX_SRC_RDY     : out std_logic;
      TX_DST_RDY     : in std_logic
   ); 
end entity;

architecture full of EXTRACT_4B_SYNT is 
   signal REG_OFFSET        : std_logic_vector(OFFSET_WIDTH-1 downto 0);
   signal REG_RX_DATA       : std_logic_vector(DATA_WIDTH-1 downto 0);
   signal REG_RX_SOP_POS    : std_logic_vector(SOP_POS_WIDTH-1 downto 0);
   signal REG_RX_EOP_POS    : std_logic_vector(log2(DATA_WIDTH/8)-1 downto 0);
   signal REG_RX_SOP        : std_logic;
   signal REG_RX_EOP        : std_logic;
   signal REG_RX_SRC_RDY    : std_logic;
   signal REG_RX_DST_RDY    : std_logic;
   signal REG_TX_DATA       : std_logic_vector((8*4)-1 downto 0);
   signal REG_TX_SRC_RDY    : std_logic;
   signal REG_TX_DST_RDY    : std_logic;
begin
   
   process(CLK)
   begin
      if (CLK'event) and (CLK='1') then
         REG_OFFSET        <= OFFSET;
         REG_RX_DATA       <= RX_DATA;
         REG_RX_SOP_POS    <= RX_SOP_POS;
         REG_RX_EOP_POS    <= RX_EOP_POS;
         REG_RX_SOP        <= RX_SOP;
         REG_RX_EOP        <= RX_EOP;
         REG_RX_SRC_RDY    <= RX_SRC_RDY;
         RX_DST_RDY        <= REG_RX_DST_RDY;
         TX_DATA           <= REG_TX_DATA;
         TX_SRC_RDY        <= REG_TX_SRC_RDY;
         REG_TX_DST_RDY    <= TX_DST_RDY;
      end if;
   end process;

   uut : entity work.EXTRACT_4B
   generic map (
      DATA_WIDTH     => DATA_WIDTH,
      SOP_POS_WIDTH  => SOP_POS_WIDTH,
      OFFSET_WIDTH   => OFFSET_WIDTH
   )
   port map (
      CLK            => CLK,
      RESET          => RESET, 
      OFFSET         => REG_OFFSET,
      RX_DATA        => REG_RX_DATA,
      RX_SOP_POS     => REG_RX_SOP_POS,
      RX_EOP_POS     => REG_RX_EOP_POS,
      RX_SOP         => REG_RX_SOP,
      RX_EOP         => REG_RX_EOP,
      RX_SRC_RDY     => REG_RX_SRC_RDY,
      RX_DST_RDY     => REG_RX_DST_RDY,
      TX_DATA        => REG_TX_DATA,
      TX_SRC_RDY     => REG_TX_SRC_RDY,
      TX_DST_RDY     => REG_TX_DST_RDY
   );
end architecture;
