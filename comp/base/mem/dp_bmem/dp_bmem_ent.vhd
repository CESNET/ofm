--
-- dp_bmem_ent.vhd: Dual port generic memory composed from Block Rams - entity 
-- declaration
-- Copyright (C) 2004 CESNET
-- Author(s): Petr Kobiersky <xkobie00@stud.fit.vutbr.cz>
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

entity DP_BMEM is
   -- Capacity of 1, 2, 4 Block rams is 16384 bits
   -- Capacity of 9, 18, 36 Block rams is 18432 bits
   generic(
      DATA_WIDTH     : integer := 32;
      -- Item in memory needed, one item size is DATA_WIDTH
      ITEMS          : integer := 1024;
      -- What operation will be performed first when both WE and RE are
      -- active? Only for behavioral simulation purpose.
      -- WRITE_FIRST(default) | READ_FIRST | NO_CHANGE
      WRITE_MODE_A   : string := "WRITE_FIRST";
      WRITE_MODE_B   : string := "WRITE_FIRST";
      -- Output directly from BlockRams or throw register
      OUTPUT_REG     : boolean := true;
      RESET_DATA_PATH: boolean := true; -- Allow the output data register to be reset
      -- debug prints
      DEBUG          : boolean := false
   );

   port(
      -- Interface A
      RSTA   : in    std_logic := '0'; -- CLKA sync reset
      CLKA   : in    std_logic; -- Clock A
      PIPE_ENA : in  std_logic; -- Pipe Enable
      REA    : in    std_logic; -- Read Enable
      WEA    : in    std_logic; -- Write Enable
      ADDRA  : in    std_logic_vector(LOG2(ITEMS)-1 downto 0); -- Address A
      DIA    : in    std_logic_vector(DATA_WIDTH-1 downto 0); -- Data A In
      DOA_DV : out   std_logic; -- Data A Valid
      DOA    : out   std_logic_vector(DATA_WIDTH-1 downto 0); -- Data A Out

      -- Interface B
      RSTB   : in    std_logic := '0'; -- CLKB sync reset
      CLKB   : in    std_logic; -- Clock B
      PIPE_ENB : in  std_logic; -- Pipe Enable
      REB    : in    std_logic; -- Read Enable
      WEB    : in    std_logic; -- Write Enable
      ADDRB  : in    std_logic_vector(LOG2(ITEMS)-1 downto 0); -- Address B
      DIB    : in    std_logic_vector(DATA_WIDTH-1 downto 0); -- Data B In
      DOB_DV : out   std_logic; -- Data B Valid
      DOB    : out   std_logic_vector(DATA_WIDTH-1 downto 0) -- Data B Out
   );
end entity DP_BMEM;
