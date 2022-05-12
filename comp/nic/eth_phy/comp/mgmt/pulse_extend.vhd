--!
--! pulse_extend.vhd: Extend one-cycle pulse to a N-cycle 
--! Copyright (C) 2017 CESNET
--! Author(s): Stepan Friedl <friedl@cesnet.cz>
--!
--! Redistribution and use in source and binary forms, with or without
--! modification, are permitted provided that the following conditions
--! are met:
--! 1. Redistributions of source code must retain the above copyright
--!    notice, this list of conditions and the following disclaimer.
--! 2. Redistributions in binary form must reproduce the above copyright
--!    notice, this list of conditions and the following disclaimer in
--!    the documentation and/or other materials provided with the
--!    distribution.
--! 3. Neither the name of the Company nor the names of its contributors
--!    may be used to endorse or promote products derived from this
--!    software without specific prior written permission.
--!
--! This software is provided ``as is'', and any express or implied
--! warranties, including, but not limited to, the implied warranties of
--! merchantability and fitness for a particular purpose are disclaimed.
--! In no event shall the company or contributors be liable for any
--! direct, indirect, incidental, special, exemplary, or consequential
--! damages (including, but not limited to, procurement of substitute
--! goods or services; loss of use, data, or profits; or business
--! interruption) however caused and on any theory of liability, whether
--! in contract, strict liability, or tort (including negligence or
--! otherwise) arising in any way out of the use of this software, even
--! if advised of the possibility of such damage.
--!
--! $Id$
--!

library IEEE;	
use IEEE.std_logic_1164.all;	
use IEEE.std_logic_unsigned.all;	
use IEEE.std_logic_arith.all;
use IEEE.std_logic_misc.all; 

entity PULSE_EXTEND is
   generic (
      N   : natural := 4 -- Number of clock cycles to which the input pulse should be extend
   );    
   Port (
      RST     : in  STD_LOGIC := '0'; -- synchronous reset, optional
      CLK     : in  STD_LOGIC;    -- clock
      I       : in  STD_LOGIC;    -- Pulse input     
      O       : out STD_LOGIC     -- Output pulse, N clock cycles long
   );
end PULSE_EXTEND;

   --! -------------------------------------------------------------------------
   --!                      Architecture declaration
   --! -------------------------------------------------------------------------

architecture behavioral of PULSE_EXTEND is

   signal i_dly    : std_logic_vector(N-1 downto 0);
   attribute shreg_extract                : string;

begin
     
   process(CLK)
   begin
      if (rising_edge(CLK)) then
         if (RST = '1') then
            i_dly <= (others => '0');
         else
            i_dly(0) <= I;
            for i in 1 to N-1 loop
               i_dly(i) <= i_dly(i-1); 
            end loop;
            O <= OR_REDUCE(i_dly); 
         end if;
      end if;
   end process;

end architecture behavioral;
