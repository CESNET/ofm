-- addr_manager_ent.vhd: manages free space and addresses for PCIe transactions
-- Copyright (c) 2022 CESNET z.s.p.o.
-- Author(s): Radek Iša <isa@cesnet.cz>, Vladislav Valek <xvalek14@vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-CLause


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.math_pack.all;


-- -----------------------------------------------------------------------------
-- PCIE_ADDR_GEN
-- -----------------------------------------------------------------------------

-- This module generates pcie headers acording to packets size. The module generates
-- number of geneaders depending on INPUT_SIZE and BLOCK_SIZE. Number of generated headers
-- is round up INPUT_SIZE/BLOCK_SIZE

entity PCIE_ADDR_GEN is
    generic (
        -- number of managed channels
        CHANNELS      : integer;
        -- size of sent segments in bytes
        BLOCK_SIZE    : integer;
        -- RAM address width
        ADDR_WIDTH    : integer   := 64;
        -- width of a pointer to the ring buffer log2(NUMBER_OF_ITEMS)
        POINTER_WIDTH : integer   := 16;
        PKT_MTU       : integer   := 2**12;
        DEVICE        : string    := "ULTRASCALE"
        );

    port (
        --=====================================================================
        -- CLOCK AND RESET
        --=====================================================================
        CLK   : in std_logic;
        RESET : in std_logic;
        --=====================================================================


        --=====================================================================
        -- ADDRES REQUEST INTERFACE (To SW manager of the DMA)
        --=====================================================================
        -- Address requesting for channel
        ADDR_CHANNEL    : out std_logic_vector(log2(CHANNELS)-1 downto 0);
        -- Address base for channel
        ADDR_BASE       : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        -- righ buffer size. log2(NUMBER_OF_MAX_ITEMS)
        ADDR_MASK       : in  std_logic_vector(POINTER_WIDTH-1 downto 0);
        -- SW pointer to ring buffer
        ADDR_SW_POINTER : in  std_logic_vector(POINTER_WIDTH-1 downto 0);
        --=====================================================================


        --=====================================================================
        -- HW UPDATE ADDRESS INTERFACE (To SW manager)
        --=====================================================================
        POINTER_UPDATE_CHAN : out std_logic_vector(log2(CHANNELS)-1 downto 0);
        POINTER_UPDATE_DATA : out std_logic_vector(POINTER_WIDTH-1 downto 0);
        POINTER_UPDATE_EN   : out std_logic;
        --=====================================================================

        --=====================================================================
        -- RESET ADDRESS MANAGER 
        --=====================================================================
        -- if one bit of this signal is set, the coresponding channel's HW address is reset
        CHANNEL_RESET : in  std_logic_vector(CHANNELS-1 downto 0);
        --=====================================================================

        --=====================================================================
        -- REQUEST ADDRES FOR CHANNEL (Metadata instructions)
        --=====================================================================
        -- Requested channel
        INPUT_DISC    : in std_logic;
        INPUT_CHANNEL : in std_logic_vector(log2(CHANNELS)-1 downto 0);
        INPUT_SIZE    : in std_logic_vector(log2(PKT_MTU+1) -1 downto 0);

        INPUT_SRC_RDY : in  std_logic;
        INPUT_DST_RDY : out std_logic;
        --=====================================================================

        --=====================================================================
        -- RESPONSE ADDRES (To be inserted to the PCIex header)
        --=====================================================================
        -- Address to RAM
        OUT_ADDR      : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        OUT_OFFSET    : out std_logic_vector(POINTER_WIDTH-1 downto 0);
        OUT_ADDR_VLD  : out std_logic;
        OUT_DISC      : out std_logic;
        OUT_LAST      : out std_logic;
        OUT_FIRST     : out std_logic;
        -- this signal have two clock delay. If you want to stop receiving new 
        OUT_DST_RDY   : in std_logic
    );

end entity;
