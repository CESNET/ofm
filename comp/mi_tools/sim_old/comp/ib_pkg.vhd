-- ib_pkg.vhd: Internal Bus Package
-- Copyright (C) 2006 CESNET
-- Author(s): Petr Kobiersky <xkobie00@stud.fit.vutbr.cz>
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
use IEEE.std_logic_textio.all;
use IEEE.numeric_std.all;
use std.textio.all;

-- ----------------------------------------------------------------------------
--                        Internal Bus Package
-- ----------------------------------------------------------------------------
package ib_pkg is
   
   -- Address 
   constant C_IB_TRANS_TYPE_WIDTH : integer := 3;
   constant C_IB_FLAG_WIDTH       : integer := 1;
   constant C_IB_LENGTH_WIDTH     : integer := 12;
   
   -- IB Transaction Type ('NORMAL/COMPL' 'LOCAL/GLOBAL' 'WRITE/READ')
   constant C_IB_L2LW_TRANSACTION          : std_logic_vector(2 downto 0) := "000";
   constant C_IB_L2LR_TRANSACTION          : std_logic_vector(2 downto 0) := "001";
   constant C_IB_L2GW_TRANSACTION          : std_logic_vector(2 downto 0) := "010";
   constant C_IB_G2LR_TRANSACTION          : std_logic_vector(2 downto 0) := "011";
   constant C_IB_WR_COMPL_TRANSACTION      : std_logic_vector(2 downto 0) := "100";
   constant C_IB_RD_COMPL_TRANSACTION      : std_logic_vector(2 downto 0) := "101";

   -- Fourth bit of type (15 bit) is reserved for 1) Ack flag - for L2LW transaction
   --                                             2) Last fragment flag - for G2LR

   -- Internal 64 bit Bus Link 
   type t_internal_bus_link64 is record
      DATA       : std_logic_vector(63 downto 0);
      SOP_N      : std_logic;
      EOP_N      : std_logic;
      SRC_RDY_N  : std_logic;
      DST_RDY_N  : std_logic;
   end record;

   -- Internal 64 bit Bus
   type t_internal_bus64 is record
      UP         : t_internal_bus_link64;
      DOWN       : t_internal_bus_link64;
   end record;


   -- Internal Bus Write Interface
   type t_ibmi_write64 is record
      ADDR      : std_logic_vector(31 downto 0);       -- Address
      DATA      : std_logic_vector(63 downto 0);       -- Data
      BE        : std_logic_vector(7 downto 0);        -- Byte Enable
      REQ       : std_logic;                           -- Write Request
      RDY       : std_logic;                           -- Ready
      LENGTH    : std_logic_vector(11 downto 0);       -- Length
      SOF       : std_logic;                           -- Start of Frame
      EOF       : std_logic;                           -- End of Frame
   end record;

   -- Internal Bus Read Interface (Simple)
   type t_ibmi_read64s is record
      -- Input interface
      ADDR      : std_logic_vector(31 downto 0);       -- Address
      BE        : std_logic_vector(7 downto 0);        -- Byte Enable
--       LENGTH    : std_logic_vector(11 downto 0);       -- Length
      REQ       : std_logic;                           -- Read Request
      ARDY      : std_logic;                           -- Address Ready
      SOF_IN    : std_logic;                           -- Start of Frame (Input)
      EOF_IN    : std_logic;                           -- End of Frame (Intput)
      -- Output interface
      DATA      : std_logic_vector(63 downto 0);       -- Read Data
      SRC_RDY   : std_logic;                           -- Data Ready
      DST_RDY   : std_logic;                           -- Endpoint Ready
   end record;


   -- Internal Bus Read Interface (Combined without Tags)
   type t_ibmi_read64c is record
      -- Input interface
      ADDR      : std_logic_vector(31 downto 0);       -- Address
      BE        : std_logic_vector(7 downto 0);        -- Byte Enable
      LENGTH    : std_logic_vector(11 downto 0);       -- Length
      REQ       : std_logic;                           -- Read Request
      ARDY      : std_logic;                           -- Address Ready
      ACCEPT    : std_logic;                           -- Accept
      SOF_IN    : std_logic;                           -- Start of Frame (Input)
      EOF_IN    : std_logic;                           -- End of Frame (Intput)
      -- Output interface
      DATA      : std_logic_vector(63 downto 0);       -- Read Data
      SRC_RDY   : std_logic;                           -- Data Ready
      DST_RDY   : std_logic;                           -- Endpoint Ready
      SOF_OUT   : std_logic;                           -- Start of Frame (Output)
      EOF_OUT   : std_logic;                           -- End of Frame (Output)
   end record;


   -- Internal Bus Read Interface (Combined with Tags)
   type t_ibmi_read64ct is record
      -- Input interface
      ADDR      : std_logic_vector(31 downto 0);       -- Address
      BE        : std_logic_vector(7 downto 0);        -- Byte Enable
      LENGTH    : std_logic_vector(11 downto 0);       -- Length
      TAG_IN    : std_logic_vector(7 downto 0);        -- Read Transaction Tag (Input)
      REQ       : std_logic;                           -- Read Request
      ARDY      : std_logic;                           -- Address Ready
      ACCEPT    : std_logic;                           -- Accept
      SOF_IN    : std_logic;                           -- Start of Frame (Input)
      EOF_IN    : std_logic;                           -- End of Frame (Intput)
      -- Output interface
      TAG_OUT   : std_logic_vector(15 downto 0);       -- Read Transaction Tag (Output)
      DATA      : std_logic_vector(63 downto 0);       -- Read Data
      SRC_RDY   : std_logic;                           -- Data Ready
      DST_RDY   : std_logic;                           -- Endpoint Ready
      SOF_OUT   : std_logic;                           -- Start of Frame (Output)
      EOF_OUT   : std_logic;                           -- End of Frame (Output)
   end record;


   -- Internal Bus BM Interface
   type t_ibbm_64 is record
      -- Master Interface Input
      GLOBAL_ADDR   : std_logic_vector(63 downto 0);   -- Global Address 
      LOCAL_ADDR    : std_logic_vector(31 downto 0);   -- Local Address
      LENGTH        : std_logic_vector(11 downto 0);   -- Length
      TAG           : std_logic_vector(15 downto 0);   -- Operation TAG
      TRANS_TYPE    : std_logic_vector(1 downto 0);    -- Type of transaction
      REQ           : std_logic;                       -- Request
                 
      -- Master Output interface
      ACK           : std_logic;                       -- Ack
      OP_TAG        : std_logic_vector(15 downto 0);   -- Operation TAG
      OP_DONE       : std_logic;                       -- Acknowledge
   end record;


end ib_pkg;


-- ----------------------------------------------------------------------------
--                        Internal Bus Package
-- ----------------------------------------------------------------------------
package body ib_pkg is
       
end ib_pkg;

