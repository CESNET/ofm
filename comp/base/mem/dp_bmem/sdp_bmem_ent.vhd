-- sdp_bmem_ent.vhd: Half dual port generic memory composed from Block Rams - entity
-- Copyright (C) 2010 CESNET
-- Author(s): Viktor Puš <pus@liberouter.org>
--
-- SPDX-License-Identifier: BSD-3-Clause
--
-- $Id$
--
-- TODO:


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;
-- auxilarity functions and constant needed to evaluate generic address etc.
use WORK.math_pack.all;

-- pragma translate_off
library UNISIM;
use UNISIM.vcomponents.all;
-- pragma translate_on


-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------

entity SDP_BMEM is
   -- Capacity of 1, 2, 4 Block rams is 16384 bits
   -- Capacity of 9, 18, 36 Block rams is 18432 bits
   generic(
      DATA_WIDTH      : integer := 32;
      -- Item in memory needed, one item size is DATA_WIDTH
      ITEMS           : integer := 1024;
      -- Output directly from BlockRams or throw register
      OUTPUT_REG      : boolean := true;
      -- Allow the output data register to be reset
      RESET_DATA_PATH : boolean := true; 
      -- debug prints
      DEBUG           : boolean := false
   );

   port(
      -- Interface A - Write only
      CLKA   : in    std_logic; -- Clock A
      RSTA   : in    std_logic := '0'; -- CLKA sync reset
      WEA    : in    std_logic; -- Write Enable
      ADDRA  : in    std_logic_vector(LOG2(ITEMS)-1 downto 0); -- Address A
      DIA    : in    std_logic_vector(DATA_WIDTH-1 downto 0); -- Data A In

      -- Interface B - Read only
      CLKB   : in    std_logic; -- Clock B
      RSTB   : in    std_logic := '0'; -- CLKB sync reset
      PIPE_ENB : in  std_logic; -- Pipe Enable
      REB    : in    std_logic; -- Read Enable
      ADDRB  : in    std_logic_vector(LOG2(ITEMS)-1 downto 0); -- Address B
      DOB_DV : out   std_logic; -- Data B Valid
      DOB    : out   std_logic_vector(DATA_WIDTH-1 downto 0) -- Data B Out
   );
end entity SDP_BMEM;
