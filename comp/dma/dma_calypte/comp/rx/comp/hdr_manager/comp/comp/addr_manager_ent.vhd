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
-- ADDR_MANAGER
-- -----------------------------------------------------------------------------

-- This component manages ring buffers in RAM where the data are sent.
-- Every channel has its own ring buffer.


-- Component is working as follows: After receiving request address for the specific
-- channel, the HW pointers are increased and the address for storing the data in RAM is created. The design cna
-- only manage constant size data.

entity ADDR_MANAGER is
    generic (
        -- number of managed channels
        CHANNELS      : integer;
        -- size of sent segments in bytes
        BLOCK_SIZE    : integer;
        -- RAM address width
        ADDR_WIDTH    : integer := 64;
        -- width of a pointer to the ring buffer log2(NUMBER_OF_ITEMS)
        POINTER_WIDTH : integer := 16;
        DEVICE        : string  := "ULTRASCALE"
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
        -- REQUEST ADDRES FOR CHANNEL (Metadata instructions)
        --=====================================================================
        -- Requested channel
        CHANNEL       : in std_logic_vector(log2(CHANNELS)-1 downto 0);
        CHANNEL_VLD   : in std_logic;
        -- if one bit of this signal is set, the coresponding channel's HW address is reset
        CHANNEL_RESET : in std_logic_vector(CHANNELS-1 downto 0);
        --=====================================================================

        --=====================================================================
        -- RESPONSE ADDRES (To be inserted to the PCIex header)
        --=====================================================================
        -- Address to RAM
        ADDR     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        OFFSET   : out std_logic_vector(POINTER_WIDTH-1 downto 0);
        ADDR_VLD : out std_logic
        );

end entity;
