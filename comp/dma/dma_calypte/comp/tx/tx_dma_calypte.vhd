-- tx_dma_calypte.vhd: connecting all important parts of the TX DMA Calypte and adds small logic to
-- connections when necessary
-- Copyright (C) 2022 CESNET z.s.p.o.
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
-- This is transmitting part of the DMA Calypte core. The major structure can be
-- changed by setting the CHANNEL_ARBITER_EN generic parameter to either true or
-- false. This parameter enables/disables the CHANNEL_ARBITER component which
-- merges streams from all CHANNEL_CORE components. The output interface with
-- enabled arbiter remains the same but valid data are transmitted on the
-- interface no. 0 only. When CHANNEL_ARBITER is disabled, each CHANNEL_CORE has
-- its own separate output. The block scheme of the TX DMA Calypte controller is
-- provided in two following figures (`N = <number of channels> - 1`):
--
-- .. figure:: img/tx_calypte_block_chan_arb.svg
--     :align: center
--     :scale: 100%
--
--     Block scheme of TX DMA Calypte controller with CHANNEL_ARBITER enabled
--
-- .. figure:: img/tx_calypte_block_dis_chan_arb.svg
--     :align: center
--     :scale: 100%
--
--     Block scheme of TX DMA Calypte controller with CHANNEL_ARBITER disabled
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
        -- Setting of internal parameters of CHANNEL_CORE
        -- =========================================================================================
        -- FIFO depth in number of items stored. The overall capacity in bytes can be obtained when
        -- this number is multiplied by the width of the PCIe CQ bus in bytes. The FIFO should fit
        -- at least one packet of the PKT_SIZE_MAX size. Otherwise a halt of the whole controller
        -- can occur.
        FIFO_DEPTH     : natural := 512;
        -- Set the number of DMA channels, each channel is controlled by one CHANNEL_CORE component.
        CHANNELS       : natural := 8;

        -- =========================================================================================
        -- Enabling of CHANNEL_ARBITER component
        --
        -- This component merges output streams from all CHANNEL_CORE components. When enabled, the
        -- valid data occur only on the 0th USR_TX_MFB interface. Then disabled, each channel has
        -- its own output.
        -- =========================================================================================
        CHANNEL_ARBITER_EN : boolean := FALSE;

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
        --
        -- Each channel has its own output unless CHANNEL_ARBITER is enabled. In that case, only
        -- line number 0 is used.
        -- =========================================================================================
        USR_TX_MFB_META_PKT_SIZE : out slv_array_t(CHANNELS -1 downto 0)(log2(PKT_SIZE_MAX + 1) -1 downto 0) := (others => (others => '0'));
        USR_TX_MFB_META_CHAN     : out slv_array_t(CHANNELS -1 downto 0)(log2(CHANNELS) -1 downto 0)         := (others => (others => '0'));
        USR_TX_MFB_META_HDR_META : out slv_array_t(CHANNELS -1 downto 0)(HDR_META_WIDTH -1 downto 0)         := (others => (others => '0'));

        USR_TX_MFB_DATA    : out slv_array_t(CHANNELS -1 downto 0)(USR_TX_MFB_REGIONS*USR_TX_MFB_REGION_SIZE*USR_TX_MFB_BLOCK_SIZE*USR_TX_MFB_ITEM_WIDTH-1 downto 0) := (others => (others => '0'));
        USR_TX_MFB_SOF     : out slv_array_t(CHANNELS -1 downto 0)(USR_TX_MFB_REGIONS -1 downto 0)                                                                   := (others => (others => '0'));
        USR_TX_MFB_EOF     : out slv_array_t(CHANNELS -1 downto 0)(USR_TX_MFB_REGIONS -1 downto 0)                                                                   := (others => (others => '0'));
        USR_TX_MFB_SOF_POS : out slv_array_t(CHANNELS -1 downto 0)(USR_TX_MFB_REGIONS*max(1, log2(USR_TX_MFB_REGION_SIZE)) -1 downto 0)                              := (others => (others => '0'));
        USR_TX_MFB_EOF_POS : out slv_array_t(CHANNELS -1 downto 0)(USR_TX_MFB_REGIONS*max(1, log2(USR_TX_MFB_REGION_SIZE*USR_TX_MFB_BLOCK_SIZE)) -1 downto 0)        := (others => (others => '0'));
        USR_TX_MFB_SRC_RDY : out std_logic_vector(CHANNELS -1 downto 0)                                                                                              := (others => '0');
        USR_TX_MFB_DST_RDY : in  std_logic_vector(CHANNELS -1 downto 0);

        -- =========================================================================================
        -- PCIe Completer Request MFB interface
        --
        -- Accepts write and read requests
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

    constant PCIE_CQ_MFB_WIDTH      : natural := PCIE_CQ_MFB_REGIONS*PCIE_CQ_MFB_REGION_SIZE*PCIE_CQ_MFB_BLOCK_SIZE*PCIE_CQ_MFB_ITEM_WIDTH;
    constant USR_TX_MFB_WIDTH       : natural := USR_TX_MFB_REGIONS*USR_TX_MFB_REGION_SIZE*USR_TX_MFB_BLOCK_SIZE*USR_TX_MFB_ITEM_WIDTH;
    -- specifies width of a signal which contains the channel number and the amount of bytes to
    -- increment from each channel
    constant CHAN_SENT_BYTES_WIDTH  : natural := log2(PKT_SIZE_MAX+1) + log2(CHANNELS);

    -- constant used in mulitplication (shift by specific number of bits to left) of data FIFO items
    -- to convert the number to the number of bytes being stored within
    constant ITEM_TO_BYTE_SHIFT : std_logic_vector(log2(USR_TX_MFB_WIDTH/8) -1 downto 0) := (others => '0');

    constant UPDATE_PERIOD : positive := 16;

    -- =============================================================================================
    -- Channel start/stop handshake mulitplexor/demultiplexor
    -- =============================================================================================
    signal start_req_chan      : std_logic_vector(log2(CHANNELS) -1 downto 0);
    signal stop_req_chan       : std_logic_vector(log2(CHANNELS) -1 downto 0);
    -- SW_MANAGER --> DEMUX
    signal start_req_vld       : std_logic;
    signal stop_req_vld        : std_logic;
    -- SW_MANAGER <-- MUX
    signal start_req_ack_mux   : std_logic;
    signal stop_req_ack_mux    : std_logic;
    -- CHANNEL_CORE --> MUX
    signal start_req_ack       : std_logic_vector(CHANNELS -1 downto 0);
    signal stop_req_ack        : std_logic_vector(CHANNELS -1 downto 0);
    -- CHANNEL_CORE <-- DEMUX
    signal start_req_vld_demux : std_logic_vector(CHANNELS -1 downto 0);
    signal stop_req_vld_demux  : std_logic_vector(CHANNELS -1 downto 0);

    -- =============================================================================================
    -- Status update interface
    -- =============================================================================================
    signal upd_tmr          : unsigned(log2(UPDATE_PERIOD) -1 downto 0);
    signal upd_en           : std_logic;
    signal chan_idx         : unsigned(log2(CHANNELS) -1 downto 0);
    signal data_fifo_status : slv_array_t(CHANNELS -1 downto 0)(log2(FIFO_DEPTH) downto 0);
    signal data_status_mux  : std_logic_vector(log2(FIFO_DEPTH) downto 0);
    signal hdr_fifo_status  : slv_array_t(CHANNELS -1 downto 0)(log2(FIFO_DEPTH) downto 0);
    signal hdr_status_mux   : std_logic_vector(log2(FIFO_DEPTH) downto 0);

    -- =============================================================================================
    -- FIFOX_MULTI signals
    -- =============================================================================================
    -- Inputs
    signal pkt_sent_inc          : std_logic_vector(CHANNELS -1 downto 0);
    signal pkt_sent_size         : slv_array_t(CHANNELS -1 downto 0)(log2(PKT_SIZE_MAX+1) -1 downto 0);
    signal chan_sent_bytes       : std_logic_vector(CHANNELS*CHAN_SENT_BYTES_WIDTH -1 downto 0);
    signal pkt_disc_inc          : std_logic_vector(CHANNELS -1 downto 0);
    signal pkt_disc_size         : slv_array_t(CHANNELS -1 downto 0)(log2(PKT_SIZE_MAX+1) -1 downto 0);
    signal chan_disc_bytes       : std_logic_vector(CHANNELS*CHAN_SENT_BYTES_WIDTH -1 downto 0);

    -- Outputs
    signal sent_bytes_fifox_multi_do     : std_logic_vector(CHAN_SENT_BYTES_WIDTH -1 downto 0);
    signal sent_bytes_fifox_multi_empty  : std_logic;
    signal disc_bytes_fifox_multi_do     : std_logic_vector(CHAN_SENT_BYTES_WIDTH -1 downto 0);
    signal disc_bytes_fifox_multi_empty  : std_logic;

    -- =============================================================================================
    -- CHANNEL_SPLITTER outputs
    -- =============================================================================================
    signal chan_split_mfb_meta_seg_size   : slv_array_t(CHANNELS -1 downto 0)(13 -1 downto 0);
    signal chan_split_mfb_meta_is_dma_hdr : std_logic_vector(CHANNELS -1 downto 0);
    signal chan_split_mfb_data            : slv_array_t(CHANNELS -1 downto 0)(PCIE_CQ_MFB_WIDTH -1 downto 0);
    signal chan_split_mfb_sof             : slv_array_t(CHANNELS -1 downto 0)(PCIE_CQ_MFB_REGIONS -1 downto 0);
    signal chan_split_mfb_eof             : slv_array_t(CHANNELS -1 downto 0)(PCIE_CQ_MFB_REGIONS -1 downto 0);
    signal chan_split_mfb_sof_pos         : slv_array_t(CHANNELS -1 downto 0)(max(1, log2(PCIE_CQ_MFB_REGION_SIZE)) -1 downto 0);
    signal chan_split_mfb_eof_pos         : slv_array_t(CHANNELS -1 downto 0)(max(1, log2(PCIE_CQ_MFB_REGION_SIZE*PCIE_CQ_MFB_BLOCK_SIZE)) -1 downto 0);
    signal chan_split_mfb_src_rdy         : std_logic_vector(CHANNELS -1 downto 0);
    signal chan_split_mfb_dst_rdy         : std_logic_vector(CHANNELS -1 downto 0);

    -- =============================================================================================
    -- CHANNEL_CORE outputs
    -- =============================================================================================
    signal chan_core_mfb_meta_pkt_size : slv_array_t(CHANNELS -1 downto 0)(log2(PKT_SIZE_MAX+1) -1 downto 0);
    signal chan_core_mfb_meta_hdr_meta : slv_array_t(CHANNELS -1 downto 0)(HDR_META_WIDTH -1 downto 0);
    signal chan_core_mfb_data          : slv_array_t(CHANNELS -1 downto 0)(USR_TX_MFB_WIDTH -1 downto 0);
    signal chan_core_mfb_sof           : slv_array_t(CHANNELS -1 downto 0)(USR_TX_MFB_REGIONS -1 downto 0);
    signal chan_core_mfb_eof           : slv_array_t(CHANNELS -1 downto 0)(USR_TX_MFB_REGIONS -1 downto 0);
    signal chan_core_mfb_sof_pos       : slv_array_t(CHANNELS -1 downto 0)(max(1, log2(USR_TX_MFB_REGION_SIZE)) -1 downto 0);
    signal chan_core_mfb_eof_pos       : slv_array_t(CHANNELS -1 downto 0)(max(1, log2(USR_TX_MFB_REGION_SIZE*USR_TX_MFB_BLOCK_SIZE)) -1 downto 0);
    signal chan_core_mfb_src_rdy       : std_logic_vector(CHANNELS -1 downto 0);
    signal chan_core_mfb_dst_rdy       : std_logic_vector(CHANNELS -1 downto 0);

    -- attribute mark_debug : string;

    -- attribute mark_debug of USR_TX_MFB_META_PKT_SIZE : signal is "true";
    -- attribute mark_debug of USR_TX_MFB_META_CHAN     : signal is "true";
    -- attribute mark_debug of USR_TX_MFB_META_HDR_META : signal is "true";

    -- attribute mark_debug of USR_TX_MFB_DATA    : signal is "true";
    -- attribute mark_debug of USR_TX_MFB_SOF     : signal is "true";
    -- attribute mark_debug of USR_TX_MFB_EOF     : signal is "true";
    -- attribute mark_debug of USR_TX_MFB_SOF_POS : signal is "true";
    -- attribute mark_debug of USR_TX_MFB_EOF_POS : signal is "true";
    -- attribute mark_debug of USR_TX_MFB_SRC_RDY : signal is "true";
    -- attribute mark_debug of USR_TX_MFB_DST_RDY : signal is "true";

    -- attribute mark_debug of PCIE_CQ_MFB_DATA    : signal is "true";
    -- attribute mark_debug of PCIE_CQ_MFB_SOF     : signal is "true";
    -- attribute mark_debug of PCIE_CQ_MFB_EOF     : signal is "true";
    -- attribute mark_debug of PCIE_CQ_MFB_SOF_POS : signal is "true";
    -- attribute mark_debug of PCIE_CQ_MFB_EOF_POS : signal is "true";
    -- attribute mark_debug of PCIE_CQ_MFB_SRC_RDY : signal is "true";
    -- attribute mark_debug of PCIE_CQ_MFB_DST_RDY : signal is "true";

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

    assert (PKT_SIZE_MAX <= FIFO_DEPTH*(USR_TX_MFB_WIDTH/8))
        report "TX_DMA_CALYPTE: too large PKT_SIZE_MAX, the internal FIFO must be able to fit at least one packet of the size of the PKT_SIZE_MAX. Either change FIFO_DEPTH or PKT_SIZE_MAX generic."
        severity FAILURE;

    assert ((CHANNELS mod 2 = 0 and CHANNELS >= 2))
        report "TX_DMA_CALYPTE: Wrong number of channels, the number should be the power of two greater than 1"
        severity FAILURE;

    software_manager_i : entity work.TX_DMA_SW_MANAGER
        generic map (
            DEVICE   => DEVICE,
            CHANNELS => CHANNELS,

            RECV_PKT_CNT_WIDTH => CNTRS_WIDTH,
            RECV_BTS_CNT_WIDTH => CNTRS_WIDTH,
            DISC_PKT_CNT_WIDTH => CNTRS_WIDTH,
            DISC_BTS_CNT_WIDTH => CNTRS_WIDTH,

            MFB_WIDTH      => USR_TX_MFB_WIDTH,
            DMA_FIFO_DEPTH => FIFO_DEPTH,
            PKT_SIZE_MAX   => PKT_SIZE_MAX,
            MI_WIDTH       => MI_WIDTH)
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

            PKT_SENT_CHAN     => sent_bytes_fifox_multi_do(log2(CHANNELS) -1 downto 0),
            PKT_SENT_INC      => not sent_bytes_fifox_multi_empty,
            PKT_SENT_BYTES    => sent_bytes_fifox_multi_do(CHAN_SENT_BYTES_WIDTH -1 downto log2(CHANNELS)),

            PKT_DISCARD_CHAN  => disc_bytes_fifox_multi_do(log2(CHANNELS) -1 downto 0),
            PKT_DISCARD_INC   => not disc_bytes_fifox_multi_empty,
            PKT_DISCARD_BYTES => disc_bytes_fifox_multi_do(CHAN_SENT_BYTES_WIDTH -1 downto log2(CHANNELS)),

            START_REQ_CHAN => start_req_chan,
            START_REQ_VLD  => start_req_vld,
            START_REQ_ACK  => start_req_ack_mux,
            STOP_REQ_CHAN  => stop_req_chan,
            STOP_REQ_VLD   => stop_req_vld,
            STOP_REQ_ACK   => stop_req_ack_mux,

            ENABLED_CHAN => open,

            DATA_FIFO_STATUS_CHAN => std_logic_vector(chan_idx),
            DATA_FIFO_STATUS_DATA => data_status_mux & ITEM_TO_BYTE_SHIFT,
            DATA_FIFO_STATUS_WE   => upd_en,

            HDR_FIFO_STATUS_CHAN => std_logic_vector(chan_idx),
            HDR_FIFO_STATUS_DATA => hdr_status_mux,
            HDR_FIFO_STATUS_WE   => upd_en);

    -- =============================================================================================
    -- Muxing/Demuxing start/stop requests
    -- =============================================================================================
    start_req_vld_demux_i : entity work.GEN_DEMUX
        generic map (
            DATA_WIDTH  => 1,
            DEMUX_WIDTH => CHANNELS,
            DEF_VALUE   => '0')
        port map (
            DATA_IN(0) => start_req_vld,
            SEL        => start_req_chan,
            DATA_OUT   => start_req_vld_demux);

    start_req_ack_mux_i : entity work.GEN_MUX
        generic map (
            DATA_WIDTH => 1,
            MUX_WIDTH  => CHANNELS)
        port map (
            DATA_IN     => start_req_ack,
            SEL         => start_req_chan,
            DATA_OUT(0) => start_req_ack_mux);

    stop_req_vld_demux_i : entity work.GEN_DEMUX
        generic map (
            DATA_WIDTH  => 1,
            DEMUX_WIDTH => CHANNELS,
            DEF_VALUE   => '0')
        port map (
            DATA_IN(0) => stop_req_vld,
            SEL        => stop_req_chan,
            DATA_OUT   => stop_req_vld_demux);

    stop_req_ack_mux_i : entity work.GEN_MUX
        generic map (
            DATA_WIDTH => 1,
            MUX_WIDTH  => CHANNELS)
        port map (
            DATA_IN     => stop_req_ack,
            SEL         => stop_req_chan,
            DATA_OUT(0) => stop_req_ack_mux);

    -- =============================================================================================
    -- Update of status FIFO informations to the registers
    -- =============================================================================================
    update_timer_p : process (CLK) is
    begin
        if (rising_edge(CLK)) then
            if (RESET = '1') then
                upd_tmr <= (others => '0');
                upd_en  <= '0';
            else
                upd_tmr <= upd_tmr + 1;
                upd_en  <= '0';

                if (upd_tmr = UPDATE_PERIOD -1) then
                    upd_en <= '1';
                end if;
            end if;
        end if;
    end process;

    chann_cycle_p : process (CLK) is
    begin
        if (rising_edge(CLK)) then
            if (RESET = '1') then
                chan_idx <= (others => '1');
            elsif (upd_en = '1') then
                chan_idx <= chan_idx + 1;
            end if;
        end if;
    end process;

    data_fifo_status_mux_i : entity work.GEN_MUX
        generic map (
            DATA_WIDTH => log2(FIFO_DEPTH) + 1,
            MUX_WIDTH  => CHANNELS)
        port map (
            DATA_IN  => slv_array_ser(data_fifo_status),
            SEL      => std_logic_vector(chan_idx),
            DATA_OUT => data_status_mux);

    hdr_fifo_status_mux_i : entity work.GEN_MUX
        generic map (
            DATA_WIDTH => log2(FIFO_DEPTH) + 1,
            MUX_WIDTH  => CHANNELS)
        port map (
            DATA_IN  => slv_array_ser(hdr_fifo_status),
            SEL      => std_logic_vector(chan_idx),
            DATA_OUT => hdr_status_mux);

    -- =============================================================================================
    -- Storing counter informations from all channels to be read by the SW manager
    --
    -- This is created because multiple channels can update their status FIFOs at once so these two
    -- FIFOX_MULTI components can store multiple of these counter updates
    -- =============================================================================================

    -- those are single items that are stored in the FIFOX_MULTI because the reading on the side
    -- of the TX_DMY_SW_MANAGER requires to know the number of the channel so every input to the
    -- FIFOX_MULTI contains the channel number on the first bits (from LSB) followed by the
    -- status of the FIFO on the current channel or the amount of bytes it needs to increment
    incl_chan_status_g : for i in 0 to (CHANNELS -1) generate
        chan_sent_bytes(i*CHAN_SENT_BYTES_WIDTH+log2(CHANNELS) -1 downto i*CHAN_SENT_BYTES_WIDTH)                                  <= std_logic_vector(to_unsigned(i, log2(CHANNELS)));
        chan_sent_bytes(i*CHAN_SENT_BYTES_WIDTH+CHAN_SENT_BYTES_WIDTH -1 downto i*CHAN_SENT_BYTES_WIDTH + log2(CHANNELS))          <= pkt_sent_size(i);
        chan_disc_bytes(i*CHAN_SENT_BYTES_WIDTH+log2(CHANNELS) -1 downto i*CHAN_SENT_BYTES_WIDTH)                                  <= std_logic_vector(to_unsigned(i, log2(CHANNELS)));
        chan_disc_bytes(i*CHAN_SENT_BYTES_WIDTH+CHAN_SENT_BYTES_WIDTH -1 downto i*CHAN_SENT_BYTES_WIDTH + log2(CHANNELS))          <= pkt_disc_size(i);
    end generate;

    sent_bytes_fifox_multi_i : entity work.FIFOX_MULTI(FULL)
        generic map (
            DATA_WIDTH          => CHAN_SENT_BYTES_WIDTH,
            ITEMS               => 2*CHANNELS + 10,
            WRITE_PORTS         => CHANNELS,
            READ_PORTS          => 1,
            RAM_TYPE            => "AUTO",
            DEVICE              => DEVICE,
            ALMOST_FULL_OFFSET  => 2,
            ALMOST_EMPTY_OFFSET => 2,
            ALLOW_SINGLE_FIFO   => FALSE,
            SAFE_READ_MODE      => FALSE)
        port map (
            CLK   => CLK,
            RESET => RESET,

            DI    => chan_sent_bytes,
            WR    => pkt_sent_inc,
            -- WARNING: possible risk of overflowing the FIFO
            FULL  => open,
            AFULL => open,

            DO       => sent_bytes_fifox_multi_do,
            RD(0)    => not sent_bytes_fifox_multi_empty,
            EMPTY(0) => sent_bytes_fifox_multi_empty,
            AEMPTY   => open);

    disc_bytes_fifox_multi_i : entity work.FIFOX_MULTI(FULL)
        generic map (
            DATA_WIDTH          => CHAN_SENT_BYTES_WIDTH,
            ITEMS               => 2*CHANNELS + 10,
            WRITE_PORTS         => CHANNELS,
            READ_PORTS          => 1,
            RAM_TYPE            => "AUTO",
            DEVICE              => DEVICE,
            ALMOST_FULL_OFFSET  => 2,
            ALMOST_EMPTY_OFFSET => 2,
            ALLOW_SINGLE_FIFO   => FALSE,
            SAFE_READ_MODE      => FALSE)
        port map (
            CLK   => CLK,
            RESET => RESET,

            DI    => chan_disc_bytes,
            WR    => pkt_disc_inc,
            -- WARNING: possible risk of overflowing the FIFO
            FULL  => open,
            AFULL => open,

            DO       => disc_bytes_fifox_multi_do,
            RD(0)    => not disc_bytes_fifox_multi_empty,
            EMPTY(0) => disc_bytes_fifox_multi_empty,
            AEMPTY   => open);

    -- =============================================================================================
    -- Splitting of incoming PCIe transaction to specific channels
    -- =============================================================================================
    channel_splitter_i : entity work.TX_DMA_CHANNEL_SPLITTER
        generic map (
            DEVICE         => DEVICE,
            CHANNELS       => CHANNELS,
            DMA_FIFO_DEPTH => FIFO_DEPTH,

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

            USR_MFB_META_BYTE_COUNT => chan_split_mfb_meta_seg_size,
            USR_MFB_META_IS_DMA_HDR => chan_split_mfb_meta_is_dma_hdr,

            USR_MFB_DATA    => chan_split_mfb_data,
            USR_MFB_SOF     => chan_split_mfb_sof,
            USR_MFB_EOF     => chan_split_mfb_eof,
            USR_MFB_SOF_POS => chan_split_mfb_sof_pos,
            USR_MFB_EOF_POS => chan_split_mfb_eof_pos,
            USR_MFB_SRC_RDY => chan_split_mfb_src_rdy,
            USR_MFB_DST_RDY => chan_split_mfb_dst_rdy);

    -- =============================================================================================
    -- Genration of CHANNEL_CORE components where each packet is built from PCIe transactions
    -- =============================================================================================
    channel_core_g : for i in 0 to (CHANNELS -1) generate
        channel_core_i : entity work.TX_DMA_CHANNEL_CORE
            generic map (
                DEVICE => DEVICE,

                PCIE_MFB_REGIONS     => PCIE_CQ_MFB_REGIONS,
                PCIE_MFB_REGION_SIZE => PCIE_CQ_MFB_REGION_SIZE,
                PCIE_MFB_BLOCK_SIZE  => PCIE_CQ_MFB_BLOCK_SIZE,
                PCIE_MFB_ITEM_WIDTH  => PCIE_CQ_MFB_ITEM_WIDTH,

                USR_MFB_REGIONS     => USR_TX_MFB_REGIONS,
                USR_MFB_REGION_SIZE => USR_TX_MFB_REGION_SIZE,
                USR_MFB_BLOCK_SIZE  => USR_TX_MFB_BLOCK_SIZE,
                USR_MFB_ITEM_WIDTH  => USR_TX_MFB_ITEM_WIDTH,

                HDR_META_WIDTH => HDR_META_WIDTH,
                PKT_SIZE_MAX   => PKT_SIZE_MAX,
                RAM_TYPE       => "AUTO",
                FIFO_DEPTH     => FIFO_DEPTH)
            port map (
                CLK   => CLK,
                RESET => RESET,

                PCIE_MFB_META_SEG_SIZE   => chan_split_mfb_meta_seg_size(i),
                PCIE_MFB_META_IS_DMA_HDR => chan_split_mfb_meta_is_dma_hdr(i),

                PCIE_MFB_DATA    => chan_split_mfb_data(i),
                PCIE_MFB_SOF     => chan_split_mfb_sof(i),
                PCIE_MFB_EOF     => chan_split_mfb_eof(i),
                PCIE_MFB_SOF_POS => chan_split_mfb_sof_pos(i),
                PCIE_MFB_EOF_POS => chan_split_mfb_eof_pos(i),
                PCIE_MFB_SRC_RDY => chan_split_mfb_src_rdy(i),
                PCIE_MFB_DST_RDY => chan_split_mfb_dst_rdy(i),

                USR_MFB_META_PKT_SIZE => chan_core_mfb_meta_pkt_size(i),
                USR_MFB_META_HDR_META => chan_core_mfb_meta_hdr_meta(i),

                USR_MFB_DATA    => chan_core_mfb_data(i),
                USR_MFB_SOF     => chan_core_mfb_sof(i),
                USR_MFB_EOF     => chan_core_mfb_eof(i),
                USR_MFB_SOF_POS => chan_core_mfb_sof_pos(i),
                USR_MFB_EOF_POS => chan_core_mfb_eof_pos(i),
                USR_MFB_SRC_RDY => chan_core_mfb_src_rdy(i),
                USR_MFB_DST_RDY => chan_core_mfb_dst_rdy(i),

                START_REQ_VLD => start_req_vld_demux(i),
                START_REQ_ACK => start_req_ack(i),
                STOP_REQ_VLD  => stop_req_vld_demux(i),
                STOP_REQ_ACK  => stop_req_ack(i),

                DATA_FIFO_STATUS => data_fifo_status(i),
                HDR_FIFO_STATUS  => hdr_fifo_status(i),

                PKT_SENT_INC  => pkt_sent_inc(i),
                PKT_SENT_SIZE => pkt_sent_size(i),

                PKT_DISC_INC  => pkt_disc_inc(i),
                PKT_DISC_SIZE => pkt_disc_size(i));
    end generate;

    -- =============================================================================================
    -- Output connections
    -- =============================================================================================
    chan_arb_g : if (CHANNEL_ARBITER_EN) generate
        signal mrg_rx_mfb_meta : slv_array_t(CHANNELS -1 downto 0)(log2(PKT_SIZE_MAX+1)+log2(CHANNELS)+HDR_META_WIDTH -1 downto 0);
        signal mrg_tx_mfb_meta : std_logic_vector(log2(PKT_SIZE_MAX+1)+log2(CHANNELS)+HDR_META_WIDTH -1 downto 0);
    begin

        mrg_rx_meta_concat_g : for i in 0 to (CHANNELS -1) generate
            mrg_rx_mfb_meta(i)(HDR_META_WIDTH -1 downto 0)                                                                  <= chan_core_mfb_meta_hdr_meta(i);
            mrg_rx_mfb_meta(i)(log2(CHANNELS)+HDR_META_WIDTH -1 downto HDR_META_WIDTH)                                      <= std_logic_vector(to_unsigned(i, log2(CHANNELS)));
            mrg_rx_mfb_meta(i)(log2(PKT_SIZE_MAX+1)+log2(CHANNELS)+HDR_META_WIDTH -1 downto log2(CHANNELS)+HDR_META_WIDTH)  <= chan_core_mfb_meta_pkt_size(i);
        end generate;

        mfb_merger_simple_gen_i : entity work.MFB_MERGER_SIMPLE_GEN
            generic map (
                MERGER_INPUTS  => CHANNELS,

                MFB_REGIONS     => USR_TX_MFB_REGIONS,
                MFB_REGION_SIZE => USR_TX_MFB_REGION_SIZE,
                MFB_BLOCK_SIZE  => USR_TX_MFB_BLOCK_SIZE,
                MFB_ITEM_WIDTH  => USR_TX_MFB_ITEM_WIDTH,
                MFB_META_WIDTH  => log2(PKT_SIZE_MAX+1)+log2(CHANNELS)+HDR_META_WIDTH,

                MASKING_EN     => TRUE,
                CNT_MAX        => 64)
            port map (
                CLK => CLK,
                RST => RESET,

                RX_MFB_DATA    => chan_core_mfb_data,
                RX_MFB_META    => mrg_rx_mfb_meta,
                RX_MFB_SOF     => chan_core_mfb_sof,
                RX_MFB_EOF     => chan_core_mfb_eof,
                RX_MFB_SOF_POS => chan_core_mfb_sof_pos,
                RX_MFB_EOF_POS => chan_core_mfb_eof_pos,
                RX_MFB_SRC_RDY => chan_core_mfb_src_rdy,
                RX_MFB_DST_RDY => chan_core_mfb_dst_rdy,

                TX_MFB_DATA    => USR_TX_MFB_DATA(0),
                TX_MFB_META    => mrg_tx_mfb_meta,
                TX_MFB_SOF     => USR_TX_MFB_SOF(0),
                TX_MFB_EOF     => USR_TX_MFB_EOF(0),
                TX_MFB_SOF_POS => USR_TX_MFB_SOF_POS(0),
                TX_MFB_EOF_POS => USR_TX_MFB_EOF_POS(0),
                TX_MFB_SRC_RDY => USR_TX_MFB_SRC_RDY(0),
                TX_MFB_DST_RDY => USR_TX_MFB_DST_RDY(0));

        USR_TX_MFB_META_HDR_META(0) <= mrg_tx_mfb_meta(HDR_META_WIDTH -1 downto 0);
        USR_TX_MFB_META_CHAN(0)     <= mrg_tx_mfb_meta(log2(CHANNELS)+HDR_META_WIDTH -1 downto HDR_META_WIDTH);
        USR_TX_MFB_META_PKT_SIZE(0) <= mrg_tx_mfb_meta(log2(PKT_SIZE_MAX+1)+log2(CHANNELS)+HDR_META_WIDTH -1 downto log2(CHANNELS)+HDR_META_WIDTH);

        -- assign rest of the outputs to 0
        chan_outs_others_zero_g : for i in 1 to (CHANNELS -1) generate
            USR_TX_MFB_META_PKT_SIZE(i) <= (others => '0');
            USR_TX_MFB_META_CHAN(i)     <= (others => '0');
            USR_TX_MFB_META_HDR_META(i) <= (others => '0');
            USR_TX_MFB_DATA(i)          <= (others => '0');
            USR_TX_MFB_SOF(i)           <= (others => '0');
            USR_TX_MFB_EOF(i)           <= (others => '0');
            USR_TX_MFB_SOF_POS(i)       <= (others => '0');
            USR_TX_MFB_EOF_POS(i)       <= (others => '0');
            USR_TX_MFB_SRC_RDY(i)       <= '0';
        end generate;
    else generate

        cores_to_out_g : for i in 0 to (CHANNELS -1) generate
            USR_TX_MFB_META_CHAN(i) <= std_logic_vector(to_unsigned(i, log2(CHANNELS)));
        end generate;

        USR_TX_MFB_META_PKT_SIZE <= chan_core_mfb_meta_pkt_size;
        USR_TX_MFB_META_HDR_META <= chan_core_mfb_meta_hdr_meta;

        USR_TX_MFB_DATA       <= chan_core_mfb_data;
        USR_TX_MFB_SOF        <= chan_core_mfb_sof;
        USR_TX_MFB_EOF        <= chan_core_mfb_eof;
        USR_TX_MFB_SOF_POS    <= chan_core_mfb_sof_pos;
        USR_TX_MFB_EOF_POS    <= chan_core_mfb_eof_pos;
        USR_TX_MFB_SRC_RDY    <= chan_core_mfb_src_rdy;
        chan_core_mfb_dst_rdy <= USR_TX_MFB_DST_RDY;
    end generate;
end architecture;
