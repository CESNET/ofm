-- hdr_manager_ent.vhd:
-- Copyright (c) 2022 CESNET z.s.p.o.
-- Author(s): Radek Iša <isa@cesnet.cz>
--
-- SPDX-License-Identifier: BSD-3-CLause

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.math_pack.all;



-- -----------------------------------------------------------------------------
-- ADDR_MANAGER
-- -----------------------------------------------------------------------------
-- This component generates PCIe headers and DMA header for the incoming packet
-- Fist step is to generate the DMA header.
-- Second is to generate PCIe headers for the packet number of pcie headers is ceil(PKT_SIZE/128)
-- if DMA_DISCARD is not set.
-- Third action is generate pcie header for dma header if DMA_DISCARD is not set.
-- In case when DMA_DISCARD is set then no pcie headers are generated.
entity RX_DMA_HDR_MANAGER is
    generic (
        -- Number of channels
        CHANNELS      : integer := 16;
        -- Maximum packet size in bytes
        PKT_MTU       : integer := 2**12;
        -- Size of the metadata in the DMA header
        METADATA_SIZE : integer := 24;
        -- RAM address width
        ADDR_WIDTH    : integer := 64;
        -- width of a pointer to the ring buffer log2(NUMBER_OF_ITEMS)
        POINTER_WIDTH : integer := 16;
        -- The DEVICE parameter allows the correct selection of the RAM
        -- implementation according to the FPGA used. Supported values are:
        --
        -- - "7SERIES"
        -- - "ULTRASCALE"
        DEVICE        : string  := "ULTRASCALE"
        );

    port (
        -- =====================================================================
        -- CLOCK AND RESET
        -- =====================================================================

        CLK   : in std_logic;
        RESET : in std_logic;


        -- =====================================================================
        --  CHANNEL START/STOP REQUEST INTERFACE
        -- =====================================================================

        -- index of channel for which a start is requested
        START_REQ_CHANNEL : in  std_logic_vector(log2(CHANNELS)-1 downto 0);
        START_REQ_VLD     : in  std_logic;
        -- channel start confirmation
        START_REQ_DONE    : out std_logic;

        -- index of channel for whic a stop is requested
        STOP_REQ_CHANNEL : in  std_logic_vector(log2(CHANNELS)-1 downto 0);
        STOP_REQ_VLD     : in  std_logic;
        -- channel stop confirmation
        STOP_REQ_DONE    : out std_logic;


        -- =====================================================================
        --  ADDRESS/POINTER READ INTERFACES
        -- =====================================================================

        -- Request interface for data space
        ADDR_DATA_CHANNEL    : out std_logic_vector(log2(CHANNELS)-1 downto 0);
        ADDR_DATA_BASE       : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        ADDR_DATA_MASK       : in  std_logic_vector(POINTER_WIDTH-1 downto 0);
        ADDR_DATA_SW_POINTER : in  std_logic_vector(POINTER_WIDTH-1 downto 0);

        -- Request interface for dma headers
        ADDR_HEADER_CHANNEL    : out std_logic_vector(log2(CHANNELS)-1 downto 0);
        ADDR_HEADER_BASE       : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        ADDR_HEADER_MASK       : in  std_logic_vector(POINTER_WIDTH-1 downto 0);
        ADDR_HEADER_SW_POINTER : in  std_logic_vector(POINTER_WIDTH-1 downto 0);


        -- =====================================================================
        --  HW POINTER UPDATE INTERFACE
        -- =====================================================================

        -- update data pointers
        HDP_UPDATE_CHAN : out std_logic_vector(log2(CHANNELS)-1 downto 0);
        HDP_UPDATE_DATA : out std_logic_vector(POINTER_WIDTH-1 downto 0);
        HDP_UPDATE_EN   : out std_logic;

        -- update header pointers
        HHP_UPDATE_CHAN : out std_logic_vector(log2(CHANNELS)-1 downto 0);
        HHP_UPDATE_DATA : out std_logic_vector(POINTER_WIDTH-1 downto 0);
        HHP_UPDATE_EN   : out std_logic;


        -- =====================================================================
        --  INFORMATION ABOUT PACKET (MVB INPUT)
        -- =====================================================================

        -- Input metadata to packet
        INF_META     : in  std_logic_vector(METADATA_SIZE-1 downto 0);
        INF_CHANNEL  : in  std_logic_vector(log2(CHANNELS)-1 downto 0);
        -- Packet size. Number of generated PCIE header for packet is roud_up(INF_PKT_SIZE/128)+1
        INF_PKT_SIZE : in  std_logic_vector(log2(PKT_MTU+1)-1 downto 0);
        INF_VLD      : in  std_logic_vector(0 downto 0);
        INF_SRC_RDY  : in  std_logic;
        INF_DST_RDY  : out std_logic;


        -- =====================================================================
        --  PCIE HEADER (MVB OUTPUT)
        -- =====================================================================
        -- PCIE header size, the values can be:
        -- 0 => PCIE_HDR(3*32-1 downto 0) bits are valid,
        -- 1 => PCIE_HDR(4*32-1 downto 0) bits are valid
        PCIE_HDR_SIZE    : out std_logic;
        -- PCIE header content, can be vendor specific
        PCIE_HDR         : out std_logic_vector(4*32-1 downto 0);
        PCIE_HDR_VLD     : out std_logic_vector(0 downto 0);
        PCIE_HDR_SRC_RDY : out std_logic;
        PCIE_HDR_DST_RDY : in  std_logic;


        -- =====================================================================
        --  PCIE HEADER (MVB OUTPUT)
        -- =====================================================================

        -- Channel to which a packet is sent
        DMA_CHANNEL     : out std_logic_vector(log2(CHANNELS)-1 downto 0);
        -- Signals if the current packet should be discarded
        DMA_DISCARD     : out std_logic;
        -- DMA header content
        DMA_HDR         : out std_logic_vector(64-1 downto 0);
        -- this is allways '1
        DMA_HDR_VLD     : out std_logic_vector(0 downto 0);
        DMA_HDR_SRC_RDY : out std_logic;
        DMA_HDR_DST_RDY : in  std_logic
        );
end entity;
