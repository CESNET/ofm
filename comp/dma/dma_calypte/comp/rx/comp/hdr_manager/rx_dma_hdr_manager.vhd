-- rx_dma_hdr_manager.vhd: this component generates pcie header and dma headers for the incoming packet
-- Copyright (c) 2022 CESNET z.s.p.o.
-- Author(s): Radek Iša <isa@cesnet.cz>
--
-- SPDX-License-Identifier: BSD-3-CLause

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.math_pack.all;

-- This component generates PCIe headers and DMA header for the incoming packet
-- Fist step is to generate the DMA header. Second is to generate PCIe headers
-- for the packet number of pcie headers is ceil(PKT_SIZE/128) if DMA_DISCARD is
-- not set. Third action is generate pcie header for dma header if DMA_DISCARD
-- is not set. In case when DMA_DISCARD is set then no pcie headers are
-- generated.
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
        CLK   : in std_logic;
        RESET : in std_logic;

        -- =====================================================================
        -- CHANNEL START/STOP REQUEST INTERFACE
        -- =====================================================================
        -- Index of channel for which a start is requested
        START_REQ_CHANNEL : in  std_logic_vector(log2(CHANNELS)-1 downto 0);
        START_REQ_VLD     : in  std_logic;
        -- Channel start confirmation
        START_REQ_DONE    : out std_logic;

        -- Index of channel for whic a stop is requested
        STOP_REQ_CHANNEL : in  std_logic_vector(log2(CHANNELS)-1 downto 0);
        STOP_REQ_VLD     : in  std_logic;
        -- Channel stop confirmation
        STOP_REQ_DONE    : out std_logic;

        -- =====================================================================
        -- ADDRESS/POINTER READ INTERFACES
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
        -- HW POINTER UPDATE INTERFACE
        -- =====================================================================
        -- Update data pointers
        HDP_UPDATE_CHAN : out std_logic_vector(log2(CHANNELS)-1 downto 0);
        HDP_UPDATE_DATA : out std_logic_vector(POINTER_WIDTH-1 downto 0);
        HDP_UPDATE_EN   : out std_logic;

        -- Update header pointers
        HHP_UPDATE_CHAN : out std_logic_vector(log2(CHANNELS)-1 downto 0);
        HHP_UPDATE_DATA : out std_logic_vector(POINTER_WIDTH-1 downto 0);
        HHP_UPDATE_EN   : out std_logic;

        -- =====================================================================
        -- INFORMATION ABOUT PACKET (MVB INPUT)
        -- =====================================================================
        -- Input metadata to packet
        INF_META     : in  std_logic_vector(METADATA_SIZE-1 downto 0);
        INF_CHANNEL  : in  std_logic_vector(log2(CHANNELS)-1 downto 0);
        -- * Packet size.
        -- * Number of generated PCIE headers for a packet is ceil(INF_PKT_SIZE/128)+1
        INF_PKT_SIZE : in  std_logic_vector(log2(PKT_MTU+1)-1 downto 0);
        INF_VLD      : in  std_logic_vector(0 downto 0);
        INF_SRC_RDY  : in  std_logic;
        INF_DST_RDY  : out std_logic;

        -- =====================================================================
        -- PCIE HEADERs (MVB OUTPUT)
        -- =====================================================================
        -- PCIE header size, the values can be (also applies for DATA_PCIE_HDR_SIZE):
        --
        -- * 0 => DMA_PCIE_HDR(3*32-1 downto 0) bits are valid,
        -- * 1 => DMA_PCIE_HDR(4*32-1 downto 0) bits are valid
        DMA_PCIE_HDR_SIZE    : out std_logic;
        -- PCIE header content (vendor specific)
        DMA_PCIE_HDR         : out std_logic_vector(4*32-1 downto 0);
        DMA_PCIE_HDR_SRC_RDY : out std_logic;
        DMA_PCIE_HDR_DST_RDY : in  std_logic;

        DATA_PCIE_HDR_SIZE    : out std_logic;
        DATA_PCIE_HDR         : out std_logic_vector(4*32-1 downto 0);
        DATA_PCIE_HDR_SRC_RDY : out std_logic;
        DATA_PCIE_HDR_DST_RDY : in  std_logic;

        -- =====================================================================
        -- PCIE HEADER (MVB OUTPUT)
        -- =====================================================================
        -- Channel to which a packet is sent
        DMA_CHANNEL     : out std_logic_vector(log2(CHANNELS)-1 downto 0);
        -- Signals if the current packet should be discarded
        DMA_DISCARD     : out std_logic;
        -- DMA header content
        DMA_HDR         : out std_logic_vector(64-1 downto 0);
        -- This is allways '1'
        DMA_HDR_VLD     : out std_logic_vector(0 downto 0);
        DMA_HDR_SRC_RDY : out std_logic;
        DMA_HDR_DST_RDY : in  std_logic
        );
end entity;

architecture FULL of RX_DMA_HDR_MANAGER is

    -- Status registers. This register represents if channel is running or it is stopped.
    signal channel_status_reg : std_logic_vector(CHANNELS-1 downto 0);
    signal channel_stop_vld   : std_logic;
    -- Before channel is stopped all generated dma headers have to be send out before stop request arrives.
    signal channel_stop_size  : unsigned(log2(16) downto 0);

    -- Signal input fifo for buffering inputs.
    -- NOTE: Possibly can be removed.
    signal input_fifo_in     : std_logic_vector(METADATA_SIZE + log2(CHANNELS) + log2(PKT_MTU+1) -1 downto 0);
    signal input_fifo_wr     : std_logic;
    signal input_fifo_full   : std_logic;
    signal input_fifo_do     : std_logic_vector(METADATA_SIZE + log2(CHANNELS) + log2(PKT_MTU+1) -1 downto 0);
    signal input_fifo_rd     : std_logic;
    signal input_fifo_empty  : std_logic;
    signal input_packet_next : std_logic;

    -- This signals values are stored in input_fifo_do
    signal input_meta           : std_logic_vector(METADATA_SIZE -1 downto 0);
    signal input_channel        : std_logic_vector(log2(CHANNELS) -1 downto 0);
    signal input_pkt_size       : std_logic_vector(log2(PKT_MTU+1) -1 downto 0);

    -- Storing fifo for pcie headers, this one is for dma pcie header which is generated only once
    -- per packet.
    signal pcie_hdr_dma_fifo_in    : std_logic_vector(1 +4*32 -1 downto 0);
    signal pcie_hdr_dma_fifo_wr    : std_logic;
    signal pcie_hdr_dma_fifo_full  : std_logic;
    signal pcie_hdr_dma_fifo_do    : std_logic_vector (1 +4*32 -1 downto 0);
    signal pcie_hdr_dma_fifo_rd    : std_logic;
    signal pcie_hdr_dma_fifo_empty : std_logic;

    -- Storing fifo for pcie header, this one is for data pcie header.
    signal pcie_hdr_data_fifo_in    : std_logic_vector(1 +4*32 -1 downto 0);
    signal pcie_hdr_data_fifo_wr    : std_logic;
    signal pcie_hdr_data_fifo_full  : std_logic;
    signal pcie_hdr_data_fifo_do    : std_logic_vector(1 +4*32 -1 downto 0);
    signal pcie_hdr_data_fifo_rd    : std_logic;
    signal pcie_hdr_data_fifo_empty : std_logic;

    -- Storing fifo for dma header. The DMA header contains the information of a packet.
    signal dma_hdr_fifo_in     : std_logic_vector(log2(CHANNELS) +1 +64 -1 downto 0);
    signal dma_hdr_fifo_wr     : std_logic;
    signal dma_hdr_fifo_full   : std_logic;
    signal dma_hdr_fifo_do     : std_logic_vector(log2(CHANNELS) +1 +64 -1 downto 0);
    signal dma_hdr_fifo_rd     : std_logic;
    signal dma_hdr_fifo_empty  : std_logic;
    signal dma_hdr_fifo_status : std_logic_vector(log2(16) downto 0);

    -- Signals driving componenet which generate pointers to memory for data
    -- if this signal is set then data addr meneger contains valid data
    signal data_packet_next   : std_logic;
    -- signals for generating pointer data in a RAM.
    signal data_hdr_addr       : std_logic_vector(ADDR_WIDTH -1 downto 0);
    signal data_hdr_offset     : std_logic_vector(POINTER_WIDTH -1 downto 0);
    signal data_hdr_addr_vld   : std_logic;
    signal data_hdr_discard    : std_logic;
    signal data_hdr_rdy        : std_logic;
    signal data_hdr_first      : std_logic;
    signal data_packet_end     : std_logic;

    -- Signals driving componenet which generate pointers to memory for dma
    -- if this signal is set then data addr meneger contains valid data
    signal dma_packet_next   : std_logic;
    -- signals for generating pointer data in a RAM.
    signal dma_hdr_addr       : std_logic_vector(ADDR_WIDTH -1 downto 0);
    signal dma_hdr_addr_vld   : std_logic;
    signal dma_hdr_rdy    : std_logic;

    --==============================================================================================
    -- signals for generating pcie header for data
    --==============================================================================================
    -- determines if the PCIe header is the size of 3 or 4 DWs
    signal pcie_hdr_len_data_trans        : std_logic;
    signal pcie_hdr_data_trans            : std_logic_vector(128-1 downto 0);
    --==============================================================================================

    --==============================================================================================
    -- signals containing generated pcie header for dma
    --==============================================================================================
    -- determines if the PCIe header is the size of 3 or 4 DWs
    signal pcie_hdr_len_dma_trans        : std_logic;
    signal pcie_hdr_dma_hdr              : std_logic_vector(128-1 downto 0);
    --==============================================================================================

    -- delay registers for generating dma header
    -- 1 clock delay
    signal dma_hdr_r0_meta       : std_logic_vector(METADATA_SIZE -1 downto 0);
    signal dma_hdr_r0_channel    : std_logic_vector(log2(CHANNELS) -1 downto 0);
    signal dma_hdr_r0_size       : std_logic_vector(log2(PKT_MTU+1) -1 downto 0);
    signal dma_hdr_r0_vld        : std_logic;
    -- 2 clock delay
    signal dma_hdr_r1_meta       : std_logic_vector(METADATA_SIZE -1 downto 0);
    signal dma_hdr_r1_channel    : std_logic_vector(log2(CHANNELS) -1 downto 0);
    signal dma_hdr_r1_size       : std_logic_vector(log2(PKT_MTU+1) -1 downto 0);
    signal dma_hdr_r1_vld        : std_logic;

    -- attribute mark_debug : string;

    -- attribute mark_debug of channel_stop_size   : signal is "true";
    -- attribute mark_debug of channel_stop_vld    : signal is "true";
    -- attribute mark_debug of dma_hdr_fifo_status : signal is "true";
    -- attribute mark_debug of dma_hdr_r0_vld      : signal is "true";
    -- attribute mark_debug of dma_hdr_r1_vld      : signal is "true";
    -- attribute mark_debug of dma_hdr_fifo_rd     : signal is "true";

    -- attribute mark_debug of channel_status_reg : signal is "true";
    -- attribute mark_debug of data_hdr_rdy       : signal is "true";
    -- attribute mark_debug of data_hdr_first     : signal is "true";
    -- attribute mark_debug of dma_hdr_rdy        : signal is "true";
begin

    --=====================================================================
    -- RUN channels
    --=====================================================================
    channel_status_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            START_REQ_DONE <= '0';

            if (RESET = '1') then

                channel_status_reg <= (others => '0');

            elsif (STOP_REQ_VLD = '1') then

                channel_status_reg(to_integer(unsigned(STOP_REQ_CHANNEL))) <= '0';

            elsif (START_REQ_VLD = '1') then

                START_REQ_DONE                                              <= '1';
                channel_status_reg(to_integer(unsigned(START_REQ_CHANNEL))) <= '1';

            end if;
        end if;
    end process;

    --stop logic
    channel_stop_p : process (CLK)
    begin
        if (rising_edge(CLK)) then

            if (RESET = '1') then
                channel_stop_vld <= '0';

            elsif (STOP_REQ_VLD = '1') then
                channel_stop_vld <= '1';

            elsif (STOP_REQ_DONE = '1') then
                channel_stop_vld <= '0';

            end if;

            if (STOP_REQ_VLD = '1') then
                -- the FIFO for the DMA header needs to be emptied
                channel_stop_size <= unsigned(dma_hdr_fifo_status) + dma_hdr_r0_vld + dma_hdr_r1_vld - dma_hdr_fifo_rd;

            elsif (dma_hdr_fifo_rd = '1') then
                channel_stop_size <= channel_stop_size -1;

            end if;
        end if;
    end process;

    STOP_REQ_DONE <= '1' when channel_stop_size = 0 and channel_stop_vld = '1' else '0';

    --=====================================================================
    -- INPUT FIFO
    --=====================================================================

    input_fifo_in <= INF_META & INF_CHANNEL & INF_PKT_SIZE;
    -- the write is permitted only if there are a valid data on the input and the FIFO is not full
    input_fifo_wr <= (or INF_VLD) and INF_SRC_RDY and (not input_fifo_full);
    INF_DST_RDY   <= not input_fifo_full;

    input_mvb_fifo_i : entity work.fifox
        generic map (
            DATA_WIDTH => METADATA_SIZE + log2(CHANNELS) + log2(PKT_MTU+1),
            ITEMS      => 16,
            DEVICE     => DEVICE
        )
        port map(
            CLK   => CLK,
            RESET => RESET,

            DI   => input_fifo_in,
            WR   => input_fifo_wr,
            FULL => input_fifo_full,

            DO    => input_fifo_do,
            RD    => input_fifo_rd,
            EMPTY => input_fifo_empty
        );

    (input_meta, input_channel, input_pkt_size) <= input_fifo_do;

    -- permits the read from the input metadata FIFO, all output FIFOs must not be full
    input_packet_next <= dma_packet_next   and data_packet_next and (not dma_hdr_fifo_full);
    input_fifo_rd     <= input_packet_next and (not input_fifo_empty);
    --==============================================================================================

    --=====================================================================
    -- DATA
    --=====================================================================
    data_pcie_addr_gen_i : entity work.pcie_addr_gen
        generic map (
            CHANNELS      => CHANNELS,
            BLOCK_SIZE    => 128,
            ADDR_WIDTH    => ADDR_WIDTH,
            POINTER_WIDTH => POINTER_WIDTH,
            PKT_MTU       => PKT_MTU,
            DEVICE        => DEVICE
        )
        port map(
            CLK   => CLK,
            RESET => RESET,

            ADDR_CHANNEL    => ADDR_DATA_CHANNEL,
            ADDR_BASE       => ADDR_DATA_BASE,
            ADDR_MASK       => ADDR_DATA_MASK,
            ADDR_SW_POINTER => ADDR_DATA_SW_POINTER,

            POINTER_UPDATE_CHAN => HDP_UPDATE_CHAN,
            POINTER_UPDATE_DATA => HDP_UPDATE_DATA,
            POINTER_UPDATE_EN   => HDP_UPDATE_EN,

            START_REQ_VLD     => START_REQ_VLD,
            START_REQ_CHANNEL => START_REQ_CHANNEL,

            INPUT_DISC     => (not channel_status_reg(to_integer(unsigned(input_channel)))),
            INPUT_CHANNEL  => input_channel,
            INPUT_SIZE     => input_pkt_size,

            INPUT_SRC_RDY  => input_fifo_rd,
            INPUT_DST_RDY  => data_packet_next,

            OUT_ADDR      => data_hdr_addr,
            OUT_OFFSET    => data_hdr_offset,
            OUT_ADDR_VLD  => data_hdr_addr_vld,
            OUT_DISC      => data_hdr_discard,
            OUT_FIRST     => data_hdr_first,
            OUT_LAST      => open,
            OUT_DST_RDY   => data_hdr_rdy
        );

    data_hdr_rdy <= '1' when pcie_hdr_data_fifo_full = '0' else '0';


    --=====================================================================
    -- DMA
    --=====================================================================
    dma_pcie_addr_gen_i : entity work.pcie_addr_gen
        generic map (
            CHANNELS      => CHANNELS,
            BLOCK_SIZE    => 8,
            ADDR_WIDTH    => ADDR_WIDTH,
            POINTER_WIDTH => POINTER_WIDTH,
            PKT_MTU       => 8,
            DEVICE        => DEVICE
        )
        port map(
            CLK   => CLK,
            RESET => RESET,

            ADDR_CHANNEL    => ADDR_HEADER_CHANNEL,
            ADDR_BASE       => ADDR_HEADER_BASE,
            ADDR_MASK       => ADDR_HEADER_MASK,
            ADDR_SW_POINTER => ADDR_HEADER_SW_POINTER,

            POINTER_UPDATE_CHAN => HHP_UPDATE_CHAN,
            POINTER_UPDATE_DATA => HHP_UPDATE_DATA,
            POINTER_UPDATE_EN   => HHP_UPDATE_EN,

            START_REQ_VLD     => START_REQ_VLD,
            START_REQ_CHANNEL => START_REQ_CHANNEL,

            INPUT_DISC     => (not channel_status_reg(to_integer(unsigned(input_channel)))),
            INPUT_CHANNEL  => input_channel,
            INPUT_SIZE     => std_logic_vector(to_unsigned(8, log2(8+1))),

            INPUT_SRC_RDY  => input_fifo_rd,
            INPUT_DST_RDY  => dma_packet_next,

            OUT_ADDR      => dma_hdr_addr,
            OUT_ADDR_VLD  => dma_hdr_addr_vld,
            OUT_DST_RDY   => dma_hdr_rdy
        );

    dma_hdr_rdy <= '1' when pcie_hdr_dma_fifo_full = '0' else '0';


    --=====================================================================
    -- PCIE HDR OUTPUT FIFO
    --=====================================================================
    --DMA
    pcie_hdr_gen_dma_i : entity work.PCIE_RQ_HDR_GEN
        generic map (
            DEVICE => DEVICE)
        port map (
            IN_ADDRESS    => dma_hdr_addr(63 downto 2),
            IN_VFID       => (others => '0'),
            IN_TAG        => (others => '0'),
            IN_DW_CNT     => std_logic_vector(to_unsigned(8/4, 11)),
            IN_ATTRIBUTES => "000",
            IN_FBE        => "1111",
            IN_LBE        => "1111",
            IN_ADDR_LEN   => pcie_hdr_len_dma_trans,
            IN_REQ_TYPE   => '1',       -- only memory writes

            OUT_HEADER    => pcie_hdr_dma_hdr);

    pcie_hdr_len_dma_trans <= '1' when (DEVICE = "ULTRASCALE" or dma_hdr_addr(64-1 downto 32) /= (32-1 downto 0 => '0')) else '0';
    pcie_hdr_dma_fifo_in <= pcie_hdr_len_dma_trans & pcie_hdr_dma_hdr;
    pcie_hdr_dma_fifo_wr <= dma_hdr_addr_vld;

    pcie_hdr_dma_fifo_i : entity work.fifox
        generic map (
            DATA_WIDTH         => 1 +4*32,       -- SIZE + PCIE HDR
            ITEMS              => 16,
            DEVICE             => DEVICE,
            ALMOST_FULL_OFFSET => 2
            )
        port map(
            CLK   => CLK,
            RESET => RESET,

            DI    => pcie_hdr_dma_fifo_in,
            WR    => pcie_hdr_dma_fifo_wr,
            AFULL => pcie_hdr_dma_fifo_full,

            DO    => pcie_hdr_dma_fifo_do,
            RD    => pcie_hdr_dma_fifo_rd,
            EMPTY => pcie_hdr_dma_fifo_empty
            );

    -- DATA
    pcie_hdr_gen_data_i : entity work.PCIE_RQ_HDR_GEN
        generic map (
            DEVICE => DEVICE)
        port map (
            IN_ADDRESS    => data_hdr_addr(63 downto 2),
            IN_VFID       => (others => '0'),
            IN_TAG        => (others => '0'),
            IN_DW_CNT     => std_logic_vector(to_unsigned(128/4, 11)),
            IN_ATTRIBUTES => "000",
            IN_FBE        => "1111",
            IN_LBE        => "1111",
            IN_ADDR_LEN   => pcie_hdr_len_data_trans,
            IN_REQ_TYPE   => '1',       -- only memory writes

            OUT_HEADER    => pcie_hdr_data_trans);

    pcie_hdr_len_data_trans <= '1' when (DEVICE = "ULTRASCALE" or data_hdr_addr(64-1 downto 32) /= (32-1 downto 0 => '0')) else '0';
    pcie_hdr_data_fifo_in   <= pcie_hdr_len_data_trans & pcie_hdr_data_trans;
    pcie_hdr_data_fifo_wr <= data_hdr_addr_vld;


    pcie_hdr_data_fifo_i : entity work.fifox
        generic map (
            DATA_WIDTH         => 1 +4*32,     --  END_PACKET + SIZE + PCIE HDR
            ITEMS              => 64,
            DEVICE             => DEVICE,
            ALMOST_FULL_OFFSET => 2
            )
        port map(
            CLK   => CLK,
            RESET => RESET,

            DI    => pcie_hdr_data_fifo_in,
            WR    => pcie_hdr_data_fifo_wr,
            AFULL => pcie_hdr_data_fifo_full,

            DO    => pcie_hdr_data_fifo_do,
            RD    => pcie_hdr_data_fifo_rd,
            EMPTY => pcie_hdr_data_fifo_empty
            );

    -- MULTIPLEXOR if the end of segment has been reached then switch the output to the PCIe headers for the DMA
    -- header, otherwise choose the PCIe headers for the ordinary data
    (DMA_PCIE_HDR_SIZE, DMA_PCIE_HDR) <= pcie_hdr_dma_fifo_do;
    DMA_PCIE_HDR_SRC_RDY              <= (not pcie_hdr_dma_fifo_empty);
    pcie_hdr_dma_fifo_rd              <= DMA_PCIE_HDR_DST_RDY and (not pcie_hdr_dma_fifo_empty);

    (DATA_PCIE_HDR_SIZE, DATA_PCIE_HDR) <= pcie_hdr_data_fifo_do;
    DATA_PCIE_HDR_SRC_RDY               <= (not pcie_hdr_data_fifo_empty);
    pcie_hdr_data_fifo_rd               <= DATA_PCIE_HDR_DST_RDY and (not pcie_hdr_data_fifo_empty);

    --=====================================================================
    -- DMA HDR FIRST REG
    --=====================================================================
    -- This process save inportant metainformation about packet to wait for valid offset.
    -- Fifo is not save because max 2 clock delay is required


    dma_hdr_input : process(CLK)
    begin
        if (rising_edge(CLK)) then
            if (RESET = '1') then
                dma_hdr_r0_vld <= '0';
                dma_hdr_r1_vld <= '0';
            else
                if (input_fifo_rd = '1' or dma_hdr_r1_vld = '0' or data_hdr_first = '1') then
                    dma_hdr_r0_vld     <= input_fifo_rd;
                    dma_hdr_r0_meta    <= input_meta;
                    dma_hdr_r0_channel <= input_channel;
                    dma_hdr_r0_size    <= input_pkt_size;
                end if;

                if (dma_hdr_r1_vld = '0' or data_hdr_first = '1') then
                    dma_hdr_r1_vld     <= dma_hdr_r0_vld;
                    dma_hdr_r1_meta    <= dma_hdr_r0_meta;
                    dma_hdr_r1_channel <= dma_hdr_r0_channel;
                    dma_hdr_r1_size    <= dma_hdr_r0_size;
                end if;
            end if;
        end if;
    end process;

    -- set input to dma fifo
    dma_hdr_fifo_in(log2(CHANNELS) +1 +64 -1 downto 64 +1) <= dma_hdr_r1_channel;
    dma_hdr_fifo_in(64) <= data_hdr_discard;

    dma_hdr_fifo_in(64-1 downto 0) <=   (24-1 downto METADATA_SIZE => '0') & dma_hdr_r1_meta
                                      & (7-1 downto 0 => '0')
                                      & '1'
                                      & std_logic_vector(resize(unsigned(data_hdr_offset),16))
                                      & (16-1 downto log2(PKT_MTU+1) => '0') & dma_hdr_r1_size;

    dma_hdr_fifo_wr <= data_hdr_first;

    dma_hdr_fifo_i : entity work.fifox
        generic map (
            DATA_WIDTH         => log2(CHANNELS) +1 +64,  -- DISCARD +  PCIE HDR
            ITEMS              => 16,
            DEVICE             => DEVICE,
            ALMOST_FULL_OFFSET => 2
            )
        port map(
            CLK   => CLK,
            RESET => RESET,

            DI    => dma_hdr_fifo_in,
            WR    => dma_hdr_fifo_wr,
            AFULL => dma_hdr_fifo_full,

            STATUS => dma_hdr_fifo_status,

            DO    => dma_hdr_fifo_do,
            RD    => dma_hdr_fifo_rd,
            EMPTY => dma_hdr_fifo_empty
            );

    (DMA_CHANNEL, DMA_DISCARD, DMA_HDR) <= dma_hdr_fifo_do;
    DMA_HDR_VLD                         <= "1";
    DMA_HDR_SRC_RDY                     <= not dma_hdr_fifo_empty;
    dma_hdr_fifo_rd                     <= DMA_HDR_DST_RDY and (not dma_hdr_fifo_empty);

end architecture;
