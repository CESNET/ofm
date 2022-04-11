-- pfifo_fl16.vhd: Frame Link protocol generic packet FIFO wrapper
-- Copyright (C) 2006 CESNET
-- Author(s): Viktor Pus <pus@liberouter.org>
--
-- SPDX-License-Identifier: BSD-3-Clause
--
-- $Id$
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- library containing log2 function
use work.math_pack.all;
-- library with t_flxx data types
use work.fl_pkg.all;

-- ----------------------------------------------------------------------------
--                            Entity declaration
-- ----------------------------------------------------------------------------
entity FL_PFIFO_FL16 is
   generic(
      -- number of items in the FIFO
      ITEMS          : integer;
      -- Size of block (for LSTBLK signal)
      BLOCK_SIZE     : integer;
      -- Width of STATUS signal available
      STATUS_WIDTH   : integer;
      -- Maximal number of packets
      MAX_DISCARD_BLOCKS : integer;
      -- Number of parts in each frame
      PARTS          : integer
   );
   port(
      -- Common signals
      CLK            : in  std_logic;
      RESET          : in  std_logic;

      -- FrameLink interfaces
      RX             : inout t_fl16;
      TX             : inout t_fl16;

      -- FIFO control signals
      DISCARD        : in  std_logic;
      LSTBLK         : out std_logic;
      FULL           : out std_logic;
      EMPTY          : out std_logic;
      STATUS         : out std_logic_vector(STATUS_WIDTH-1 downto 0);
      FRAME_RDY      : out std_logic
   );
end entity FL_PFIFO_FL16;      

architecture full of FL_PFIFO_FL16 is
begin
   
   FL_FIFO_I: entity work.FL_PFIFO
   generic map
   (
      DATA_WIDTH  => 16,
      ITEMS       => ITEMS,
      BLOCK_SIZE  => BLOCK_SIZE,
      STATUS_WIDTH=> STATUS_WIDTH,
      MAX_DISCARD_BLOCKS => MAX_DISCARD_BLOCKS,
      PARTS       => PARTS
   )
   port map
   (
      CLK            => CLK,
      RESET          => RESET,

      -- write interface
      RX_DATA        => RX.DATA,
      RX_REM         => RX.DREM,
      RX_SRC_RDY_N   => RX.SRC_RDY_N,
      RX_DST_RDY_N   => RX.DST_RDY_N,
      RX_SOP_N       => RX.SOP_N,
      RX_EOP_N       => RX.EOP_N,
      RX_SOF_N       => RX.SOF_N,
      RX_EOF_N       => RX.EOF_N,
      
      -- read interface
      TX_DATA        => TX.DATA,
      TX_REM         => TX.DREM,
      TX_SRC_RDY_N   => TX.SRC_RDY_N,
      TX_DST_RDY_N   => TX.DST_RDY_N,
      TX_SOP_N       => TX.SOP_N,
      TX_EOP_N       => TX.EOP_N,
      TX_SOF_N       => TX.SOF_N,
      TX_EOF_N       => TX.EOF_N,

      -- FIFO state signals
      DISCARD        => DISCARD,
      LSTBLK         => LSTBLK,
      FULL           => FULL,
      EMPTY          => EMPTY,
      STATUS         => STATUS,
      FRAME_RDY      => FRAME_RDY
   );

end architecture full;
