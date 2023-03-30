-- tx_dma_chan_start_stop_ctrl.vhd: controls the acception of packets according to the running state
-- of the DMA channels
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

entity TX_DMA_CHAN_START_STOP_CTRL is
    generic (
        DEVICE : string := "ULTRASCALE";

        -- Total number of DMA Channels within this DMA Endpoint
        CHANNELS : natural := 8;

        -- =========================================================================================
        -- Input PCIe interface parameters
        -- =========================================================================================
        PCIE_MFB_REGIONS     : natural := 1;
        PCIE_MFB_REGION_SIZE : natural := 1;
        PCIE_MFB_BLOCK_SIZE  : natural := 8;
        PCIE_MFB_ITEM_WIDTH  : natural := 32;

        -- =========================================================================================
        -- Others
        -- =========================================================================================
        -- Largest packet (in bytes) which can come out of USR_MFB interface
        PKT_SIZE_MAX : natural := 2**16 - 1
        );
    port (
        CLK   : in std_logic;
        RESET : in std_logic;

        -- =========================================================================================
        -- Input PCIe MFB interface
        -- =========================================================================================
        PCIE_MFB_DATA    : in  std_logic_vector(PCIE_MFB_REGIONS*PCIE_MFB_REGION_SIZE*PCIE_MFB_BLOCK_SIZE*PCIE_MFB_ITEM_WIDTH-1 downto 0);
        PCIE_MFB_META    : in  std_logic_vector((PCIE_MFB_REGIONS*PCIE_MFB_REGION_SIZE*PCIE_MFB_BLOCK_SIZE*PCIE_MFB_ITEM_WIDTH)/8+log2(CHANNELS)+62+1-1 downto 0);
        PCIE_MFB_SOF     : in  std_logic_vector(PCIE_MFB_REGIONS -1 downto 0);
        PCIE_MFB_EOF     : in  std_logic_vector(PCIE_MFB_REGIONS -1 downto 0);
        PCIE_MFB_SOF_POS : in  std_logic_vector(PCIE_MFB_REGIONS*max(1, log2(PCIE_MFB_REGION_SIZE)) -1 downto 0);
        PCIE_MFB_EOF_POS : in  std_logic_vector(PCIE_MFB_REGIONS*max(1, log2(PCIE_MFB_REGION_SIZE*PCIE_MFB_BLOCK_SIZE)) -1 downto 0);
        PCIE_MFB_SRC_RDY : in  std_logic;
        PCIE_MFB_DST_RDY : out std_logic;

        -- =========================================================================================
        -- Output MFB interface
        -- =========================================================================================
        USR_MFB_DATA    : out std_logic_vector(PCIE_MFB_REGIONS*PCIE_MFB_REGION_SIZE*PCIE_MFB_BLOCK_SIZE*PCIE_MFB_ITEM_WIDTH-1 downto 0);
        USR_MFB_META    : out std_logic_vector((PCIE_MFB_REGIONS*PCIE_MFB_REGION_SIZE*PCIE_MFB_BLOCK_SIZE*PCIE_MFB_ITEM_WIDTH)/8+log2(CHANNELS)+62+1-1 downto 0);
        USR_MFB_SOF     : out std_logic_vector(PCIE_MFB_REGIONS -1 downto 0);
        USR_MFB_EOF     : out std_logic_vector(PCIE_MFB_REGIONS -1 downto 0);
        USR_MFB_SOF_POS : out std_logic_vector(PCIE_MFB_REGIONS*max(1, log2(PCIE_MFB_REGION_SIZE)) -1 downto 0);
        USR_MFB_EOF_POS : out std_logic_vector(PCIE_MFB_REGIONS*max(1, log2(PCIE_MFB_REGION_SIZE*PCIE_MFB_BLOCK_SIZE)) -1 downto 0);
        USR_MFB_SRC_RDY : out std_logic;
        USR_MFB_DST_RDY : in  std_logic;

        -- =========================================================================================
        -- Start/stop interface from the TX_DMA_SW_MANAGER
        -- =========================================================================================
        START_REQ_CHAN : in std_logic_vector(log2(CHANNELS)-1 downto 0);
        START_REQ_VLD  : in  std_logic;
        START_REQ_ACK  : out std_logic;
        STOP_REQ_CHAN  : in  std_logic_vector(log2(CHANNELS)-1 downto 0);
        STOP_REQ_VLD   : in  std_logic;
        STOP_REQ_ACK   : out std_logic;

        -- =========================================================================================
        -- Control signals for the counter of discarded packets
        -- =========================================================================================
        PKT_DISC_CHAN : out std_logic_vector(log2(CHANNELS) -1 downto 0);
        PKT_DISC_INC  : out std_logic;
        PKT_DISC_BYTES : out std_logic_vector(log2(PKT_SIZE_MAX+1) -1 downto 0)
        );
end entity;

architecture FULL of TX_DMA_CHAN_START_STOP_CTRL is

    constant MFB_LENGTH : natural := PCIE_MFB_REGIONS*PCIE_MFB_REGION_SIZE*PCIE_MFB_BLOCK_SIZE*PCIE_MFB_ITEM_WIDTH;

    -- =============================================================================================
    -- Defining ranges for meta signal
    -- =============================================================================================
    constant META_IS_DMA_HDR_W : natural := 1;
    constant META_PCIE_ADDR_W  : natural := 62;
    constant META_CHAN_NUM_W   : natural := log2(CHANNELS);
    constant META_BE_W         : natural := MFB_LENGTH/8;

    constant META_IS_DMA_HDR_O : natural := 0;
    constant META_PCIE_ADDR_O  : natural := META_IS_DMA_HDR_O + META_IS_DMA_HDR_W;
    constant META_CHAN_NUM_O   : natural := META_PCIE_ADDR_O + META_PCIE_ADDR_W;
    constant META_BE_O         : natural := META_CHAN_NUM_O + META_CHAN_NUM_W;

    subtype META_IS_DMA_HDR is natural range META_IS_DMA_HDR_O + META_IS_DMA_HDR_W -1 downto META_IS_DMA_HDR_O;
    subtype META_PCIE_ADDR is natural range META_PCIE_ADDR_O + META_PCIE_ADDR_W -1 downto META_PCIE_ADDR_O;
    subtype META_CHAN_NUM is natural range META_CHAN_NUM_O + META_CHAN_NUM_W -1 downto META_CHAN_NUM_O;
    subtype META_BE is natural range META_BE_O + META_BE_W -1 downto META_BE_O;

    -- =============================================================================================
    -- State machines' states
    -- =============================================================================================
    type channel_active_state_t is (CHANNEL_RUNNING, CHANNEL_START, CHANNEL_STOP_PENDING, CHANNEL_STOPPED);
    type all_chan_active_states_t is array (CHANNELS -1 downto 0) of channel_active_state_t;
    signal channel_active_pst : all_chan_active_states_t := (others => CHANNEL_STOPPED);
    signal channel_active_nst : all_chan_active_states_t := (others => CHANNEL_STOPPED);
    -- MUX inputs to acknowledge start/stop from each channel
    signal chan_start_req_ack : std_logic_vector(CHANNELS -1 downto 0);
    signal chan_stop_req_ack  : std_logic_vector(CHANNELS -1 downto 0);

    type pkt_acc_state_t is (S_IDLE, S_PKT_PENDING, S_PKT_DROP);
    type all_chan_pkt_acc_state_t is array (CHANNELS -1 downto 0) of pkt_acc_state_t;
    signal pkt_acc_pst      : all_chan_pkt_acc_state_t := (others => S_IDLE);
    signal pkt_acc_nst      : all_chan_pkt_acc_state_t := (others => S_IDLE);
    -- drop enable for each channel
    signal chan_pkt_drop_en : slv_array_t(CHANNELS -1 downto 0)(PCIE_MFB_REGIONS -1 downto 0);
    -- MUXed from all channels
    signal pkt_drop_en      : std_logic_vector(PCIE_MFB_REGIONS -1 downto 0);
begin

    -- =============================================================================================
    -- Channel start/stop control
    -- =============================================================================================
    channel_active_fsm_g : for j in (CHANNELS -1) downto 0 generate
        channel_active_state_reg_p : process (CLK) is
        begin
            if (rising_edge(CLK)) then
                if (RESET = '1') then
                    channel_active_pst(j) <= CHANNEL_STOPPED;
                else
                    channel_active_pst(j) <= channel_active_nst(j);
                end if;
            end if;
        end process;

        channel_active_nst_logic_p : process (all) is
        begin
            channel_active_nst(j) <= channel_active_pst(j);
            chan_start_req_ack(j) <= '0';
            chan_stop_req_ack(j)  <= '0';

            case channel_active_pst(j) is
                when CHANNEL_STOPPED =>
                    if (START_REQ_VLD = '1' and j = to_integer(unsigned(START_REQ_CHAN))) then
                        channel_active_nst(j) <= CHANNEL_START;
                    end if;

                when CHANNEL_START =>
                    chan_start_req_ack(j) <= '1';
                    channel_active_nst(j) <= CHANNEL_RUNNING;

                when CHANNEL_RUNNING =>
                    if (STOP_REQ_VLD = '1' and j = to_integer(unsigned(STOP_REQ_CHAN))) then
                        channel_active_nst(j) <= CHANNEL_STOP_PENDING;
                    end if;

                when CHANNEL_STOP_PENDING =>
                    if (pkt_acc_pst(j) = S_IDLE) then
                        chan_stop_req_ack(j)  <= '1';
                        channel_active_nst(j) <= CHANNEL_STOPPED;
                    end if;
            end case;
        end process;
    end generate;

    START_REQ_ACK <= chan_start_req_ack(to_integer(unsigned(START_REQ_CHAN)));
    STOP_REQ_ACK  <= chan_stop_req_ack(to_integer(unsigned(STOP_REQ_CHAN)));

    -- =============================================================================================
    -- Status of a packet processing on all channels
    --
    -- The PKT_PENDING means there are still incoming PCIe transactions for the current packet.
    -- =============================================================================================
    acceptor_fsm_g : for j in (CHANNELS -1) downto 0 generate
        pkt_acceptor_state_reg_p : process (CLK) is
        begin
            if (rising_edge(CLK)) then
                if (RESET = '1') then
                    pkt_acc_pst(j) <= S_IDLE;
                else
                    pkt_acc_pst(j) <= pkt_acc_nst(j);
                end if;
            end if;
        end process;

        pkt_acceptor_nst_logic_p : process (all) is
        begin
            pkt_acc_nst(j)      <= pkt_acc_pst(j);
            chan_pkt_drop_en(j) <= (others => '0');

            case pkt_acc_pst(j) is
                when S_IDLE =>
                    if (
                        PCIE_MFB_SRC_RDY = '1'
                        and PCIE_MFB_SOF = "1"
                        and std_logic_vector(to_unsigned(j, log2(CHANNELS))) = PCIE_MFB_META(META_CHAN_NUM)
                        ) then

                        if (channel_active_pst(j) = CHANNEL_RUNNING) then
                            pkt_acc_nst(j) <= S_PKT_PENDING;
                        else
                            pkt_acc_nst(j)      <= S_PKT_DROP;
                            chan_pkt_drop_en(j) <= (others => '1');
                        end if;
                    end if;

                when S_PKT_PENDING =>
                    if (
                        PCIE_MFB_SRC_RDY = '1'
                        and PCIE_MFB_META(META_IS_DMA_HDR) = "1"
                        and std_logic_vector(to_unsigned(j, log2(CHANNELS))) = PCIE_MFB_META(META_CHAN_NUM)
                        ) then
                        pkt_acc_nst(j) <= S_IDLE;
                    end if;

                when S_PKT_DROP =>
                    if (PCIE_MFB_SRC_RDY = '1'
                        and PCIE_MFB_SOF = "1"
                        and std_logic_vector(to_unsigned(j, log2(CHANNELS))) = PCIE_MFB_META(META_CHAN_NUM)) then
                        chan_pkt_drop_en(j) <= (others => '1');

                        if (PCIE_MFB_META(META_IS_DMA_HDR) = "1") then
                            pkt_acc_nst(j) <= S_IDLE;
                        end if;
                    end if;
            end case;
        end process;
    end generate;

    PKT_DISC_CHAN <= PCIE_MFB_META(META_CHAN_NUM);
    -- choose only packet size from the DMA header
    PKT_DISC_BYTES <= PCIE_MFB_DATA(log2(PKT_SIZE_MAX+1) -1 downto 0);
    PKT_DISC_INC  <= '1' when
                    (
                        pkt_acc_pst(to_integer(unsigned(PCIE_MFB_META(META_CHAN_NUM)))) = S_PKT_DROP
                        and PCIE_MFB_META(META_IS_DMA_HDR) = "1"
                        and PCIE_MFB_SRC_RDY = '1'
                        and PCIE_MFB_DST_RDY = '1')
                    else '0';

    -- =============================================================================================
    -- Packet droping
    --
    -- Meeting specific conditions regarding processing of a current packet and channel active
    -- status will cause every packet on the input to be dropped.
    -- =============================================================================================
    pkt_drop_en <= chan_pkt_drop_en(to_integer(unsigned(PCIE_MFB_META(META_CHAN_NUM))));

    pkt_dropper_i : entity work.MFB_DROPPER
        generic map (
            REGIONS     => PCIE_MFB_REGIONS,
            REGION_SIZE => PCIE_MFB_REGION_SIZE,
            BLOCK_SIZE  => PCIE_MFB_BLOCK_SIZE,
            ITEM_WIDTH  => PCIE_MFB_ITEM_WIDTH,
            META_WIDTH  => PCIE_MFB_META'length)
        port map (
            CLK   => CLK,
            RESET => RESET,

            RX_DATA    => PCIE_MFB_DATA,
            RX_META    => PCIE_MFB_META,
            RX_SOF_POS => PCIE_MFB_SOF_POS,
            RX_EOF_POS => PCIE_MFB_EOF_POS,
            RX_SOF     => PCIE_MFB_SOF,
            RX_EOF     => PCIE_MFB_EOF,
            RX_SRC_RDY => PCIE_MFB_SRC_RDY,
            RX_DST_RDY => PCIE_MFB_DST_RDY,
            RX_DROP    => pkt_drop_en,

            TX_DATA    => USR_MFB_DATA,
            TX_META    => USR_MFB_META,
            TX_SOF_POS => USR_MFB_SOF_POS,
            TX_EOF_POS => USR_MFB_EOF_POS,
            TX_SOF     => USR_MFB_SOF,
            TX_EOF     => USR_MFB_EOF,
            TX_SRC_RDY => USR_MFB_SRC_RDY,
            TX_DST_RDY => USR_MFB_DST_RDY);
end architecture;
