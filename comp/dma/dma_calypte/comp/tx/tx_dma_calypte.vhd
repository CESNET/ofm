-- tx_dma_calypte.vhd: connecting all important parts of the TX DMA Calypte and adds small logic to
-- connections when necessary
-- Copyright (C) 2023 CESNET z.s.p.o.
-- Author(s): Vladislav Valek  <xvalek14@vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Note:

use work.math_pack.all;
use work.type_pack.all;
use work.pcie_meta_pack.all;

-- .. WARNING::
--    The Completer Completion interface is not supported yet. Calypte Controller
--    supports only Memory Write PCIe transactions.
--
-- This is the transmitting part of the DMA Calypte core. TX direction behaves
-- similarly to the RX DMA Calypte. Data buffers are provided in the hardware to
-- which the data can be stored. The frames are output on the *USR_TX_* side and
-- PCI Express transactions are accepted on the *PCIE_CQ_* side. Output frame
-- can constist out of multiple PCIe transactions. Each such frame is delimited
-- by the DMA header which provides the size of the frame as well as the channel
-- to which the frame is designated and an address of the first byte of the
-- frame. PCIe transactions can be send on the unsorted series of adresses. The
-- DMA header then serves as delimiting block where, after its acceptance,
-- the frame on the output is read continuously from the address of the first
-- byte. The block scheme of the TX DMA Calypte controller is provided in the
-- following figure:
--
-- .. figure:: img/tx_calypte_block-tx_dma_calypte_top.svg
--     :align: center
--     :scale: 100%
--
entity TX_DMA_CALYPTE is
    generic (
        DEVICE : string := "ULTRASCALE";

        MI_WIDTH : natural := 32;

        -- =========================================================================================
        -- Output interface to the FPGA user logic
        -- =========================================================================================
        USR_TX_MFB_REGIONS     : natural := 1;
        USR_TX_MFB_REGION_SIZE : natural := 4;
        USR_TX_MFB_BLOCK_SIZE  : natural := 8;
        USR_TX_MFB_ITEM_WIDTH  : natural := 8;

        -- =========================================================================================
        -- Input PCIe interface (Completer Request)
        -- =========================================================================================
        PCIE_CQ_MFB_REGIONS     : natural := 1;
        PCIE_CQ_MFB_REGION_SIZE : natural := 1;
        PCIE_CQ_MFB_BLOCK_SIZE  : natural := 8;
        PCIE_CQ_MFB_ITEM_WIDTH  : natural := 32;

        -- =========================================================================================
        -- Output PCIe interface (Completer Completion) MFB setting
        -- =========================================================================================
        PCIE_CC_MFB_REGIONS     : natural := 1;
        PCIE_CC_MFB_REGION_SIZE : natural := 1;
        PCIE_CC_MFB_BLOCK_SIZE  : natural := 8;
        PCIE_CC_MFB_ITEM_WIDTH  : natural := 32;

        -- =========================================================================================
        -- Setting of internal components
        -- =========================================================================================
        -- Pointer width for data and hdr buffers. The data pointer points to bytes of the packet.
        -- The header pointer points to the header of a current packet.
        DATA_POINTER_WIDTH    : natural := 14;
        DMA_HDR_POINTER_WIDTH : natural := 9;
        -- Set the number of DMA channels, each channel has its separate buffer
        CHANNELS              : natural := 8;

        -- =========================================================================================
        -- Others
        -- =========================================================================================
        -- Set the width of counters of packets for each channel which are there to provide some
        -- entry level statistics.
        CNTRS_WIDTH    : natural := 64;
        -- Width of the metadata in bits which are stored in the DMA header.
        HDR_META_WIDTH : natural := 24;
        -- Size of the largest packets that can be transmitted on the USR_TX_MFB interface.
        PKT_SIZE_MAX   : natural := 2**14
        );
    port (
        CLK   : in std_logic;
        RESET : in std_logic;

        -- =========================================================================================
        -- User MFB signals
        -- =========================================================================================
        USR_TX_MFB_META_PKT_SIZE : out std_logic_vector(log2(PKT_SIZE_MAX + 1) -1 downto 0);
        USR_TX_MFB_META_CHAN     : out std_logic_vector(log2(CHANNELS) -1 downto 0);
        USR_TX_MFB_META_HDR_META : out std_logic_vector(HDR_META_WIDTH -1 downto 0);

        USR_TX_MFB_DATA    : out std_logic_vector(USR_TX_MFB_REGIONS*USR_TX_MFB_REGION_SIZE*USR_TX_MFB_BLOCK_SIZE*USR_TX_MFB_ITEM_WIDTH-1 downto 0);
        USR_TX_MFB_SOF     : out std_logic_vector(USR_TX_MFB_REGIONS -1 downto 0);
        USR_TX_MFB_EOF     : out std_logic_vector(USR_TX_MFB_REGIONS -1 downto 0);
        USR_TX_MFB_SOF_POS : out std_logic_vector(USR_TX_MFB_REGIONS*max(1, log2(USR_TX_MFB_REGION_SIZE)) -1 downto 0);
        USR_TX_MFB_EOF_POS : out std_logic_vector(USR_TX_MFB_REGIONS*max(1, log2(USR_TX_MFB_REGION_SIZE*USR_TX_MFB_BLOCK_SIZE)) -1 downto 0);
        USR_TX_MFB_SRC_RDY : out std_logic;
        USR_TX_MFB_DST_RDY : in  std_logic;

        -- =========================================================================================
        -- PCIe Completer Request MFB interface
        --
        -- Accepts PCIe write and read requests
        -- =========================================================================================
        PCIE_CQ_MFB_DATA    : in  std_logic_vector(PCIE_CQ_MFB_REGIONS*PCIE_CQ_MFB_REGION_SIZE*PCIE_CQ_MFB_BLOCK_SIZE*PCIE_CQ_MFB_ITEM_WIDTH-1 downto 0);
        PCIE_CQ_MFB_META    : in  std_logic_vector(PCIE_CQ_META_WIDTH -1 downto 0);
        PCIE_CQ_MFB_SOF     : in  std_logic_vector(PCIE_CQ_MFB_REGIONS -1 downto 0);
        PCIE_CQ_MFB_EOF     : in  std_logic_vector(PCIE_CQ_MFB_REGIONS -1 downto 0);
        PCIE_CQ_MFB_SOF_POS : in  std_logic_vector(PCIE_CQ_MFB_REGIONS*max(1, log2(PCIE_CQ_MFB_REGION_SIZE)) -1 downto 0);
        PCIE_CQ_MFB_EOF_POS : in  std_logic_vector(PCIE_CQ_MFB_REGIONS*max(1, log2(PCIE_CQ_MFB_REGION_SIZE*PCIE_CQ_MFB_BLOCK_SIZE)) -1 downto 0);
        PCIE_CQ_MFB_SRC_RDY : in  std_logic;
        PCIE_CQ_MFB_DST_RDY : out std_logic := '1';

        -- =========================================================================================
        -- PCIe Completer Completion MFB interface
        --
        -- Transmits responses to read requests received on the CQ interface
        -- =========================================================================================
        PCIE_CC_MFB_DATA    : out std_logic_vector(PCIE_CC_MFB_REGIONS*PCIE_CC_MFB_REGION_SIZE*PCIE_CC_MFB_BLOCK_SIZE*PCIE_CC_MFB_ITEM_WIDTH-1 downto 0) := (others => '0');
        PCIE_CC_MFB_META    : out std_logic_vector(PCIE_CC_META_WIDTH -1 downto 0)                                                                       := (others => '0');
        PCIE_CC_MFB_SOF     : out std_logic_vector(PCIE_CC_MFB_REGIONS -1 downto 0)                                                                      := (others => '0');
        PCIE_CC_MFB_EOF     : out std_logic_vector(PCIE_CC_MFB_REGIONS -1 downto 0)                                                                      := (others => '0');
        PCIE_CC_MFB_SOF_POS : out std_logic_vector(PCIE_CC_MFB_REGIONS*max(1, log2(PCIE_CC_MFB_REGION_SIZE)) -1 downto 0)                                := (others => '0');
        PCIE_CC_MFB_EOF_POS : out std_logic_vector(PCIE_CC_MFB_REGIONS*max(1, log2(PCIE_CC_MFB_REGION_SIZE*PCIE_CC_MFB_BLOCK_SIZE)) -1 downto 0)         := (others => '0');
        PCIE_CC_MFB_SRC_RDY : out std_logic                                                                                                              := '0';
        PCIE_CC_MFB_DST_RDY : in  std_logic;

        -- =========================================================================================
        -- Control MI bus
        -- =========================================================================================
        MI_ADDR : in  std_logic_vector(MI_WIDTH -1 downto 0);
        MI_DWR  : in  std_logic_vector(MI_WIDTH -1 downto 0);
        MI_BE   : in  std_logic_vector(MI_WIDTH/8 -1 downto 0);
        MI_RD   : in  std_logic;
        MI_WR   : in  std_logic;
        MI_DRD  : out std_logic_vector(MI_WIDTH -1 downto 0);
        MI_ARDY : out std_logic;
        MI_DRDY : out std_logic
        );
end entity;

architecture FULL of TX_DMA_CALYPTE is

    -- =============================================================================================
    -- Constants and range definitions
    -- =============================================================================================
    constant PCIE_CQ_MFB_WIDTH : natural := PCIE_CQ_MFB_REGIONS*PCIE_CQ_MFB_REGION_SIZE*PCIE_CQ_MFB_BLOCK_SIZE*PCIE_CQ_MFB_ITEM_WIDTH;
    constant USR_TX_MFB_WIDTH  : natural := USR_TX_MFB_REGIONS*USR_TX_MFB_REGION_SIZE*USR_TX_MFB_BLOCK_SIZE*USR_TX_MFB_ITEM_WIDTH;

    constant META_IS_DMA_HDR_W : natural := 1;
    constant META_PCIE_ADDR_W  : natural := 62;
    constant META_CHAN_NUM_W   : natural := log2(CHANNELS);
    constant META_BE_W         : natural := PCIE_CQ_MFB_WIDTH/8;

    constant META_IS_DMA_HDR_O : natural := 0;
    constant META_PCIE_ADDR_O  : natural := META_IS_DMA_HDR_O + META_IS_DMA_HDR_W;
    constant META_CHAN_NUM_O   : natural := META_PCIE_ADDR_O + META_PCIE_ADDR_W;
    constant META_BE_O         : natural := META_CHAN_NUM_O + META_CHAN_NUM_W;

    subtype META_IS_DMA_HDR is natural range META_IS_DMA_HDR_O + META_IS_DMA_HDR_W -1 downto META_IS_DMA_HDR_O;
    subtype META_PCIE_ADDR is natural range META_PCIE_ADDR_O + META_PCIE_ADDR_W -1 downto META_PCIE_ADDR_O;
    subtype META_CHAN_NUM is natural range META_CHAN_NUM_O + META_CHAN_NUM_W -1 downto META_CHAN_NUM_O;
    subtype META_BE is natural range META_BE_O + META_BE_W -1 downto META_BE_O;

    -- =============================================================================================
    -- Interconnect signals
    -- =============================================================================================
    signal pkt_sent_chan  : std_logic_vector(log2(CHANNELS) -1 downto 0);
    signal pkt_sent_inc   : std_logic;
    signal pkt_sent_bytes : std_logic_vector(log2(PKT_SIZE_MAX+1) -1 downto 0);

    signal pkt_disc_chan  : std_logic_vector(log2(CHANNELS) -1 downto 0);
    signal pkt_disc_inc   : std_logic;
    signal pkt_disc_bytes : std_logic_vector(log2(PKT_SIZE_MAX+1) -1 downto 0);

    signal start_req_chan : std_logic_vector(log2(CHANNELS) -1 downto 0);
    signal start_req_vld  : std_logic;
    signal start_req_ack  : std_logic;

    signal stop_req_chan : std_logic_vector(log2(CHANNELS) -1 downto 0);
    signal stop_req_vld  : std_logic;
    signal stop_req_ack  : std_logic;

    signal upd_hdp_chan : std_logic_vector(log2(CHANNELS) -1 downto 0);
    signal upd_hdp_data : std_logic_vector(DATA_POINTER_WIDTH -1 downto 0);
    signal upd_hdp_en   : std_logic;

    signal upd_hhp_chan : std_logic_vector(log2(CHANNELS) -1 downto 0);
    signal upd_hhp_data : std_logic_vector(DMA_HDR_POINTER_WIDTH -1 downto 0);
    signal upd_hhp_en   : std_logic;

    signal ext_mfb_meta_is_dma_hdr : std_logic;
    signal ext_mfb_meta_pcie_addr  : std_logic_vector(62 -1 downto 0);
    signal ext_mfb_meta_chan_num   : std_logic_vector(log2(CHANNELS) -1 downto 0);
    signal ext_mfb_meta_byte_en    : std_logic_vector(PCIE_CQ_MFB_WIDTH/8 -1 downto 0);

    signal ext_mfb_data    : std_logic_vector(PCIE_CQ_MFB_WIDTH -1 downto 0);
    signal ext_mfb_sof     : std_logic_vector(PCIE_CQ_MFB_REGIONS -1 downto 0);
    signal ext_mfb_eof     : std_logic_vector(PCIE_CQ_MFB_REGIONS -1 downto 0);
    signal ext_mfb_sof_pos : std_logic_vector(PCIE_CQ_MFB_REGIONS*max(1, log2(PCIE_CQ_MFB_REGION_SIZE)) -1 downto 0);
    signal ext_mfb_eof_pos : std_logic_vector(PCIE_CQ_MFB_REGIONS*max(1, log2(PCIE_CQ_MFB_REGION_SIZE*PCIE_CQ_MFB_BLOCK_SIZE)) -1 downto 0);
    signal ext_mfb_src_rdy : std_logic;
    signal ext_mfb_dst_rdy : std_logic;

    signal st_sp_ctrl_mfb_data    : std_logic_vector(PCIE_CQ_MFB_WIDTH -1 downto 0);
    signal st_sp_ctrl_mfb_meta    : std_logic_vector(META_BE_W + META_BE_O -1 downto 0);
    signal st_sp_ctrl_mfb_sof     : std_logic_vector(PCIE_CQ_MFB_REGIONS -1 downto 0);
    signal st_sp_ctrl_mfb_eof     : std_logic_vector(PCIE_CQ_MFB_REGIONS -1 downto 0);
    signal st_sp_ctrl_mfb_sof_pos : std_logic_vector(PCIE_CQ_MFB_REGIONS*max(1, log2(PCIE_CQ_MFB_REGION_SIZE)) -1 downto 0);
    signal st_sp_ctrl_mfb_eof_pos : std_logic_vector(PCIE_CQ_MFB_REGIONS*max(1, log2(PCIE_CQ_MFB_REGION_SIZE*PCIE_CQ_MFB_BLOCK_SIZE)) -1 downto 0);
    signal st_sp_ctrl_mfb_src_rdy : std_logic;
    signal st_sp_ctrl_mfb_dst_rdy : std_logic;

    signal trbuff_rd_chan : std_logic_vector(log2(CHANNELS) -1 downto 0);
    signal trbuff_rd_data : std_logic_vector(PCIE_CQ_MFB_WIDTH -1 downto 0);
    signal trbuff_rd_addr : std_logic_vector(DATA_POINTER_WIDTH -1 downto 0);
    signal trbuff_rd_en   : std_logic;

    signal hdr_fifo_tx_data    : std_logic_vector(62 + log2(CHANNELS) + 64 -1 downto 0);
    signal hdr_fifo_tx_src_rdy : std_logic;
    signal hdr_fifo_tx_dst_rdy : std_logic;

    signal enabled_chans : std_logic_vector(CHANNELS -1 downto 0);
begin

    assert (USR_TX_MFB_REGIONS = 1 and USR_TX_MFB_REGION_SIZE = 4 and USR_TX_MFB_BLOCK_SIZE = 8 and USR_TX_MFB_ITEM_WIDTH = 8)
        report "TX_DMA_CALYPTE: unsupported USR_TX_MFB configuration, the alowed are: (1,4,8,8)"
        severity FAILURE;

    assert (PCIE_CQ_MFB_REGIONS = 1 and PCIE_CQ_MFB_REGION_SIZE = 1 and PCIE_CQ_MFB_BLOCK_SIZE = 8 and PCIE_CQ_MFB_ITEM_WIDTH = 32)
        report "TX_DMA_CALYPTE: unsupported PCIE_CQ_MFB configuration, the allowed are: (1,1,8,32)"
        severity FAILURE;

    assert (DEVICE = "ULTRASCALE")
        report "TX_DMA_CALYPTE: unsupported device type, the allowed are: ULTRASCALE"
        severity FAILURE;

    assert (PKT_SIZE_MAX <= 2**DATA_POINTER_WIDTH)
        report "TX_DMA_CALYPTE: too large PKT_SIZE_MAX, the internal FIFO must be able to fit at least one packet of the size of the PKT_SIZE_MAX. Either change FIFO_DEPTH or PKT_SIZE_MAX generic."
        severity FAILURE;

    assert ((CHANNELS mod 2 = 0 and CHANNELS >= 2))
        report "TX_DMA_CALYPTE: Wrong number of channels, the number should be the power of two greater than 1"
        severity FAILURE;

    tx_dma_sw_manager_i : entity work.TX_DMA_SW_MANAGER
        generic map (
            DEVICE   => DEVICE,
            CHANNELS => CHANNELS,

            RECV_PKT_CNT_WIDTH => CNTRS_WIDTH,
            RECV_BTS_CNT_WIDTH => CNTRS_WIDTH,
            DISC_PKT_CNT_WIDTH => CNTRS_WIDTH,
            DISC_BTS_CNT_WIDTH => CNTRS_WIDTH,

            DATA_POINTER_WIDTH    => DATA_POINTER_WIDTH,
            DMA_HDR_POINTER_WIDTH => DMA_HDR_POINTER_WIDTH,
            PKT_SIZE_MAX          => PKT_SIZE_MAX,
            MI_WIDTH              => MI_WIDTH)
        port map (
            CLK   => CLK,
            RESET => RESET,

            MI_ADDR => MI_ADDR,
            MI_DWR  => MI_DWR,
            MI_BE   => MI_BE,
            MI_RD   => MI_RD,
            MI_WR   => MI_WR,
            MI_DRD  => MI_DRD,
            MI_ARDY => MI_ARDY,
            MI_DRDY => MI_DRDY,

            PKT_SENT_CHAN     => pkt_sent_chan,
            PKT_SENT_INC      => pkt_sent_inc,
            PKT_SENT_BYTES    => pkt_sent_bytes,
            PKT_DISCARD_CHAN  => pkt_disc_chan,
            PKT_DISCARD_INC   => pkt_disc_inc,
            PKT_DISCARD_BYTES => pkt_disc_bytes,

            START_REQ_CHAN => start_req_chan,
            START_REQ_VLD  => start_req_vld,
            START_REQ_ACK  => start_req_ack,
            STOP_REQ_CHAN  => stop_req_chan,
            STOP_REQ_VLD   => stop_req_vld,
            STOP_REQ_ACK   => stop_req_ack,

            ENABLED_CHAN => enabled_chans,

            HDP_WR_CHAN => upd_hdp_chan,
            HDP_WR_DATA => upd_hdp_data,
            HDP_WR_EN   => upd_hdp_en,
            HHP_WR_CHAN => upd_hhp_chan,
            HHP_WR_DATA => upd_hhp_data,
            HHP_WR_EN   => upd_hhp_en);

    tx_dma_metadata_extractor_i : entity work.TX_DMA_METADATA_EXTRACTOR
        generic map (
            DEVICE        => DEVICE,
            CHANNELS      => CHANNELS,
            POINTER_WIDTH => DATA_POINTER_WIDTH,

            PCIE_MFB_REGIONS     => PCIE_CQ_MFB_REGIONS,
            PCIE_MFB_REGION_SIZE => PCIE_CQ_MFB_REGION_SIZE,
            PCIE_MFB_BLOCK_SIZE  => PCIE_CQ_MFB_BLOCK_SIZE,
            PCIE_MFB_ITEM_WIDTH  => PCIE_CQ_MFB_ITEM_WIDTH)

        port map (
            CLK   => CLK,
            RESET => RESET,

            PCIE_MFB_DATA    => PCIE_CQ_MFB_DATA,
            PCIE_MFB_META    => PCIE_CQ_MFB_META,
            PCIE_MFB_SOF     => PCIE_CQ_MFB_SOF,
            PCIE_MFB_EOF     => PCIE_CQ_MFB_EOF,
            PCIE_MFB_SOF_POS => PCIE_CQ_MFB_SOF_POS,
            PCIE_MFB_EOF_POS => PCIE_CQ_MFB_EOF_POS,
            PCIE_MFB_SRC_RDY => PCIE_CQ_MFB_SRC_RDY,
            PCIE_MFB_DST_RDY => PCIE_CQ_MFB_DST_RDY,

            USR_MFB_META_IS_DMA_HDR => ext_mfb_meta_is_dma_hdr,
            USR_MFB_META_PCIE_ADDR  => ext_mfb_meta_pcie_addr,
            USR_MFB_META_CHAN_NUM   => ext_mfb_meta_chan_num,
            USR_MFB_META_BYTE_EN    => ext_mfb_meta_byte_en,

            USR_MFB_DATA    => ext_mfb_data,
            USR_MFB_SOF     => ext_mfb_sof,
            USR_MFB_EOF     => ext_mfb_eof,
            USR_MFB_SOF_POS => ext_mfb_sof_pos,
            USR_MFB_EOF_POS => ext_mfb_eof_pos,
            USR_MFB_SRC_RDY => ext_mfb_src_rdy,
            USR_MFB_DST_RDY => ext_mfb_dst_rdy);

    tx_dma_chan_start_stop_ctrl_i : entity work.TX_DMA_CHAN_START_STOP_CTRL
        generic map (
            DEVICE   => DEVICE,
            CHANNELS => CHANNELS,

            PCIE_MFB_REGIONS     => PCIE_CQ_MFB_REGIONS,
            PCIE_MFB_REGION_SIZE => PCIE_CQ_MFB_REGION_SIZE,
            PCIE_MFB_BLOCK_SIZE  => PCIE_CQ_MFB_BLOCK_SIZE,
            PCIE_MFB_ITEM_WIDTH  => PCIE_CQ_MFB_ITEM_WIDTH,

            PKT_SIZE_MAX => PKT_SIZE_MAX)
        port map (
            CLK   => CLK,
            RESET => RESET,

            PCIE_MFB_DATA    => ext_mfb_data,
            PCIE_MFB_META    => ext_mfb_meta_byte_en & ext_mfb_meta_chan_num & ext_mfb_meta_pcie_addr & ext_mfb_meta_is_dma_hdr,
            PCIE_MFB_SOF     => ext_mfb_sof,
            PCIE_MFB_EOF     => ext_mfb_eof,
            PCIE_MFB_SOF_POS => ext_mfb_sof_pos,
            PCIE_MFB_EOF_POS => ext_mfb_eof_pos,
            PCIE_MFB_SRC_RDY => ext_mfb_src_rdy,
            PCIE_MFB_DST_RDY => ext_mfb_dst_rdy,

            USR_MFB_DATA    => st_sp_ctrl_mfb_data,
            USR_MFB_META    => st_sp_ctrl_mfb_meta,
            USR_MFB_SOF     => st_sp_ctrl_mfb_sof,
            USR_MFB_EOF     => st_sp_ctrl_mfb_eof,
            USR_MFB_SOF_POS => st_sp_ctrl_mfb_sof_pos,
            USR_MFB_EOF_POS => st_sp_ctrl_mfb_eof_pos,
            USR_MFB_SRC_RDY => st_sp_ctrl_mfb_src_rdy,
            USR_MFB_DST_RDY => st_sp_ctrl_mfb_dst_rdy,

            START_REQ_CHAN => start_req_chan,
            START_REQ_VLD  => start_req_vld,
            START_REQ_ACK  => start_req_ack,
            STOP_REQ_CHAN  => stop_req_chan,
            STOP_REQ_VLD   => stop_req_vld,
            STOP_REQ_ACK   => stop_req_ack,

            PKT_DISC_CHAN  => pkt_disc_chan,
            PKT_DISC_INC   => pkt_disc_inc,
            PKT_DISC_BYTES => pkt_disc_bytes);

    tx_dma_pcie_trans_buffer_i : entity work.TX_DMA_PCIE_TRANS_BUFFER
        generic map (
            DEVICE   => DEVICE,
            CHANNELS => CHANNELS,

            MFB_REGIONS     => PCIE_CQ_MFB_REGIONS,
            MFB_REGION_SIZE => PCIE_CQ_MFB_REGION_SIZE,
            MFB_BLOCK_SIZE  => PCIE_CQ_MFB_BLOCK_SIZE,
            MFB_ITEM_WIDTH  => PCIE_CQ_MFB_ITEM_WIDTH,

            POINTER_WIDTH => DATA_POINTER_WIDTH)
        port map (
            CLK   => CLK,
            RESET => RESET,

            PCIE_MFB_DATA    => st_sp_ctrl_mfb_data,
            PCIE_MFB_META    => st_sp_ctrl_mfb_meta,
            PCIE_MFB_SOF     => st_sp_ctrl_mfb_sof,
            PCIE_MFB_EOF     => st_sp_ctrl_mfb_eof,
            PCIE_MFB_SOF_POS => st_sp_ctrl_mfb_sof_pos,
            PCIE_MFB_EOF_POS => st_sp_ctrl_mfb_eof_pos,
            PCIE_MFB_SRC_RDY => st_sp_ctrl_mfb_src_rdy and st_sp_ctrl_mfb_dst_rdy and (not st_sp_ctrl_mfb_meta(META_IS_DMA_HDR)(0)),
            PCIE_MFB_DST_RDY => open,

            RD_CHAN => trbuff_rd_chan,
            RD_DATA => trbuff_rd_data,
            RD_ADDR => trbuff_rd_addr,
            RD_EN   => trbuff_rd_en);

    dma_hdr_fifo_i : entity work.MVB_FIFOX
        generic map (
            ITEMS               => 1,
            ITEM_WIDTH          => 62 + log2(CHANNELS) + 64,
            FIFO_DEPTH          => 2**DMA_HDR_POINTER_WIDTH,
            RAM_TYPE            => "AUTO",
            DEVICE              => DEVICE,
            ALMOST_FULL_OFFSET  => 3,
            ALMOST_EMPTY_OFFSET => 3,
            FAKE_FIFO           => FALSE)
        port map (
            CLK   => CLK,
            RESET => RESET,

            RX_DATA    => st_sp_ctrl_mfb_meta(META_PCIE_ADDR) & st_sp_ctrl_mfb_meta(META_CHAN_NUM) & st_sp_ctrl_mfb_data(63 downto 0),
            RX_VLD     => "1",
            RX_SRC_RDY => st_sp_ctrl_mfb_src_rdy and st_sp_ctrl_mfb_meta(META_IS_DMA_HDR)(0),
            RX_DST_RDY => st_sp_ctrl_mfb_dst_rdy,

            TX_DATA    => hdr_fifo_tx_data,
            TX_VLD     => open,
            TX_SRC_RDY => hdr_fifo_tx_src_rdy,
            TX_DST_RDY => hdr_fifo_tx_dst_rdy,

            STATUS => open,
            AFULL  => open,
            AEMPTY => open);

    tx_dma_pkt_dispatcher_i : entity work.TX_DMA_PKT_DISPATCHER
        generic map (
            DEVICE => DEVICE,

            CHANNELS       => CHANNELS,
            HDR_META_WIDTH => HDR_META_WIDTH,
            PKT_SIZE_MAX   => PKT_SIZE_MAX,

            MFB_REGIONS     => USR_TX_MFB_REGIONS,
            MFB_REGION_SIZE => USR_TX_MFB_REGION_SIZE,
            MFB_BLOCK_SIZE  => USR_TX_MFB_BLOCK_SIZE,
            MFB_ITEM_WIDTH  => USR_TX_MFB_ITEM_WIDTH,

            DATA_POINTER_WIDTH    => DATA_POINTER_WIDTH,
            DMA_HDR_POINTER_WIDTH => DMA_HDR_POINTER_WIDTH)
        port map (
            CLK   => CLK,
            RESET => RESET,

            USR_MFB_META_HDR_META => USR_TX_MFB_META_HDR_META,
            USR_MFB_META_CHAN     => USR_TX_MFB_META_CHAN,
            USR_MFB_META_PKT_SIZE => USR_TX_MFB_META_PKT_SIZE,

            USR_MFB_DATA    => USR_TX_MFB_DATA,
            USR_MFB_SOF     => USR_TX_MFB_SOF,
            USR_MFB_EOF     => USR_TX_MFB_EOF,
            USR_MFB_SOF_POS => USR_TX_MFB_SOF_POS,
            USR_MFB_EOF_POS => USR_TX_MFB_EOF_POS,
            USR_MFB_SRC_RDY => USR_TX_MFB_SRC_RDY,
            USR_MFB_DST_RDY => USR_TX_MFB_DST_RDY,

            HDR_BUFF_ADDR    => hdr_fifo_tx_data(62+log2(CHANNELS)+64 -1 downto log2(CHANNELS)+64),
            HDR_BUFF_CHAN    => hdr_fifo_tx_data(log2(CHANNELS)+64 -1 downto 64),
            HDR_BUFF_DATA    => hdr_fifo_tx_data(63 downto 0),
            HDR_BUFF_SRC_RDY => hdr_fifo_tx_src_rdy,
            HDR_BUFF_DST_RDY => hdr_fifo_tx_dst_rdy,

            BUFF_RD_CHAN => trbuff_rd_chan,
            BUFF_RD_DATA => trbuff_rd_data,
            BUFF_RD_ADDR => trbuff_rd_addr,
            BUFF_RD_EN   => trbuff_rd_en,

            PKT_SENT_CHAN  => pkt_sent_chan,
            PKT_SENT_INC   => pkt_sent_inc,
            PKT_SENT_BYTES => pkt_sent_bytes,

            ENABLED_CHANS => enabled_chans,

            UPD_HDP_CHAN => upd_hdp_chan,
            UPD_HDP_DATA => upd_hdp_data,
            UPD_HDP_EN   => upd_hdp_en,

            UPD_HHP_CHAN => upd_hhp_chan,
            UPD_HHP_DATA => upd_hhp_data,
            UPD_HHP_EN   => upd_hhp_en);
end architecture;
