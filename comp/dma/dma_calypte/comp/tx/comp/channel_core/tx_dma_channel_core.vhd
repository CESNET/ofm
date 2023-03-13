-- tx_dma_channel_core.vhd: binds incoming PCIe transactions into one packet, each set of
-- transactions, which create a packet, is delimited by the DMA header
-- Copyright (C) 2022 CESNET z.s.p.o.
-- Author(s): Vladislav Valek  <xvalek14@vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Note:

use work.math_pack.all;

-- The component provides the core functionality of the TX DMA Calypte controller.
-- It accepts PCIe transactions on the input and outputs DMA frames on the output.
-- The output frame can consist of one or more PCIe transactions which are binded
-- together in the internal components. Each set of transactions (which make a
-- whole packet) is delimited by the DMA header sent in a separate PCIe
-- transaction. The block scheme of the `CHANNEL_CORE` component is provided in the
-- following figure:
--
-- .. figure:: img/tx_calypte_block-chan_core_block.svg
--     :align: center
--     :scale: 100%
entity TX_DMA_CHANNEL_CORE is
    generic (
        DEVICE : string := "ULTRASCALE";

        -- =========================================================================================
        -- Input PCIe interface parameters
        -- =========================================================================================
        PCIE_MFB_REGIONS     : natural := 1;
        PCIE_MFB_REGION_SIZE : natural := 1;
        PCIE_MFB_BLOCK_SIZE  : natural := 8;
        PCIE_MFB_ITEM_WIDTH  : natural := 32;

        -- =========================================================================================
        -- Output (user logic) interface
        -- =========================================================================================
        USR_MFB_REGIONS     : natural := 1;
        USR_MFB_REGION_SIZE : natural := 4;
        USR_MFB_BLOCK_SIZE  : natural := 8;
        USR_MFB_ITEM_WIDTH  : natural := 8;

        -- =========================================================================================
        -- Others
        -- =========================================================================================
        -- Width of the metadata in bits that are contained in the DMA header
        HDR_META_WIDTH : natural := 24;
        -- Largest packet (in bytes) which can come out of USR_MFB interface
        PKT_SIZE_MAX   : natural := 2**16 - 1;
        -- Choosen type of RAM used in the internal FIFO, for more information on available types, refer
        -- to the :vhdl:type:`FIFOX_RAM_TYPE`
        RAM_TYPE   : string  := "AUTO";
        -- Number of data words that can be stored in internal FIFO
        FIFO_DEPTH : natural := 512

        );
    port (
        CLK   : in std_logic;
        RESET : in std_logic;

        -- =========================================================================================
        -- Input PCIe MFB interface
        -- =========================================================================================
        -- One-bit information if current transaction contains the DMA header
        PCIE_MFB_META_IS_DMA_HDR : in std_logic;
        -- Byte enable of the first and last DWord in the incoming transaction, valid with SOF
        PCIE_MFB_META_FBE : in std_logic_vector(4 -1 downto 0);
        PCIE_MFB_META_LBE : in std_logic_vector(4 -1 downto 0);

        PCIE_MFB_DATA    : in  std_logic_vector(PCIE_MFB_REGIONS*PCIE_MFB_REGION_SIZE*PCIE_MFB_BLOCK_SIZE*PCIE_MFB_ITEM_WIDTH-1 downto 0);
        PCIE_MFB_SOF     : in  std_logic_vector(PCIE_MFB_REGIONS -1 downto 0);
        PCIE_MFB_EOF     : in  std_logic_vector(PCIE_MFB_REGIONS -1 downto 0);
        PCIE_MFB_SOF_POS : in  std_logic_vector(PCIE_MFB_REGIONS*max(1, log2(PCIE_MFB_REGION_SIZE)) -1 downto 0);
        PCIE_MFB_EOF_POS : in  std_logic_vector(PCIE_MFB_REGIONS*max(1, log2(PCIE_MFB_REGION_SIZE*PCIE_MFB_BLOCK_SIZE)) -1 downto 0);
        PCIE_MFB_SRC_RDY : in  std_logic;
        PCIE_MFB_DST_RDY : out std_logic;

        -- =========================================================================================
        -- Output MFB interface
        -- =========================================================================================
        -- Length of the output packet in bytes
        USR_MFB_META_PKT_SIZE : out std_logic_vector(log2(PKT_SIZE_MAX + 1) -1 downto 0);
        -- Metadata information from the DMA header
        USR_MFB_META_HDR_META : out std_logic_vector(HDR_META_WIDTH -1 downto 0);

        USR_MFB_DATA    : out std_logic_vector(USR_MFB_REGIONS*USR_MFB_REGION_SIZE*USR_MFB_BLOCK_SIZE*USR_MFB_ITEM_WIDTH-1 downto 0);
        USR_MFB_SOF     : out std_logic_vector(USR_MFB_REGIONS -1 downto 0);
        USR_MFB_EOF     : out std_logic_vector(USR_MFB_REGIONS -1 downto 0);
        USR_MFB_SOF_POS : out std_logic_vector(USR_MFB_REGIONS*max(1, log2(USR_MFB_REGION_SIZE)) -1 downto 0);
        USR_MFB_EOF_POS : out std_logic_vector(USR_MFB_REGIONS*max(1, log2(USR_MFB_REGION_SIZE*USR_MFB_BLOCK_SIZE)) -1 downto 0);
        USR_MFB_SRC_RDY : out std_logic;
        USR_MFB_DST_RDY : in  std_logic;

        -- =========================================================================================
        -- Start/stop interface from the TX_DMA_SW_MANAGER
        -- =========================================================================================
        START_REQ_VLD : in  std_logic;
        START_REQ_ACK : out std_logic;
        STOP_REQ_VLD  : in  std_logic;
        STOP_REQ_ACK  : out std_logic;

        -- =========================================================================================
        -- Status information about taken capacity of internal FIFOs
        -- =========================================================================================
        DATA_FIFO_STATUS : out std_logic_vector(log2(FIFO_DEPTH) downto 0);
        HDR_FIFO_STATUS  : out std_logic_vector(log2(FIFO_DEPTH) downto 0);

        -- =========================================================================================
        -- Control signals for packet counters
        -- =========================================================================================
        PKT_SENT_INC  : out std_logic;
        PKT_SENT_SIZE : out std_logic_vector(log2(PKT_SIZE_MAX+1) -1 downto 0);
        PKT_DISC_INC  : out std_logic;
        PKT_DISC_SIZE : out std_logic_vector(log2(PKT_SIZE_MAX+1) -1 downto 0)
        );
end entity;

architecture FULL of TX_DMA_CHANNEL_CORE is

    -- =============================================================================================
    -- NOTE: Every internal *_mfb_meta signal contains the size of the packet in bytes and one bit
    -- indication if current transaction is a DMA header. The meta informations are valid with SOF.
    -- =============================================================================================

    constant PCIE_MFB_WIDTH : natural := PCIE_MFB_REGIONS*PCIE_MFB_REGION_SIZE*PCIE_MFB_BLOCK_SIZE*PCIE_MFB_ITEM_WIDTH;
    constant USR_MFB_WIDTH  : natural := USR_MFB_REGIONS*USR_MFB_REGION_SIZE*USR_MFB_BLOCK_SIZE*USR_MFB_ITEM_WIDTH;

    -- =============================================================================================
    -- Defining ranges for meta signal
    -- =============================================================================================
    constant PCIE_META_IS_DMA_HDR_W : natural := 1;
    constant PCIE_META_FBE_W : natural := 4;
    constant PCIE_META_LBE_W : natural := 4;

    constant PCIE_META_IS_DMA_HDR_O : natural := 0;
    constant PCIE_META_FBE_O : natural := PCIE_META_IS_DMA_HDR_O + PCIE_META_IS_DMA_HDR_W;
    constant PCIE_META_LBE_O : natural := PCIE_META_FBE_O + PCIE_META_FBE_W;

    subtype PCIE_META_IS_DMA_HDR is natural range PCIE_META_IS_DMA_HDR_O + PCIE_META_IS_DMA_HDR_W -1 downto PCIE_META_IS_DMA_HDR_O;
    subtype PCIE_META_FBE is natural range PCIE_META_FBE_O + PCIE_META_FBE_W -1 downto PCIE_META_FBE_O;
    subtype PCIE_META_LBE is natural range PCIE_META_LBE_O + PCIE_META_LBE_W -1 downto PCIE_META_LBE_O;

    -- =============================================================================================
    -- State machines' states
    -- =============================================================================================
    type channel_active_state_t is (CHANNEL_RUNNING, CHANNEL_START, CHANNEL_STOP_PENDING, CHANNEL_STOPPED);
    signal channel_active_pst : channel_active_state_t := CHANNEL_STOPPED;
    signal channel_active_nst : channel_active_state_t := CHANNEL_STOPPED;

    type pkt_acc_state_t is (S_IDLE, S_PKT_PENDING, S_PKT_DROP);
    signal pkt_acc_pst : pkt_acc_state_t := S_IDLE;
    signal pkt_acc_nst : pkt_acc_state_t := S_IDLE;

    signal pkt_drop_en         : std_logic_vector(PCIE_MFB_REGIONS -1 downto 0);
    signal pkt_acc_mfb_data    : std_logic_vector(PCIE_MFB_WIDTH -1 downto 0);
    signal pkt_acc_mfb_meta    : std_logic_vector(4+4+1 -1 downto 0);
    signal pkt_acc_mfb_sof_pos : std_logic_vector(PCIE_MFB_REGIONS*max(1, log2(PCIE_MFB_REGION_SIZE)) -1 downto 0);
    signal pkt_acc_mfb_eof_pos : std_logic_vector(PCIE_MFB_REGIONS*max(1, log2(PCIE_MFB_REGION_SIZE*PCIE_MFB_BLOCK_SIZE)) -1 downto 0);
    signal pkt_acc_mfb_sof     : std_logic_vector(PCIE_MFB_REGIONS -1 downto 0);
    signal pkt_acc_mfb_eof     : std_logic_vector(PCIE_MFB_REGIONS -1 downto 0);
    signal pkt_acc_mfb_src_rdy : std_logic;
    signal pkt_acc_mfb_dst_rdy : std_logic;

    signal cutt_mfb_data    : std_logic_vector(PCIE_MFB_WIDTH -1 downto 0);
    signal cutt_mfb_meta    : std_logic_vector(4+4+1 -1 downto 0);
    signal cutt_mfb_sof_pos : std_logic_vector(PCIE_MFB_REGIONS*max(1, log2(PCIE_MFB_REGION_SIZE)) -1 downto 0);
    signal cutt_mfb_eof_pos : std_logic_vector(PCIE_MFB_REGIONS*max(1, log2(PCIE_MFB_REGION_SIZE*PCIE_MFB_BLOCK_SIZE)) -1 downto 0);
    signal cutt_mfb_sof     : std_logic_vector(PCIE_MFB_REGIONS -1 downto 0);
    signal cutt_mfb_eof     : std_logic_vector(PCIE_MFB_REGIONS -1 downto 0);
    signal cutt_mfb_src_rdy : std_logic;
    signal cutt_mfb_dst_rdy : std_logic;

    -- this FSM is technically a counter
    signal align_ctl_pst : unsigned(max(1, log2(PCIE_MFB_BLOCK_SIZE)) -1 downto 0);
    signal align_ctl_nst : unsigned(max(1, log2(PCIE_MFB_BLOCK_SIZE)) -1 downto 0);
    signal align_block   : std_logic_vector(max(1, log2(PCIE_MFB_BLOCK_SIZE)) -1 downto 0);
    -- storing registers for FBE and LBE values
    signal cutt_pcie_fbe_pst : std_logic_vector(4 -1 downto 0);
    signal cutt_pcie_lbe_pst : std_logic_vector(4 -1 downto 0);
    signal cutt_pcie_fbe_nst : std_logic_vector(4 -1 downto 0);
    signal cutt_pcie_lbe_nst : std_logic_vector(4 -1 downto 0);
    -- determine the position of last valid byte in last DW of the transaction
    signal cutt_mfb_byte_eof_pos : std_logic_vector(2 -1 downto 0);

    signal align_mfb_data    : std_logic_vector(USR_MFB_WIDTH -1 downto 0);
    signal align_mfb_meta    : std_logic_vector(4+4+1 -1 downto 0);
    -- special case because the items are rearranged an not the blocks
    signal align_mfb_sof_pos : std_logic_vector(USR_MFB_REGIONS*max(1, log2(PCIE_MFB_BLOCK_SIZE)) -1 downto 0);
    signal align_mfb_eof_pos : std_logic_vector(USR_MFB_REGIONS*max(1, log2(USR_MFB_REGION_SIZE*USR_MFB_BLOCK_SIZE)) -1 downto 0);
    signal align_mfb_sof     : std_logic_vector(USR_MFB_REGIONS -1 downto 0);
    signal align_mfb_eof     : std_logic_vector(USR_MFB_REGIONS -1 downto 0);
    signal align_mfb_src_rdy : std_logic;
    signal align_mfb_dst_rdy : std_logic;

    type pkt_build_state_t is (START_DETECT, SEGMENT_RECEPTION, SEGMENT_MERGE, SEGMENT_MERGE_BREAK);
    signal pkt_build_pst : pkt_build_state_t := START_DETECT;
    signal pkt_build_nst : pkt_build_state_t := START_DETECT;

    -- Put aside register output of the pkt_build_state FSM
    signal mfb_data_pst    : std_logic_vector(USR_MFB_WIDTH -1 downto 0);
    signal mfb_sof_pos_pst : std_logic_vector(USR_MFB_REGIONS*max(1, log2(USR_MFB_REGION_SIZE)) -1 downto 0);
    signal mfb_eof_pos_pst : std_logic_vector(USR_MFB_REGIONS*max(1, log2(USR_MFB_REGION_SIZE*USR_MFB_BLOCK_SIZE)) -1 downto 0);
    signal mfb_sof_pst     : std_logic_vector(USR_MFB_REGIONS -1 downto 0);
    signal mfb_eof_pst     : std_logic_vector(USR_MFB_REGIONS -1 downto 0);
    signal mfb_src_rdy_pst : std_logic;

    -- Put aside register input of the pkt_build_state FSM
    signal mfb_data_nst    : std_logic_vector(USR_MFB_WIDTH -1 downto 0);
    signal mfb_sof_pos_nst : std_logic_vector(USR_MFB_REGIONS*max(1, log2(USR_MFB_REGION_SIZE)) -1 downto 0);
    signal mfb_eof_pos_nst : std_logic_vector(USR_MFB_REGIONS*max(1, log2(USR_MFB_REGION_SIZE*USR_MFB_BLOCK_SIZE)) -1 downto 0);
    signal mfb_sof_nst     : std_logic_vector(USR_MFB_REGIONS -1 downto 0);
    signal mfb_eof_nst     : std_logic_vector(USR_MFB_REGIONS -1 downto 0);
    signal mfb_src_rdy_nst : std_logic;

    signal build_fsm_mfb_data    : std_logic_vector(USR_MFB_WIDTH -1 downto 0);
    signal build_fsm_mfb_sof_pos : std_logic_vector(USR_MFB_REGIONS*max(1, log2(USR_MFB_REGION_SIZE)) -1 downto 0);
    signal build_fsm_mfb_eof_pos : std_logic_vector(USR_MFB_REGIONS*max(1, log2(USR_MFB_REGION_SIZE*USR_MFB_BLOCK_SIZE)) -1 downto 0);
    signal build_fsm_mfb_sof     : std_logic_vector(USR_MFB_REGIONS -1 downto 0);
    signal build_fsm_mfb_eof     : std_logic_vector(USR_MFB_REGIONS -1 downto 0);
    signal build_fsm_mfb_src_rdy : std_logic;

    -- Output register of the pkt_build_state
    signal build_fsm_mfb_data_reg    : std_logic_vector(USR_MFB_WIDTH -1 downto 0);
    signal build_fsm_mfb_sof_pos_reg : std_logic_vector(USR_MFB_REGIONS*max(1, log2(USR_MFB_REGION_SIZE)) -1 downto 0);
    signal build_fsm_mfb_eof_pos_reg : std_logic_vector(USR_MFB_REGIONS*max(1, log2(USR_MFB_REGION_SIZE*USR_MFB_BLOCK_SIZE)) -1 downto 0);
    signal build_fsm_mfb_sof_reg     : std_logic_vector(USR_MFB_REGIONS -1 downto 0);
    signal build_fsm_mfb_eof_reg     : std_logic_vector(USR_MFB_REGIONS -1 downto 0);
    signal build_fsm_mfb_src_rdy_reg : std_logic;

    -- Additional outuput signals of the pkt_build_state FSM
    signal ovrd_mfb_eof       : std_logic;
    signal ovrd_mfb_src_rdy   : std_logic;
    signal seg_merge_store_en : std_logic;

    -- Storage FIFO for complete packets
    signal fifo_rx_mfb_data    : std_logic_vector(USR_MFB_WIDTH -1 downto 0);
    signal fifo_rx_mfb_sof_pos : std_logic_vector(USR_MFB_REGIONS*max(1, log2(USR_MFB_REGION_SIZE)) -1 downto 0);
    signal fifo_rx_mfb_eof_pos : std_logic_vector(USR_MFB_REGIONS*max(1, log2(USR_MFB_REGION_SIZE*USR_MFB_BLOCK_SIZE)) -1 downto 0);
    signal fifo_rx_mfb_sof     : std_logic_vector(USR_MFB_REGIONS -1 downto 0);
    signal fifo_rx_mfb_eof     : std_logic_vector(USR_MFB_REGIONS -1 downto 0);
    signal fifo_rx_mfb_src_rdy : std_logic;
    signal fifo_rx_mfb_dst_rdy : std_logic;

    signal fifo_tx_mfb_data    : std_logic_vector(USR_MFB_WIDTH -1 downto 0);
    signal fifo_tx_mfb_sof_pos : std_logic_vector(USR_MFB_REGIONS*max(1, log2(USR_MFB_REGION_SIZE)) -1 downto 0);
    signal fifo_tx_mfb_eof_pos : std_logic_vector(USR_MFB_REGIONS*max(1, log2(USR_MFB_REGION_SIZE*USR_MFB_BLOCK_SIZE)) -1 downto 0);
    signal fifo_tx_mfb_sof     : std_logic_vector(USR_MFB_REGIONS -1 downto 0);
    signal fifo_tx_mfb_eof     : std_logic_vector(USR_MFB_REGIONS -1 downto 0);
    signal fifo_tx_mfb_src_rdy : std_logic;
    signal fifo_tx_mfb_dst_rdy : std_logic;

    -- Storge FIFO for deparsed DMA header information
    signal fifo_rx_mvb_dst_rdy : std_logic;
    signal fifo_tx_mvb_data    : std_logic_vector(HDR_META_WIDTH + log2(PKT_SIZE_MAX+1) -1 downto 0);
    signal fifo_tx_mvb_src_rdy : std_logic;
    signal fifo_tx_mvb_dst_rdy : std_logic;

    -- compound DST_RDY from both of the FIFOs
    signal fifos_rx_dst_rdy : std_logic;

    type pkt_dispatch_state_t is (PKT_BEGIN, PKT_PROCESS);
    signal pkt_dispatch_pst : pkt_dispatch_state_t := PKT_BEGIN;
    signal pkt_dispatch_nst : pkt_dispatch_state_t := PKT_BEGIN;

    -- Increment signal for the packet counter
    signal pkt_size_stored  : std_logic_vector(log2(PKT_SIZE_MAX+1) -1 downto 0);
    signal pkt_size_curr    : std_logic_vector(log2(PKT_SIZE_MAX+1) -1 downto 0);

    -- attribute mark_debug : string;

    -- attribute mark_debug of PCIE_MFB_META_IS_DMA_HDR : signal is "true";

    -- attribute mark_debug of PCIE_MFB_DATA    : signal is "true";
    -- attribute mark_debug of PCIE_MFB_SOF     : signal is "true";
    -- attribute mark_debug of PCIE_MFB_EOF     : signal is "true";
    -- attribute mark_debug of PCIE_MFB_SOF_POS : signal is "true";
    -- attribute mark_debug of PCIE_MFB_EOF_POS : signal is "true";
    -- attribute mark_debug of PCIE_MFB_SRC_RDY : signal is "true";
    -- attribute mark_debug of PCIE_MFB_DST_RDY : signal is "true";

    -- attribute mark_debug of USR_MFB_META_PKT_SIZE : signal is "true";
    -- attribute mark_debug of USR_MFB_META_HDR_META : signal is "true";

    -- attribute mark_debug of USR_MFB_DATA    : signal is "true";
    -- attribute mark_debug of USR_MFB_SOF     : signal is "true";
    -- attribute mark_debug of USR_MFB_EOF     : signal is "true";
    -- attribute mark_debug of USR_MFB_SOF_POS : signal is "true";
    -- attribute mark_debug of USR_MFB_EOF_POS : signal is "true";
    -- attribute mark_debug of USR_MFB_SRC_RDY : signal is "true";
    -- attribute mark_debug of USR_MFB_DST_RDY : signal is "true";

    -- attribute mark_debug of START_REQ_VLD : signal is "true";
    -- attribute mark_debug of START_REQ_ACK : signal is "true";
    -- attribute mark_debug of STOP_REQ_VLD  : signal is "true";
    -- attribute mark_debug of STOP_REQ_ACK  : signal is "true";

    -- attribute mark_debug of DATA_FIFO_STATUS : signal is "true";
    -- attribute mark_debug of HDR_FIFO_STATUS  : signal is "true";

    -- attribute mark_debug of channel_active_pst : signal is "true";
    -- attribute mark_debug of pkt_acc_pst        : signal is "true";
    -- attribute mark_debug of pkt_dispatch_pst   : signal is "true";
    -- attribute mark_debug of pkt_build_pst      : signal is "true";
    -- attribute mark_debug of align_ctl_pst      : signal is "true";
    -- attribute mark_debug of align_block        : signal is "true";

    -- attribute mark_debug of pkt_drop_en          : signal is "true";
    -- attribute mark_debug of pkt_acc_mfb_data    : signal is "true";
    -- attribute mark_debug of pkt_acc_mfb_meta    : signal is "true";
    -- attribute mark_debug of pkt_acc_mfb_sof     : signal is "true";
    -- attribute mark_debug of pkt_acc_mfb_eof     : signal is "true";
    -- attribute mark_debug of pkt_acc_mfb_sof_pos : signal is "true";
    -- attribute mark_debug of pkt_acc_mfb_eof_pos : signal is "true";
    -- attribute mark_debug of pkt_acc_mfb_src_rdy : signal is "true";
    -- attribute mark_debug of pkt_acc_mfb_dst_rdy : signal is "true";

    -- attribute mark_debug of cutt_mfb_data    : signal is "true";
    -- attribute mark_debug of cutt_mfb_meta    : signal is "true";
    -- attribute mark_debug of cutt_mfb_sof     : signal is "true";
    -- attribute mark_debug of cutt_mfb_eof     : signal is "true";
    -- attribute mark_debug of cutt_mfb_sof_pos : signal is "true";
    -- attribute mark_debug of cutt_mfb_eof_pos : signal is "true";
    -- attribute mark_debug of cutt_mfb_src_rdy : signal is "true";
    -- attribute mark_debug of cutt_mfb_dst_rdy : signal is "true";

    -- attribute mark_debug of align_mfb_data    : signal is "true";
    -- attribute mark_debug of align_mfb_meta    : signal is "true";
    -- attribute mark_debug of align_mfb_sof     : signal is "true";
    -- attribute mark_debug of align_mfb_eof     : signal is "true";
    -- attribute mark_debug of align_mfb_sof_pos : signal is "true";
    -- attribute mark_debug of align_mfb_eof_pos : signal is "true";
    -- attribute mark_debug of align_mfb_src_rdy : signal is "true";
    -- attribute mark_debug of align_mfb_dst_rdy : signal is "true";

    -- attribute mark_debug of fifo_rx_mfb_data    : signal is "true";
    -- attribute mark_debug of fifo_rx_mfb_sof_pos : signal is "true";
    -- attribute mark_debug of fifo_rx_mfb_eof_pos : signal is "true";
    -- attribute mark_debug of fifo_rx_mfb_sof     : signal is "true";
    -- attribute mark_debug of fifo_rx_mfb_eof     : signal is "true";
    -- attribute mark_debug of fifo_rx_mfb_src_rdy : signal is "true";
    -- attribute mark_debug of fifo_rx_mfb_dst_rdy : signal is "true";

    -- attribute mark_debug of fifo_rx_mvb_dst_rdy : signal is "true";
begin

    -- =============================================================================================
    -- Channel start/stop control
    -- =============================================================================================
    channel_active_state_reg_p : process (CLK) is
    begin
        if (rising_edge(CLK)) then
            if (RESET = '1') then
                channel_active_pst <= CHANNEL_STOPPED;
            else
                channel_active_pst <= channel_active_nst;
            end if;
        end if;
    end process;

    channel_active_nst_logic_p : process (all) is
    begin
        channel_active_nst <= channel_active_pst;
        START_REQ_ACK      <= '0';
        STOP_REQ_ACK       <= '0';

        case channel_active_pst is
            when CHANNEL_STOPPED =>
                if (START_REQ_VLD = '1') then
                    channel_active_nst <= CHANNEL_START;
                end if;

            when CHANNEL_START =>
                START_REQ_ACK      <= '1';
                channel_active_nst <= CHANNEL_RUNNING;

            when CHANNEL_RUNNING =>
                if (STOP_REQ_VLD = '1') then
                    channel_active_nst <= CHANNEL_STOP_PENDING;
                end if;

            when CHANNEL_STOP_PENDING =>
                if (pkt_acc_pst = S_IDLE) then
                    STOP_REQ_ACK       <= '1';
                    channel_active_nst <= CHANNEL_STOPPED;
                end if;
        end case;
    end process;

    -- =============================================================================================
    -- Status of a packet processing
    --
    -- The PKT_PENDING means there are still incoming PCIe transactions for the current packet.
    -- =============================================================================================
    pkt_acceptor_state_reg_p : process (CLK) is
    begin
        if (rising_edge(CLK)) then
            if (RESET = '1') then
                pkt_acc_pst <= S_IDLE;
            else
                pkt_acc_pst <= pkt_acc_nst;
            end if;
        end if;
    end process;

    pkt_acceptor_nst_logic_p : process (all) is
    begin
        pkt_acc_nst <= pkt_acc_pst;
        pkt_drop_en <= (others => '0');

        case pkt_acc_pst is
            when S_IDLE =>
                if (
                    PCIE_MFB_SRC_RDY = '1'
                    and PCIE_MFB_SOF = "1"
                    ) then

                    if (channel_active_pst = CHANNEL_RUNNING) then
                        pkt_acc_nst <= S_PKT_PENDING;
                    else
                        pkt_acc_nst <= S_PKT_DROP;
                        pkt_drop_en <= (others => '1');
                    end if;
                end if;

            when S_PKT_PENDING =>

                if (PCIE_MFB_SRC_RDY = '1' and PCIE_MFB_META_IS_DMA_HDR = '1') then
                    pkt_acc_nst <= S_IDLE;
                end if;

            when S_PKT_DROP =>
                pkt_drop_en <= (others => '1');

                if (PCIE_MFB_SRC_RDY = '1' and PCIE_MFB_META_IS_DMA_HDR = '1') then
                    pkt_acc_nst <= S_IDLE;
                end if;
        end case;
    end process;

    -- choose only packet size from the DMA header
    PKT_DISC_SIZE <= PCIE_MFB_DATA(128 + log2(PKT_SIZE_MAX+1) -1 downto 128);
    PKT_DISC_INC  <= '1' when (pkt_acc_pst = S_PKT_DROP and PCIE_MFB_SRC_RDY = '1' and PCIE_MFB_META_IS_DMA_HDR = '1' and PCIE_MFB_DST_RDY = '1') else '0';

    -- =============================================================================================
    -- Packet droping
    --
    -- Meeting specific conditions regarding processing of a current packet and channel active
    -- status will cause every packet on the input to be dropped.
    -- =============================================================================================
    pkt_dropper_i : entity work.MFB_DROPPER
        generic map (
            REGIONS     => PCIE_MFB_REGIONS,
            REGION_SIZE => PCIE_MFB_REGION_SIZE,
            BLOCK_SIZE  => PCIE_MFB_BLOCK_SIZE,
            ITEM_WIDTH  => PCIE_MFB_ITEM_WIDTH,
            META_WIDTH  => 1 + 4 + 4)
        port map (
            CLK   => CLK,
            RESET => RESET,

            RX_DATA    => PCIE_MFB_DATA,
            RX_META    => PCIE_MFB_META_LBE & PCIE_MFB_META_FBE & PCIE_MFB_META_IS_DMA_HDR,
            RX_SOF_POS => PCIE_MFB_SOF_POS,
            RX_EOF_POS => PCIE_MFB_EOF_POS,
            RX_SOF     => PCIE_MFB_SOF,
            RX_EOF     => PCIE_MFB_EOF,
            RX_SRC_RDY => PCIE_MFB_SRC_RDY,
            RX_DST_RDY => PCIE_MFB_DST_RDY,
            RX_DROP    => pkt_drop_en,

            TX_DATA    => pkt_acc_mfb_data,
            TX_META    => pkt_acc_mfb_meta,
            TX_SOF_POS => pkt_acc_mfb_sof_pos,
            TX_EOF_POS => pkt_acc_mfb_eof_pos,
            TX_SOF     => pkt_acc_mfb_sof,
            TX_EOF     => pkt_acc_mfb_eof,
            TX_SRC_RDY => pkt_acc_mfb_src_rdy,
            TX_DST_RDY => pkt_acc_mfb_dst_rdy);

    -- =============================================================================================
    -- Cut the PCIe header from the incoming transaction
    -- =============================================================================================
    pcie_hdr_cutter_i : entity work.MFB_CUTTER_SIMPLE
        generic map (
            REGIONS        => PCIE_MFB_REGIONS,
            REGION_SIZE    => PCIE_MFB_REGION_SIZE,
            BLOCK_SIZE     => PCIE_MFB_BLOCK_SIZE,
            ITEM_WIDTH     => PCIE_MFB_ITEM_WIDTH,
            META_WIDTH     => 1 + 4 + 4,
            META_ALIGNMENT => 0,
            -- 16 because the PCIe header is 16 DW long
            CUTTED_ITEMS   => 4)
        port map (
            CLK   => CLK,
            RESET => RESET,

            RX_DATA    => pkt_acc_mfb_data,
            RX_META    => pkt_acc_mfb_meta,
            RX_SOF     => pkt_acc_mfb_sof,
            RX_EOF     => pkt_acc_mfb_eof,
            RX_SOF_POS => pkt_acc_mfb_sof_pos,
            RX_EOF_POS => pkt_acc_mfb_eof_pos,
            RX_SRC_RDY => pkt_acc_mfb_src_rdy,
            RX_DST_RDY => pkt_acc_mfb_dst_rdy,
            RX_CUT     => pkt_acc_mfb_sof,

            TX_DATA    => cutt_mfb_data,
            TX_META    => cutt_mfb_meta,
            TX_SOF     => cutt_mfb_sof,
            TX_EOF     => cutt_mfb_eof,
            TX_SOF_POS => cutt_mfb_sof_pos,
            TX_EOF_POS => cutt_mfb_eof_pos,
            TX_SRC_RDY => cutt_mfb_src_rdy,
            TX_DST_RDY => cutt_mfb_dst_rdy);

    -- =============================================================================================
    -- DATA ALIGNER
    --
    -- Aligns incoming data with removed PCIe header so the packet can be transmiited without any
    -- gaps. The MFB_DATA_ALIGNER is a dynamic packet shifter which is controled by the logic
    -- provided here.
    -- =============================================================================================
    align_ctl_state_reg_p : process (CLK) is
    begin
        if (rising_edge(CLK)) then
            if (RESET = '1') then
                align_ctl_pst <= (others => '0');
                cutt_pcie_fbe_pst <= (others => '0');
                cutt_pcie_lbe_pst <= (others => '0');
            elsif (cutt_mfb_dst_rdy = '1') then
                align_ctl_pst <= align_ctl_nst;
                cutt_pcie_fbe_pst <= cutt_pcie_fbe_nst;
                cutt_pcie_lbe_pst <= cutt_pcie_lbe_nst;
            end if;
        end if;
    end process;

    align_ctl_logic_p : process (all) is
    begin
        align_ctl_nst <= align_ctl_pst;
        cutt_pcie_fbe_nst <= cutt_pcie_fbe_pst;
        cutt_pcie_lbe_nst <= cutt_pcie_lbe_pst;

        if (cutt_mfb_src_rdy = '1') then

            if (cutt_mfb_sof = "0" and cutt_mfb_eof = "1") then
                if (
                    std_match(cutt_pcie_lbe_pst, "1---")
                    or
                    (std_match(cutt_pcie_fbe_pst, "1---") and std_match(cutt_pcie_lbe_pst, "0000"))
                    ) then
                    -- The alignment of a next transaction should be set so that it begins in a DW
                    -- following immediately behind behind the DW in which a previous transaction has ended.
                    align_ctl_nst <= unsigned(cutt_mfb_eof_pos) + align_ctl_pst + 1;
                else
                    -- Broken alignment when the FBE, LBE or both are not comprising of consistent rows
                    -- of 1s. The transaction is shifted in a way, that the last DW of the previous
                    -- transaction is covered with the first DW of the next transaction.
                    align_ctl_nst <= unsigned(cutt_mfb_eof_pos) + align_ctl_pst;
                end if;

            -- Special case when PCIE transaction is so small that it fits to the current word. Then
            -- byte enables can be taken from the outputs of header cutter and not from the registers.
            elsif (cutt_mfb_sof = "1" and cutt_mfb_eof = "1") then
                if (
                    std_match(cutt_mfb_meta(PCIE_META_LBE), "1---")
                    or
                    (std_match(cutt_mfb_meta(PCIE_META_FBE), "1---") and std_match(cutt_mfb_meta(PCIE_META_LBE), "0000"))
                    ) then
                    align_ctl_nst <= unsigned(cutt_mfb_eof_pos) + align_ctl_pst + 1;
                else
                    align_ctl_nst <= unsigned(cutt_mfb_eof_pos) + align_ctl_pst;
                end if;

            -- when only the beginning of the transaction occurs, then take only values of byte
            -- enable signals to the register
            elsif (cutt_mfb_sof = "1" and cutt_mfb_eof = "0") then
                cutt_pcie_fbe_nst <= cutt_mfb_meta(PCIE_META_FBE);
                cutt_pcie_lbe_nst <= cutt_mfb_meta(PCIE_META_LBE);
            end if;

            -- if there is a DMA header, return the alignment for the beginning segment of the next
            -- packet to the 0th block
            if (cutt_mfb_sof = "1" and cutt_mfb_meta(PCIE_META_IS_DMA_HDR) = "1") then
                align_ctl_nst <= (others => '0');
            end if;
        end if;
    end process;

    -- This process duplicates the LBE value with the EOF of the transaction. This value is used
    -- furter when building the DMA frame.
    lbe_duplicaton_p: process (all) is
    begin
        cutt_mfb_byte_eof_pos <= "11";

        if (cutt_mfb_src_rdy = '1' and cutt_mfb_eof = "1") then

            if (cutt_mfb_sof = "0") then
                if (std_match(cutt_pcie_lbe_pst, "01--")) then
                    cutt_mfb_byte_eof_pos <= "10";
                elsif (std_match(cutt_pcie_lbe_pst, "001-")) then
                    cutt_mfb_byte_eof_pos <= "01";
                elsif (std_match(cutt_pcie_lbe_pst, "0001")) then
                    cutt_mfb_byte_eof_pos <= "00";
                end if;
            else
                if (cutt_mfb_meta(PCIE_META_LBE) = "0000") then
                    if (std_match(cutt_mfb_meta(PCIE_META_FBE),"0001")) then
                        cutt_mfb_byte_eof_pos <= "00";
                    elsif (std_match(cutt_mfb_meta(PCIE_META_FBE),"001-")) then
                        cutt_mfb_byte_eof_pos <= "01";
                    elsif (std_match(cutt_mfb_meta(PCIE_META_FBE),"01--")) then
                        cutt_mfb_byte_eof_pos <= "10";
                    end if;
                elsif (std_match(cutt_mfb_meta(PCIE_META_LBE), "0001")) then
                    cutt_mfb_byte_eof_pos <= "00";
                elsif (std_match(cutt_mfb_meta(PCIE_META_LBE), "001-")) then
                    cutt_mfb_byte_eof_pos <= "01";
                elsif (std_match(cutt_mfb_meta(PCIE_META_LBE), "01--")) then
                    cutt_mfb_byte_eof_pos <= "10";
                end if;
            end if;
        end if;
    end process;

    -- this process controls if the currently incoming transaction is the DMA header and if so,
    -- overrrides the align_ctl_pst value specified by the align_ctl_logic_p
    check_if_dma_hdr_p : process (all) is
    begin
        if (cutt_mfb_sof = "1" and cutt_mfb_src_rdy = '1' and cutt_mfb_meta(PCIE_META_IS_DMA_HDR) = "1") then
            align_block <= (others => '0');
        else
            align_block <= std_logic_vector(align_ctl_pst);
        end if;
    end process;

    data_aligner_i : entity work.MFB_DATA_ALIGNER
        generic map (
            REGION_SIZE => 8,
            BLOCK_SIZE  => 4,
            ITEM_WIDTH  => 8,

            META_WIDTH => 4+4+1)
        port map (
            CLK => CLK,
            RST => RESET,

            ALIGN_BLOCK => align_block,

            RX_MFB_DATA    => cutt_mfb_data,
            RX_MFB_META    => cutt_mfb_meta,
            RX_MFB_SOF     => cutt_mfb_sof(0),
            RX_MFB_EOF     => cutt_mfb_eof(0),
            -- every incoming segment arrives with SOF_POS=0 anyways
            RX_MFB_SOF_POS => "00" & cutt_mfb_sof_pos,
            RX_MFB_EOF_POS => cutt_mfb_eof_pos & cutt_mfb_byte_eof_pos,
            RX_MFB_SRC_RDY => cutt_mfb_src_rdy,
            RX_MFB_DST_RDY => cutt_mfb_dst_rdy,

            TX_MFB_DATA    => align_mfb_data,
            TX_MFB_META    => align_mfb_meta,
            TX_MFB_SOF     => align_mfb_sof(0),
            TX_MFB_EOF     => align_mfb_eof(0),
            TX_MFB_SOF_POS => align_mfb_sof_pos,
            TX_MFB_EOF_POS => align_mfb_eof_pos,
            TX_MFB_SRC_RDY => align_mfb_src_rdy,
            TX_MFB_DST_RDY => align_mfb_dst_rdy);

    align_mfb_dst_rdy <= fifos_rx_dst_rdy;

    -- =============================================================================================
    -- BUILDING OF A PACKET
    --
    -- The packet is builded out of one or many PCIe transtactions wchich is handled by the
    -- following FSM. Each packet is delimited by the DMA header which is sent at its end.
    -- =============================================================================================
    build_fsm_state_reg_p : process (CLK) is
    begin
        if (rising_edge(CLK)) then
            if (RESET = '1') then

                pkt_build_pst <= START_DETECT;

                mfb_data_pst    <= (others => '0');
                mfb_sof_pst     <= (others => '0');
                mfb_eof_pst     <= (others => '0');
                mfb_sof_pos_pst <= (others => '0');
                mfb_eof_pos_pst <= (others => '0');
                mfb_src_rdy_pst <= '0';

            elsif (fifos_rx_dst_rdy = '1') then

                pkt_build_pst <= pkt_build_nst;

                mfb_data_pst    <= mfb_data_nst;
                mfb_sof_pst     <= mfb_sof_nst;
                mfb_eof_pst     <= mfb_eof_nst;
                mfb_sof_pos_pst <= mfb_sof_pos_nst;
                mfb_eof_pos_pst <= mfb_eof_pos_nst;
                mfb_src_rdy_pst <= mfb_src_rdy_nst;

            end if;
        end if;
    end process;

    build_fsm_nst_logic_p : process (all) is
    begin

        pkt_build_nst <= pkt_build_pst;

        case pkt_build_pst is
            -- the FSM waits for a beginning segment of a new packet which shall be built
            when START_DETECT =>

                if (align_mfb_sof = "1" and align_mfb_src_rdy = '1') then
                    pkt_build_nst <= SEGMENT_RECEPTION;

                    -- when the initial segment comes and immediately ends in a current word, that
                    -- means, that this is a short segment
                    if (align_mfb_eof = "1") then
                        if (unsigned(align_mfb_eof_pos) < 31) then
                            pkt_build_nst <= SEGMENT_MERGE;
                        else
                            pkt_build_nst <= SEGMENT_MERGE_BREAK;
                        end if;
                    end if;
                end if;

            -- reception of single segments of a packet = building in progress
            when SEGMENT_RECEPTION =>

                if (align_mfb_src_rdy = '1') then

                    if (align_mfb_eof = "1") then
                        if (unsigned(align_mfb_eof_pos) < 31) then
                            pkt_build_nst <= SEGMENT_MERGE;
                        else
                            pkt_build_nst <= SEGMENT_MERGE_BREAK;
                        end if;
                    end if;
                end if;

            -- waiting for a following segment to be merged with a previous one
            when SEGMENT_MERGE | SEGMENT_MERGE_BREAK =>

                if (align_mfb_src_rdy = '1') then

                    -- if instead of a next segment, a DMA header arrives, the building of a packet
                    -- is finished
                    if (align_mfb_meta(0) = '1') then
                        pkt_build_nst <= START_DETECT;
                    elsif (align_mfb_eof = "1") then

                        if (unsigned(align_mfb_eof_pos) < 31) then
                            pkt_build_nst <= SEGMENT_MERGE;
                        else
                            pkt_build_nst <= SEGMENT_MERGE_BREAK;
                        end if;
                    else
                        pkt_build_nst <= SEGMENT_RECEPTION;
                    end if;
                end if;
        end case;
    end process;

    build_fsm_out_logic_p : process (all) is
    begin

        build_fsm_mfb_data    <= align_mfb_data;
        build_fsm_mfb_sof     <= (others => '0');
        build_fsm_mfb_eof     <= (others => '0');
        -- take only top bits from the align_mfb_sof_pos signal
        build_fsm_mfb_sof_pos <= align_mfb_sof_pos(align_mfb_sof_pos'high downto align_mfb_sof_pos'high - build_fsm_mfb_sof_pos'length + 1);
        build_fsm_mfb_eof_pos <= align_mfb_eof_pos;
        build_fsm_mfb_src_rdy <= '0';

        ovrd_mfb_eof       <= '0';
        ovrd_mfb_src_rdy   <= '0';
        seg_merge_store_en <= '1';

        mfb_data_nst    <= mfb_data_pst;
        mfb_sof_nst     <= mfb_sof_pst;
        mfb_eof_nst     <= mfb_eof_pst;
        mfb_sof_pos_nst <= mfb_sof_pos_pst;
        mfb_eof_pos_nst <= mfb_eof_pos_pst;
        mfb_src_rdy_nst <= mfb_src_rdy_pst;

        case pkt_build_pst is
            -- awaiting the arrival of the ínitial segment of a packet
            when START_DETECT =>

                if (align_mfb_sof = "1" and align_mfb_src_rdy = '1') then

                    build_fsm_mfb_sof     <= "1";
                    build_fsm_mfb_src_rdy <= '1';

                    if (align_mfb_eof = "1") then
                        build_fsm_mfb_src_rdy <= '0';

                        -- Put the current transaction into a side register because if another
                        -- segment of a packet arrives, then it needs to be connected in the current
                        -- word
                        if (unsigned(align_mfb_eof_pos) < 31) then
                            mfb_data_nst    <= align_mfb_data;
                            mfb_sof_nst     <= align_mfb_sof;
                            mfb_eof_nst     <= "0";
                            mfb_sof_pos_nst <= align_mfb_sof_pos(align_mfb_sof_pos'high downto align_mfb_sof_pos'high - build_fsm_mfb_sof_pos'length + 1);
                            mfb_eof_pos_nst <= align_mfb_eof_pos;
                            mfb_src_rdy_nst <= align_mfb_src_rdy;
                        end if;
                    end if;
                end if;

            -- receiving a current packet segment
            when SEGMENT_RECEPTION =>

                -- put the current transaction into a side register
                if (align_mfb_src_rdy = '1') then
                    build_fsm_mfb_src_rdy <= '1';

                    if (align_mfb_eof = "1") then
                        build_fsm_mfb_src_rdy <= '0';

                        if (unsigned(align_mfb_eof_pos) < 31) then
                            mfb_data_nst    <= align_mfb_data;
                            mfb_sof_nst     <= (others => '0');
                            mfb_eof_nst     <= (others => '0');
                            mfb_sof_pos_nst <= align_mfb_sof_pos(align_mfb_sof_pos'high downto align_mfb_sof_pos'high - build_fsm_mfb_sof_pos'length + 1);
                            mfb_eof_pos_nst <= align_mfb_eof_pos;
                            mfb_src_rdy_nst <= align_mfb_src_rdy;
                        end if;
                    end if;
                end if;

            -- merging of two packet segments in one word
            when SEGMENT_MERGE =>
                if (align_mfb_src_rdy = '1') then

                    -- the DMA header arrived, put data stored in the side register to the FIFO with
                    -- a valid EOF
                    if (align_mfb_meta(0) = '1') then

                        build_fsm_mfb_data    <= mfb_data_pst;
                        build_fsm_mfb_sof     <= mfb_sof_pst;
                        build_fsm_mfb_eof     <= "1";
                        build_fsm_mfb_sof_pos <= mfb_sof_pos_pst;
                        build_fsm_mfb_eof_pos <= mfb_eof_pos_pst;
                        build_fsm_mfb_src_rdy <= '1';

                    -- another segment of a packet arrived so merge these two segments to one word
                    -- but only store them in the side register because there are the current
                    -- segment ends in a current input word so another merging to the current
                    -- output word will follow
                    elsif (align_mfb_eof = "1" ) then
                        if (unsigned(align_mfb_eof_pos) < 31) then

                            for i in 0 to 31 loop
                                if (i <= unsigned(mfb_eof_pos_pst)) then
                                    mfb_data_nst(i*8 + 7 downto i*8) <= mfb_data_pst(i*8 + 7 downto i*8);
                                else
                                    mfb_data_nst(i*8 + 7 downto i*8) <= align_mfb_data(i*8 + 7 downto i*8);
                                end if;
                            end loop;

                            mfb_eof_pos_nst <= align_mfb_eof_pos;
                        else
                            for i in 0 to 31 loop
                                if (i <= unsigned(mfb_eof_pos_pst)) then
                                    build_fsm_mfb_data(i*8 + 7 downto i*8) <= mfb_data_pst(i*8 + 7 downto i*8);
                                else
                                    build_fsm_mfb_data(i*8 + 7 downto i*8) <= align_mfb_data(i*8 + 7 downto i*8);
                                end if;
                            end loop;

                            build_fsm_mfb_sof     <= mfb_sof_pst;
                            build_fsm_mfb_sof_pos <= mfb_sof_pos_pst;
                        end if;

                    -- the curent segment does not end in a current input word so send this merged
                    -- word into the FIFO
                    else

                        for i in 0 to 31 loop
                            if (i <= unsigned(mfb_eof_pos_pst)) then
                                build_fsm_mfb_data(i*8 + 7 downto i*8) <= mfb_data_pst(i*8 + 7 downto i*8);
                            else
                                build_fsm_mfb_data(i*8 + 7 downto i*8) <= align_mfb_data(i*8 + 7 downto i*8);
                            end if;
                        end loop;

                        build_fsm_mfb_sof     <= mfb_sof_pst;
                        build_fsm_mfb_sof_pos <= mfb_sof_pos_pst;
                        build_fsm_mfb_src_rdy <= '1';
                    end if;
                end if;

            -- data from the previous MFB transaction of the data aligner are stored in the
            -- seg_merge_break_reg and the decision needs to be made either if DMA header or another
            -- packet segment arrives. E.G. the border between two packet segments is also a border
            -- between two MFB words.
            when SEGMENT_MERGE_BREAK =>

                -- stop the output register before next segment arrives
                seg_merge_store_en <= '0';

                if (align_mfb_src_rdy = '1') then

                    seg_merge_store_en <= '1';

                    -- DMA header data are written to the MVB FIFO. The EOF and SRC_RDY values on the
                    -- input of the MFB FIFO are overriden by the FSM because there is implicitely
                    -- assumed that the next segment of a packet will follow and not the DMA header
                    if (align_mfb_meta(0) = '1') then
                        ovrd_mfb_eof     <= '1';
                        ovrd_mfb_src_rdy <= '1';
                    -- there comes the segment which also ends in the current word, so it needs to
                    -- be stored in the side-register
                    elsif (align_mfb_eof = "1") then
                        ovrd_mfb_src_rdy <= '1';

                        if (unsigned(align_mfb_eof_pos) < 31) then
                            mfb_data_nst    <= align_mfb_data;
                            mfb_eof_nst     <= align_mfb_eof;
                            mfb_eof_pos_nst <= align_mfb_eof_pos;
                            mfb_src_rdy_nst <= align_mfb_src_rdy;
                        end if;

                    -- there are two words and both are valid, one stored in the seg_merge_break_reg
                    -- and one on its input
                    else
                        ovrd_mfb_src_rdy      <= '1';
                        build_fsm_mfb_src_rdy <= '1';
                    end if;
                end if;
        end case;
    end process;

    seg_merge_break_reg_p : process (CLK) is
    begin
        if (rising_edge(CLK)) then
            if (RESET = '1') then

                build_fsm_mfb_src_rdy_reg <= '0';

            elsif (fifos_rx_dst_rdy = '1' and seg_merge_store_en = '1') then

                build_fsm_mfb_data_reg    <= build_fsm_mfb_data;
                build_fsm_mfb_sof_reg     <= build_fsm_mfb_sof;
                build_fsm_mfb_eof_reg     <= build_fsm_mfb_eof;
                build_fsm_mfb_sof_pos_reg <= build_fsm_mfb_sof_pos;
                build_fsm_mfb_eof_pos_reg <= build_fsm_mfb_eof_pos;
                build_fsm_mfb_src_rdy_reg <= build_fsm_mfb_src_rdy;

            end if;
        end if;
    end process;

    fifo_rx_mfb_data    <= build_fsm_mfb_data_reg;
    fifo_rx_mfb_sof     <= build_fsm_mfb_sof_reg;
    fifo_rx_mfb_eof     <= build_fsm_mfb_eof_reg or ovrd_mfb_eof;
    fifo_rx_mfb_sof_pos <= build_fsm_mfb_sof_pos_reg;
    fifo_rx_mfb_eof_pos <= build_fsm_mfb_eof_pos_reg;
    fifo_rx_mfb_src_rdy <= (build_fsm_mfb_src_rdy_reg or ovrd_mfb_src_rdy) and fifo_rx_mvb_dst_rdy;

    fifos_rx_dst_rdy <= fifo_rx_mfb_dst_rdy and fifo_rx_mvb_dst_rdy;

    -- =============================================================================================
    -- PACKET STORAGE
    --
    -- These FIFOs store complete packets and the metadata provided to them in the DMA header.
    -- =============================================================================================
    mfb_data_fifo_i : entity work.MFB_FIFOX
        generic map (
            REGIONS     => USR_MFB_REGIONS,
            REGION_SIZE => USR_MFB_REGION_SIZE,
            BLOCK_SIZE  => USR_MFB_BLOCK_SIZE,
            ITEM_WIDTH  => USR_MFB_ITEM_WIDTH,
            META_WIDTH  => 0,

            FIFO_DEPTH => FIFO_DEPTH,
            RAM_TYPE   => RAM_TYPE,
            DEVICE     => DEVICE,

            ALMOST_FULL_OFFSET  => 2,
            ALMOST_EMPTY_OFFSET => 2)
        port map (
            CLK => CLK,
            RST => RESET,

            RX_DATA    => fifo_rx_mfb_data,
            RX_META    => (others => '0'),
            RX_SOF_POS => fifo_rx_mfb_sof_pos,
            RX_EOF_POS => fifo_rx_mfb_eof_pos,
            RX_SOF     => fifo_rx_mfb_sof,
            RX_EOF     => fifo_rx_mfb_eof,
            RX_SRC_RDY => fifo_rx_mfb_src_rdy,
            RX_DST_RDY => fifo_rx_mfb_dst_rdy,

            TX_DATA    => fifo_tx_mfb_data,
            TX_META    => open,
            TX_SOF_POS => fifo_tx_mfb_sof_pos,
            TX_EOF_POS => fifo_tx_mfb_eof_pos,
            TX_SOF     => fifo_tx_mfb_sof,
            TX_EOF     => fifo_tx_mfb_eof,
            TX_SRC_RDY => fifo_tx_mfb_src_rdy,
            TX_DST_RDY => fifo_tx_mfb_dst_rdy,

            FIFO_STATUS => DATA_FIFO_STATUS,

            FIFO_AFULL  => open,
            FIFO_AEMPTY => open);

    mvb_hdr_fifo_i : entity work.MVB_FIFOX
        generic map (
            ITEMS      => 1,
            ITEM_WIDTH => HDR_META_WIDTH + log2(PKT_SIZE_MAX+1),

            FIFO_DEPTH => FIFO_DEPTH,
            RAM_TYPE   => RAM_TYPE,
            DEVICE     => DEVICE,

            ALMOST_FULL_OFFSET  => 2,
            ALMOST_EMPTY_OFFSET => 2,
            FAKE_FIFO           => FALSE)
        port map (
            CLK   => CLK,
            RESET => RESET,

            -- choose only valid data from the DMA header
            RX_DATA    => align_mfb_data(40+ HDR_META_WIDTH -1 downto 40) & align_mfb_data(log2(PKT_SIZE_MAX+1) -1 downto 0),
            RX_VLD     => (others => '1'),
            -- write when there is a DMA header
            RX_SRC_RDY => align_mfb_meta(0) and align_mfb_src_rdy and fifo_rx_mfb_dst_rdy,
            RX_DST_RDY => fifo_rx_mvb_dst_rdy,

            TX_DATA    => fifo_tx_mvb_data,
            TX_VLD     => open,
            TX_SRC_RDY => fifo_tx_mvb_src_rdy,
            TX_DST_RDY => fifo_tx_mvb_dst_rdy,

            STATUS => HDR_FIFO_STATUS,

            AFULL  => open,
            AEMPTY => open);

    -- =============================================================================================
    -- Output dispatching of a packet
    --
    -- This FSM handles the correct transmission of the packet on the output from storage FIFOs.
    -- =============================================================================================
    pkt_dispatch_state_reg_p : process (CLK) is
    begin
        if (rising_edge(CLK)) then
            if (RESET = '1') then
                pkt_dispatch_pst <= PKT_BEGIN;
                pkt_size_stored  <= (others => '0');
            elsif (USR_MFB_DST_RDY = '1') then
                pkt_dispatch_pst <= pkt_dispatch_nst;
                pkt_size_stored  <= pkt_size_curr;
            end if;
        end if;
    end process;

    pkt_dispatch_nst_logic_p : process (all) is
    begin
        pkt_dispatch_nst <= pkt_dispatch_pst;

        case pkt_dispatch_pst is
            when PKT_BEGIN =>
                if (fifo_tx_mfb_src_rdy = '1' and fifo_tx_mvb_src_rdy = '1' and fifo_tx_mfb_sof = "1" and fifo_tx_mfb_eof = "0") then
                    pkt_dispatch_nst <= PKT_PROCESS;
                end if;

            when PKT_PROCESS =>
                if (fifo_tx_mfb_src_rdy = '1' and fifo_tx_mfb_eof = "1") then
                    pkt_dispatch_nst <= PKT_BEGIN;
                end if;
        end case;
    end process;

    pkt_dispatch_out_logic_p : process (all) is
        variable pkt_size_uns : unsigned(log2(PKT_SIZE_MAX+1) -1 downto 0);
    begin

        USR_MFB_META_PKT_SIZE <= fifo_tx_mvb_data(log2(PKT_SIZE_MAX+1) -1 downto 0);
        USR_MFB_META_HDR_META <= fifo_tx_mvb_data(log2(PKT_SIZE_MAX+1) + HDR_META_WIDTH -1 downto log2(PKT_SIZE_MAX+1));

        USR_MFB_DATA    <= fifo_tx_mfb_data;
        USR_MFB_SOF     <= "0";
        USR_MFB_EOF     <= "0";
        USR_MFB_SOF_POS <= fifo_tx_mfb_sof_pos;
        USR_MFB_EOF_POS <= fifo_tx_mfb_eof_pos;
        USR_MFB_SRC_RDY <= '0';

        fifo_tx_mvb_dst_rdy <= '0';
        fifo_tx_mfb_dst_rdy <= '0';

        pkt_size_curr <= pkt_size_stored;
        PKT_SENT_SIZE <= pkt_size_stored;

        case pkt_dispatch_pst is
            when PKT_BEGIN =>

                if (fifo_tx_mfb_src_rdy = '1' and fifo_tx_mvb_src_rdy = '1' and fifo_tx_mfb_sof = "1") then

                    USR_MFB_SOF     <= "1";
                    USR_MFB_SRC_RDY <= '1';

                    fifo_tx_mfb_dst_rdy <= USR_MFB_DST_RDY;
                    fifo_tx_mvb_dst_rdy <= USR_MFB_DST_RDY;

                    if (fifo_tx_mfb_eof = "1") then
                        USR_MFB_EOF   <= "1";
                        PKT_SENT_SIZE <= fifo_tx_mvb_data(log2(PKT_SIZE_MAX+1) -1 downto 0);
                    else
                        pkt_size_curr <= fifo_tx_mvb_data(log2(PKT_SIZE_MAX+1) -1 downto 0);
                    end if;
                end if;

            when PKT_PROCESS =>

                USR_MFB_SRC_RDY     <= fifo_tx_mfb_src_rdy;
                fifo_tx_mfb_dst_rdy <= USR_MFB_DST_RDY;

                if (fifo_tx_mfb_eof = "1") then
                    USR_MFB_EOF  <= "1";
                end if;
        end case;
    end process;

    PKT_SENT_INC <= '1' when (fifo_tx_mfb_src_rdy = '1' and fifo_tx_mfb_eof = "1" and USR_MFB_DST_RDY = '1') else '0';
end architecture;
