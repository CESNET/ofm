-- tx_dma_pkt_dispatchervhd: this component dispatches the DMA frames from buffers to the user logic
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
use work.dma_hdr_pkg.all;

-- This component dispatches the frames from data buffers accoring to available DMA Headers. Frames
-- are dispatched from all channels in order in which DMA headers did come from the PCI Express.
-- After dispatching a frame, the component issues an update of header and data pointers. If a channel
-- is already stopped and DMA header for this channel occurs on the input of this component, this
-- DMA header is dropped and no frame data are dispatched to the output as well as no update of
-- pointers is issued.
entity TX_DMA_PKT_DISPATCHER is
    generic (
        DEVICE : string := "ULTRASCALE";

        CHANNELS       : natural := 8;
        HDR_META_WIDTH : natural := 24;
        PKT_SIZE_MAX   : natural := 2**16 -1;

        MFB_REGIONS     : natural := 1;
        MFB_REGION_SIZE : natural := 1;
        MFB_BLOCK_SIZE  : natural := 8;
        MFB_ITEM_WIDTH  : natural := 32;

        DATA_POINTER_WIDTH    : natural := 16;
        DMA_HDR_POINTER_WIDTH : natural := 9);
    port (
        CLK   : in std_logic;
        RESET : in std_logic;

        -- =========================================================================================
        -- Outuput MFB interface to user logic
        -- =========================================================================================
        USR_MFB_META_HDR_META : out std_logic_vector(HDR_META_WIDTH -1 downto 0);
        USR_MFB_META_CHAN     : out std_logic_vector(log2(CHANNELS) -1 downto 0);
        USR_MFB_META_PKT_SIZE : out std_logic_vector(log2(PKT_SIZE_MAX+1) -1 downto 0);

        USR_MFB_DATA    : out std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
        USR_MFB_SOF     : out std_logic_vector(MFB_REGIONS -1 downto 0);
        USR_MFB_EOF     : out std_logic_vector(MFB_REGIONS -1 downto 0);
        USR_MFB_SOF_POS : out std_logic_vector(MFB_REGIONS*max(1, log2(MFB_REGION_SIZE)) -1 downto 0);
        USR_MFB_EOF_POS : out std_logic_vector(MFB_REGIONS*max(1, log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE)) -1 downto 0);
        USR_MFB_SRC_RDY : out std_logic;
        USR_MFB_DST_RDY : in  std_logic;

        -- =========================================================================================
        -- Input interface from header buffer
        -- =========================================================================================
        -- This is not an address for reading interface of the buffer, but the addres on which the
        -- current header has been written.
        HDR_BUFF_ADDR    : in  std_logic_vector(62 -1 downto 0);
        HDR_BUFF_CHAN    : in  std_logic_vector(log2(CHANNELS) -1 downto 0);
        HDR_BUFF_DATA    : in  std_logic_vector(DMA_HDR_WIDTH -1 downto 0);
        HDR_BUFF_SRC_RDY : in  std_logic;
        HDR_BUFF_DST_RDY : out std_logic;

        -- =========================================================================================
        -- Reading interface to the data buffer
        -- =========================================================================================
        BUFF_RD_CHAN : out std_logic_vector(log2(CHANNELS) -1 downto 0);
        BUFF_RD_DATA : in  std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
        BUFF_RD_ADDR : out std_logic_vector(DATA_POINTER_WIDTH -1 downto 0);
        BUFF_RD_EN   : out std_logic;

        -- =========================================================================================
        -- Interface to the software manager
        --
        -- For pointer update and incrementing of packet counter.
        -- =========================================================================================
        PKT_SENT_CHAN  : out std_logic_vector(log2(CHANNELS) -1 downto 0);
        PKT_SENT_INC   : out std_logic;
        PKT_SENT_BYTES : out std_logic_vector(log2(PKT_SIZE_MAX+1) -1 downto 0);

        ENABLED_CHANS : in std_logic_vector(CHANNELS -1 downto 0);

        UPD_HDP_CHAN : out std_logic_vector(log2(CHANNELS) -1 downto 0);
        UPD_HDP_DATA : out std_logic_vector(DATA_POINTER_WIDTH -1 downto 0);
        UPD_HDP_EN   : out std_logic;

        UPD_HHP_CHAN : out std_logic_vector(log2(CHANNELS) -1 downto 0);
        UPD_HHP_DATA : out std_logic_vector(DMA_HDR_POINTER_WIDTH -1 downto 0);
        UPD_HHP_EN   : out std_logic
        );
end entity;

architecture FULL of TX_DMA_PKT_DISPATCHER is
    signal addr_cntr_pst : unsigned(BUFF_RD_ADDR'range);
    signal addr_cntr_nst : unsigned(BUFF_RD_ADDR'range);

    signal byte_cntr_pst : unsigned(log2(PKT_SIZE_MAX+1) -1 downto 0);
    signal byte_cntr_nst : unsigned(log2(PKT_SIZE_MAX+1) -1 downto 0);

    type pkt_dispatch_state_t is (S_IDLE, S_PKT_MIDDLE, S_UPDATE_STATUS);
    signal pkt_dispatch_pst : pkt_dispatch_state_t := S_IDLE;
    signal pkt_dispatch_nst : pkt_dispatch_state_t := S_IDLE;

    signal disp_fsm_mfb_sof     : std_logic_vector(USR_MFB_SOF'range);
    signal disp_fsm_mfb_eof     : std_logic_vector(USR_MFB_EOF'range);
    signal disp_fsm_mfb_eof_pos : std_logic_vector(USR_MFB_EOF_POS'range);
    signal disp_fsm_mfb_src_rdy : std_logic;
    signal mfb_dst_rdy_reg      : std_logic;
    signal buff_rd_data_reg     : std_logic_vector(BUFF_RD_DATA'range);
begin

    pkt_dispatch_fsm_reg_p : process (CLK) is
    begin
        if (rising_edge(CLK)) then
            if (RESET = '1') then
                pkt_dispatch_pst <= S_IDLE;
                addr_cntr_pst    <= (others => '0');
                byte_cntr_pst    <= (others => '0');
            elsif (USR_MFB_DST_RDY = '1') then
                pkt_dispatch_pst <= pkt_dispatch_nst;
                addr_cntr_pst    <= addr_cntr_nst;
                byte_cntr_pst    <= byte_cntr_nst;
            end if;
        end if;
    end process;

    pkt_dispatch_fsm_nst_logic_p : process (all) is
        variable dma_hdr_frame_ptr_v    : unsigned(DMA_FRAME_PTR_W -1 downto 0);
        variable dma_hdr_frame_length_v : unsigned(DMA_FRAME_LENGTH_W -1 downto 0);
    begin
        pkt_dispatch_nst <= pkt_dispatch_pst;

        dma_hdr_frame_ptr_v    := unsigned(HDR_BUFF_DATA(DMA_FRAME_PTR));
        dma_hdr_frame_length_v := unsigned(HDR_BUFF_DATA(DMA_FRAME_LENGTH));

        case pkt_dispatch_pst is
            when S_IDLE =>
                if (HDR_BUFF_SRC_RDY = '1' and ENABLED_CHANS(to_integer(unsigned(HDR_BUFF_CHAN))) = '1') then
                    if (dma_hdr_frame_length_v > (USR_MFB_DATA'length /8)) then
                        pkt_dispatch_nst <= S_PKT_MIDDLE;
                    else
                        pkt_dispatch_nst <= S_UPDATE_STATUS;
                    end if;
                end if;

            when S_PKT_MIDDLE =>
                if (byte_cntr_pst <= (USR_MFB_DATA'length /8)) then
                    pkt_dispatch_nst <= S_UPDATE_STATUS;
                end if;
            when S_UPDATE_STATUS =>
                pkt_dispatch_nst <= S_IDLE;
        end case;
    end process;

    pkt_dispatch_fsm_output_logic_p : process (all) is
        variable dma_hdr_frame_ptr_v    : unsigned(DMA_FRAME_PTR_W -1 downto 0);
        variable dma_hdr_frame_length_v : unsigned(DMA_FRAME_LENGTH_W -1 downto 0);
    begin
        addr_cntr_nst <= addr_cntr_pst;
        byte_cntr_nst <= byte_cntr_pst;

        disp_fsm_mfb_sof     <= (others => '0');
        disp_fsm_mfb_eof     <= (others => '0');
        disp_fsm_mfb_eof_pos <= (others => '0');
        disp_fsm_mfb_src_rdy <= '0';

        HDR_BUFF_DST_RDY <= '0';

        BUFF_RD_ADDR <= std_logic_vector(addr_cntr_pst);
        BUFF_RD_EN   <= '0';

        PKT_SENT_INC <= '0';
        UPD_HDP_EN   <= '0';
        UPD_HHP_EN   <= '0';

        dma_hdr_frame_ptr_v    := unsigned(HDR_BUFF_DATA(DMA_FRAME_PTR));
        dma_hdr_frame_length_v := unsigned(HDR_BUFF_DATA(DMA_FRAME_LENGTH));

        case pkt_dispatch_pst is
            when S_IDLE =>

                if (HDR_BUFF_SRC_RDY = '1') then
                    if (ENABLED_CHANS(to_integer(unsigned(HDR_BUFF_CHAN))) = '0') then
                        HDR_BUFF_DST_RDY <= USR_MFB_DST_RDY;
                    else
                        disp_fsm_mfb_sof     <= "1";
                        disp_fsm_mfb_src_rdy <= '1';

                        BUFF_RD_ADDR <= std_logic_vector(dma_hdr_frame_ptr_v(BUFF_RD_ADDR'range));
                        BUFF_RD_EN   <= '1';

                        -- When the packet, according to its length, fits in the output word, then
                        -- assign EOF and do not count next address for the reading.
                        if (dma_hdr_frame_length_v <= (USR_MFB_DATA'length /8)) then
                            addr_cntr_nst        <= dma_hdr_frame_ptr_v(BUFF_RD_ADDR'range);
                            disp_fsm_mfb_eof     <= "1";
                            -- take only the lower bits from the frame length
                            disp_fsm_mfb_eof_pos <= std_logic_vector(dma_hdr_frame_length_v(USR_MFB_EOF_POS'range) - 1);
                        else
                            addr_cntr_nst <= dma_hdr_frame_ptr_v(BUFF_RD_ADDR'range) + (USR_MFB_DATA'length /8);
                            byte_cntr_nst <= resize(dma_hdr_frame_length_v, byte_cntr_nst'length) - (USR_MFB_DATA'length /8);
                        end if;
                    end if;
                end if;

            when S_PKT_MIDDLE =>

                addr_cntr_nst        <= addr_cntr_pst + (USR_MFB_DATA'length /8);
                byte_cntr_nst        <= byte_cntr_pst - (USR_MFB_DATA'length /8);
                disp_fsm_mfb_src_rdy <= '1';
                BUFF_RD_EN           <= '1';

                if (byte_cntr_pst <= (USR_MFB_DATA'length /8)) then
                    disp_fsm_mfb_eof     <= "1";
                    disp_fsm_mfb_eof_pos <= std_logic_vector(dma_hdr_frame_length_v(USR_MFB_EOF_POS'range) - 1);
                end if;

            when S_UPDATE_STATUS =>
                HDR_BUFF_DST_RDY <= USR_MFB_DST_RDY;
                PKT_SENT_INC     <= USR_MFB_DST_RDY;
                UPD_HDP_EN       <= USR_MFB_DST_RDY;
                UPD_HHP_EN       <= USR_MFB_DST_RDY;
        end case;
    end process;

    BUFF_RD_CHAN <= HDR_BUFF_CHAN;

    PKT_SENT_CHAN  <= HDR_BUFF_CHAN;
    PKT_SENT_BYTES <= HDR_BUFF_DATA(DMA_FRAME_LENGTH)(PKT_SENT_BYTES'range);

    UPD_HDP_CHAN <= HDR_BUFF_CHAN;
    UPD_HDP_DATA <= std_logic_vector(resize(unsigned(HDR_BUFF_DATA(DMA_FRAME_LENGTH)) + unsigned(HDR_BUFF_DATA(DMA_FRAME_PTR)), DATA_POINTER_WIDTH));
    UPD_HHP_CHAN <= HDR_BUFF_CHAN;
    UPD_HHP_DATA <= std_logic_vector(resize((unsigned(HDR_BUFF_ADDR) & "00"), DMA_HDR_POINTER_WIDTH) + 8);

    -- This process delays the set of all output MFB signals because the data come from the data
    -- buffer one clock cycle after the address and enable signal have been set.
    out_delay_reg_p : process (CLK) is
    begin
        if (rising_edge(CLK)) then
            if (RESET = '1') then
                USR_MFB_SOF     <= (others => '0');
                USR_MFB_EOF     <= (others => '0');
                USR_MFB_EOF_POS <= (others => '0');
                USR_MFB_SRC_RDY <= '0';
            elsif (USR_MFB_DST_RDY = '1') then
                USR_MFB_SOF     <= disp_fsm_mfb_sof;
                USR_MFB_EOF     <= disp_fsm_mfb_eof;
                USR_MFB_EOF_POS <= disp_fsm_mfb_eof_pos;
                USR_MFB_SRC_RDY <= disp_fsm_mfb_src_rdy;
            end if;
        end if;
    end process;

    USR_MFB_META_HDR_META <= HDR_BUFF_DATA(DMA_USR_METADATA);
    USR_MFB_META_CHAN     <= HDR_BUFF_CHAN;
    USR_MFB_META_PKT_SIZE <= HDR_BUFF_DATA(DMA_FRAME_LENGTH)(USR_MFB_META_PKT_SIZE'range);

    USR_MFB_DATA    <= BUFF_RD_DATA when mfb_dst_rdy_reg = '1' else buff_rd_data_reg;
    USR_MFB_SOF_POS <= (others => '0');

    mfb_dst_rdy_reg_p : process (CLK) is
    begin
        if (rising_edge(CLK)) then
            mfb_dst_rdy_reg <= USR_MFB_DST_RDY;
        end if;
    end process;

    buff_rd_data_reg_p : process (CLK) is
    begin
        if (rising_edge(CLK)) then
            if (RESET = '1') then
                buff_rd_data_reg <= (others => '0');
            elsif (mfb_dst_rdy_reg = '1') then
                buff_rd_data_reg <= BUFF_RD_DATA;
            end if;
        end if;
    end process;
end architecture;
