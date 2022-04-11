-- fifo.vhd: FIFO - m x n bit
--                  - synchronous write, asynchronous read
--                  - Status signal
-- Copyright (C) 2006 CESNET
-- Author(s):  Pecenka Tomas pecenka@liberouter.org
--             Pus Viktor    pus@liberouter.org
--
-- SPDX-License-Identifier: BSD-3-Clause
--
-- $Id$
--
-- TODO:
--
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;
use work.math_pack.all;



-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity FIFO is
   generic (
      -- Set data width here
      DATA_WIDTH     : integer := 84;

      -- Set number of items in FIFO here
      ITEMS          : integer := 64;

      -- for last block identification
      BLOCK_SIZE     : integer := 0;

      -- compute value of status signal
      STATUS_ENABLED : boolean := false;

      -- for better timing on output
      DO_REG         : boolean := false
   );
   port(
      RESET    : in std_logic;  -- Global reset signal
      CLK      : in std_logic;  -- Global clock signal

      -- Write interface
      DATA_IN  : in std_logic_vector((DATA_WIDTH-1) downto 0); -- Data input
      WRITE_REQ: in std_logic;  -- Write request
      FULL     : out std_logic; -- FIFO is full
      LSTBLK   : out std_logic; -- Last block identifier
      STATUS   : out std_logic_vector(log2(ITEMS) downto 0); -- Free items (only when STATUS_ENABLED is true)

      -- Read interface
      DATA_OUT : out std_logic_vector((DATA_WIDTH-1) downto 0); -- Data output
      READ_REQ : in std_logic;  -- Read request
      EMPTY    : out std_logic  -- FIFO is empty
   );
end entity;
