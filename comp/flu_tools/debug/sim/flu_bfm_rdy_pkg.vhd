-- flu_bfm_rdy_pkg.vhd: RDY signal functions package for sim and monitor
-- Copyright (C) 2014 CESNET
-- Author(s): Ivan Bryndza <xbrynd00@stud.feec.vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause
--
-- $Id$
--
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;
use IEEE.numeric_std.all;

-- ----------------------------------------------------------------------------
--                        RDY functions package
-- ----------------------------------------------------------------------------
PACKAGE flu_bfm_rdy_pkg IS
TYPE RDYSignalDriver IS (EVER, ONOFF, RND);
PROCEDURE DriveRdyN50_50(signal CLK       : IN  std_logic;
                         signal RDY : OUT std_logic);
			 
PROCEDURE DriveRdyNAll(signal CLK       : IN  std_logic;
                       signal RDY : OUT std_logic);
		       
PROCEDURE DriveRdyNRnd(signal CLK       : IN  std_logic;
                       signal RDY : OUT std_logic);
		       
PROCEDURE SetSeed(Seed : in integer);
END flu_bfm_rdy_pkg;
-- ----------------------------------------------------------------------------
--                   FrameLinkUnaligned Bus BFM Package BODY
-- ----------------------------------------------------------------------------
PACKAGE BODY flu_bfm_rdy_pkg IS
SHARED VARIABLE number: integer := 399751;

PROCEDURE SetSeed(Seed : in integer) IS
   BEGIN
      number := Seed; 
   END;

PROCEDURE Random(RND : out integer) IS
   BEGIN
      number := number * 69069 + 1;
      RND := (number rem 7);
   END;

PROCEDURE DriveRdyN50_50(signal CLK       : IN  std_logic;
                         signal RDY : OUT std_logic) IS
  BEGIN
    RDY <= '0';
    wait until (CLK'event and CLK='1');
    RDY <= '1';
    wait until (CLK'event and CLK='1');
  END;

PROCEDURE DriveRdyNAll(signal CLK       : IN  std_logic;
                       signal RDY : OUT std_logic) IS
  BEGIN
    RDY <= '1';
    wait until (CLK'event and CLK='1');
  END;
  
PROCEDURE DriveRdyNRnd(signal CLK       : IN  std_logic;
                       signal RDY : OUT std_logic) IS
VARIABLE RNDVAL: integer;
VARIABLE VALUE: std_logic;
   BEGIN
      Random(RNDVAL);
      if (RNDVAL rem 2 = 0) then
        VALUE := '0';
      else
        VALUE := '1';
      end if;
      Random(RNDVAL);
      for i in 1 to RNDVAL loop
         RDY <= VALUE;
         wait until (CLK'event and CLK='1');
      end loop;
   END;
       

END flu_bfm_rdy_pkg;
