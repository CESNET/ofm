-- Copyright (C) 2023 CESNET z. s. p. o.
-- Author(s): Daniel Kondys <kondys@cesnet.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.math_pack.all;
use work.type_pack.all;


-- =========================================================================
--  Description
-- =========================================================================

-- Incoming packets with Timestamps [ns] are stored in the RX FIFO, from which they are read when the Time Counter value reaches the Timestamp value.
-- There are 2 Timestamp formats that are currently supported (see the :vhdl:genconstant:`TS_FORMAT <mfb_packet_delayer.ts_format>` generic).
-- The packets read from the RX FIFO are stored in the TX FIFO.
-- The read logic of the RX FIFO is very simplified and not made for high efficiency and it's been tested for MFB_REGIONS=1 only.
--
entity MFB_PACKET_DELAYER is
generic(
    -- Number of Regions within a data word, must be power of 2.
    MFB_REGIONS           : natural := 1;
    -- Region size (in Blocks).
    MFB_REGION_SIZE       : natural := 8;
    -- Block size (in Items), must be 8.
    MFB_BLOCK_SIZE        : natural := 8;
    -- Item width (in bits), must be 8.
    MFB_ITEM_WIDTH        : natural := 8;
    -- Metadata width (in bits).
    MFB_META_WIDTH        : natural := 0;

    -- Freq of the CLK signal (in Hz).
    CLK_FREQUENCY         : natural := 200000000;
    -- Width of Timestamps (in bits).
    TS_WIDTH              : natural := 48;
    -- Format of Timestamps. Options:
    --
    -- - ``0`` number of NS between individual packets,
    -- - ``1`` number of NS from RESET.
    TS_FORMAT             : natural := 0;
    -- Number of Items in the Input packet FIFOX_MULTI (main buffer).
    FIFO_DEPTH            : natural := 2048;

    -- FPGA device name: ULTRASCALE, STRATIX10, AGILEX, ...
    DEVICE                : string := "STRATIX10"
);
port(
    -- =====================================================================
    --  Clock and Reset
    -- =====================================================================

    CLK            : in  std_logic;
    RESET          : in  std_logic;

    -- Reset current time (applies only when TS_FORMAT=1).
    -- Time counter is reset with the next first SOF.
    TIME_RESET     : in  std_logic;

    -- Input Time used to decide whether a packet's Timestamp is OK or not.
    CURRENT_TIME   : in  std_logic_vector(64-1 downto 0);

    -- =====================================================================
    --  RX inf
    -- =====================================================================

    RX_MFB_DATA    : in  std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
    -- Valid with SOF.
    RX_MFB_META    : in  std_logic_vector(MFB_REGIONS*MFB_META_WIDTH-1 downto 0) := (others => '0');
    -- Timestamp valid with each SOF.
    RX_MFB_TS      : in  std_logic_vector(MFB_REGIONS*TS_WIDTH-1 downto 0) := (others => '0');
    RX_MFB_SOF_POS : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    RX_MFB_EOF_POS : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    RX_MFB_SOF     : in  std_logic_vector(MFB_REGIONS-1 downto 0);
    RX_MFB_EOF     : in  std_logic_vector(MFB_REGIONS-1 downto 0);
    RX_MFB_SRC_RDY : in  std_logic;
    RX_MFB_DST_RDY : out std_logic;
    
    -- =====================================================================
    --  TX inf
    -- =====================================================================

    TX_MFB_DATA    : out std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
    -- Valid with SOF.
    TX_MFB_META    : out std_logic_vector(MFB_REGIONS*MFB_META_WIDTH-1 downto 0);
    TX_MFB_SOF_POS : out std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    TX_MFB_EOF_POS : out std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    TX_MFB_SOF     : out std_logic_vector(MFB_REGIONS-1 downto 0);
    TX_MFB_EOF     : out std_logic_vector(MFB_REGIONS-1 downto 0);
    TX_MFB_SRC_RDY : out std_logic;
    TX_MFB_DST_RDY : in  std_logic
);
end entity;

architecture FULL of MFB_PACKET_DELAYER is

    subtype my_integer is integer range MFB_REGION_SIZE-1 downto 0;
    type my_integer_vector is array(natural range <>) of my_integer;

    -- ========================================================================
    --                                CONSTANTS
    -- ========================================================================

    constant WORD_WIDTH    : natural := MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH;
    constant REGION_WIDTH  : natural := WORD_WIDTH/MFB_REGIONS;
    constant WORD_BLOCKS   : natural := MFB_REGIONS*MFB_REGION_SIZE;
    constant BLOCK_WIDTH   : natural := WORD_WIDTH/WORD_BLOCKS;
    constant SOF_POS_WIDTH : natural := max(1,log2(MFB_REGION_SIZE));
    constant EOF_POS_WIDTH : natural := max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE));

    --                                       Data        + Meta           + Timestamps + SOFs and EOFs + EOF POS (only Items)
    constant RX_FIFO_DATA_WIDTH : natural := BLOCK_WIDTH + MFB_META_WIDTH + TS_WIDTH   + 2             + max(1,log2(MFB_BLOCK_SIZE));
    -- Clock period in nanoseconds
    constant CLK_PERIOD         : natural := integer(real(1)/real(CLK_FREQUENCY)*real(10**9));
    -- Counter increment (in ns)
    constant TIME_CNT_INC       : std_logic_vector := std_logic_vector(to_unsigned(CLK_PERIOD, log2(CLK_PERIOD)));

    -- ========================================================================
    --                                 SIGNALS
    -- ========================================================================

    signal rx_mfb_data_arr              : slv_array_t(WORD_BLOCKS-1 downto 0)(BLOCK_WIDTH-1 downto 0);
    signal rx_mfb_meta_regions_arr      : slv_array_t(MFB_REGIONS-1 downto 0)(MFB_META_WIDTH-1 downto 0);
    signal rx_mfb_meta_blocks_arr       : slv_array_t(WORD_BLOCKS-1 downto 0)(MFB_META_WIDTH-1 downto 0);
    signal rx_mfb_ts_regions_arr        : slv_array_t(MFB_REGIONS-1 downto 0)(TS_WIDTH-1 downto 0);
    signal rx_mfb_ts_blocks_arr         : slv_array_t(WORD_BLOCKS-1 downto 0)(TS_WIDTH-1 downto 0);
    signal rx_mfb_sof_pos_arr           : slv_array_t(MFB_REGIONS-1 downto 0)(SOF_POS_WIDTH-1 downto 0);
    signal rx_mfb_eof_pos_arr           : slv_array_t(MFB_REGIONS-1 downto 0)(EOF_POS_WIDTH-1 downto 0);

    signal rx_fifoxm_in_sof_onehot      : slv_array_t   (MFB_REGIONS-1 downto 0)(MFB_REGION_SIZE-1 downto 0);
    signal rx_fifoxm_in_eof_onehot      : slv_array_t   (MFB_REGIONS-1 downto 0)(MFB_REGION_SIZE-1 downto 0);
    signal rx_fifoxm_in_eof_pos_items   : slv_array_2d_t(MFB_REGIONS-1 downto 0)(MFB_REGION_SIZE-1 downto 0)(max(1,log2(MFB_BLOCK_SIZE))-1 downto 0);

    signal rx_mfb_sof_ser               : std_logic_vector(WORD_BLOCKS-1 downto 0);
    signal rx_mfb_eof_ser               : std_logic_vector(WORD_BLOCKS-1 downto 0);
    signal rx_mfb_eof_pos_ser           : std_logic_vector(WORD_BLOCKS*            max(1,log2(MFB_BLOCK_SIZE))-1 downto 0);
    signal rx_mfb_eof_pos_blocks_arr    : slv_array_t     (WORD_BLOCKS-1 downto 0)(max(1,log2(MFB_BLOCK_SIZE))-1 downto 0);

    signal rx_fifoxm_din_arr            : slv_array_t      (WORD_BLOCKS-1 downto 0)(RX_FIFO_DATA_WIDTH-1 downto 0);
    signal rx_fifoxm_din                : std_logic_vector (WORD_BLOCKS*            RX_FIFO_DATA_WIDTH-1 downto 0);
    signal rx_mfb_pkt_cont              : std_logic_vector (MFB_REGIONS downto 0);
    signal rx_mfb_sof_pos_ptr           : my_integer_vector(MFB_REGIONS-1 downto 0);
    signal rx_mfb_eof_pos_ptr           : my_integer_vector(MFB_REGIONS-1 downto 0);
    signal rx_mfb_blocks_to_write       : slv_array_t      (MFB_REGIONS-1 downto 0)(MFB_REGION_SIZE-1 downto 0);
    signal rx_fifoxm_wr                 : std_logic_vector (WORD_BLOCKS-1 downto 0);
    signal rx_fifoxm_full               : std_logic;

    signal rx_fifoxm_dout               : std_logic_vector(WORD_BLOCKS*RX_FIFO_DATA_WIDTH-1 downto 0);
    signal rx_fifoxm_rd                 : std_logic_vector(WORD_BLOCKS-1 downto 0);
    signal rx_fifoxm_empty              : std_logic_vector(WORD_BLOCKS-1 downto 0);

    signal rx_fifoxm_dout_arr           : slv_array_t     (WORD_BLOCKS-1 downto 0)(RX_FIFO_DATA_WIDTH-1 downto 0);
    signal rx_fifoxm_out_data           : slv_array_t     (WORD_BLOCKS-1 downto 0)(BLOCK_WIDTH-1 downto 0);
    signal rx_fifoxm_out_meta_blocks    : slv_array_t     (WORD_BLOCKS-1 downto 0)(MFB_META_WIDTH-1 downto 0);
    signal rx_fifoxm_out_ts_blocks      : slv_array_t     (WORD_BLOCKS-1 downto 0)(TS_WIDTH-1 downto 0);
    signal rx_fifoxm_out_sof_onehot     : std_logic_vector(WORD_BLOCKS-1 downto 0);
    signal rx_fifoxm_out_eof_onehot     : std_logic_vector(WORD_BLOCKS-1 downto 0);
    signal rx_fifoxm_out_eof_pos_items  : slv_array_t     (WORD_BLOCKS-1 downto 0)(max(1,log2(MFB_BLOCK_SIZE))-1 downto 0);

    signal rx_fifoxm_out_sof_onehot_vld : std_logic_vector(WORD_BLOCKS-1 downto 0);
    signal rx_fifoxm_out_eof_onehot_vld : std_logic_vector(WORD_BLOCKS-1 downto 0);

    signal sof_onehot_region            : slv_array_t(MFB_REGIONS-1 downto 0)(MFB_REGION_SIZE-1 downto 0);
    signal eof_onehot_region            : slv_array_t(MFB_REGIONS-1 downto 0)(MFB_REGION_SIZE-1 downto 0);

    signal sof                          : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal sof_pos_region               : slv_array_t     (MFB_REGIONS-1 downto 0)(SOF_POS_WIDTH-1 downto 0);
    signal eof                          : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal eof_pos_blocks_region        : slv_array_t     (MFB_REGIONS-1 downto 0)(SOF_POS_WIDTH-1 downto 0);
    signal eof_pos_items_region         : slv_array_t     (MFB_REGIONS-1 downto 0)(max(1,log2(MFB_BLOCK_SIZE))-1 downto 0);
    signal eof_pos_region               : slv_array_t     (MFB_REGIONS-1 downto 0)(EOF_POS_WIDTH-1 downto 0);

    signal rx_fifoxm_out_meta_regions   : slv_array_t     (MFB_REGIONS-1 downto 0)(MFB_META_WIDTH-1 downto 0);
    signal rx_fifoxm_out_ts_regions     : u_array_t       (MFB_REGIONS-1 downto 0)(TS_WIDTH-1 downto 0);
    signal ts_ok                        : std_logic_vector(MFB_REGIONS-1 downto 0);

    signal sof_rd_vec                   : std_logic_vector(WORD_BLOCKS-1 downto 0);
    signal eof_rd_vec                   : std_logic_vector(WORD_BLOCKS-1 downto 0);
    signal eof_rd_vec_en                : std_logic;

    signal cont_rd                      : std_logic;
    signal blocks_to_read               : slv_array_t      (MFB_REGIONS-1 downto 0)(MFB_REGION_SIZE-1 downto 0);
    signal sof_pos_ptr                  : my_integer_vector(MFB_REGIONS-1 downto 0);

    signal sof_read                     : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal first_sof_read               : std_logic;
    signal waiting_for_first_sof        : std_logic;
    signal update_stored_time           : std_logic;
    signal current_time_reg             : unsigned(64-1 downto 0);
    signal one_clk_period_time_diff     : unsigned                         (TS_WIDTH-1 downto 0);
    signal accum_time_diff              : unsigned                         (TS_WIDTH-1 downto 0);
    signal stored_time_diff             : unsigned                         (TS_WIDTH-1 downto 0);
    signal stored_time_diff_fixed       : u_array_t(MFB_REGIONS-1 downto 0)(TS_WIDTH-1 downto 0);

    signal mfb_data_mid_reg             : std_logic_vector(WORD_WIDTH-1 downto 0);
    signal mfb_meta_mid_reg             : std_logic_vector(MFB_REGIONS*MFB_META_WIDTH-1 downto 0);
    signal mfb_sof_pos_mid_reg          : std_logic_vector(MFB_REGIONS*SOF_POS_WIDTH-1 downto 0);
    signal mfb_eof_pos_mid_reg          : std_logic_vector(MFB_REGIONS*EOF_POS_WIDTH-1 downto 0);
    signal mfb_sof_mid_reg              : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal mfb_eof_mid_reg              : std_logic_vector(MFB_REGIONS-1 downto 0);
    signal mfb_src_rdy_mid_reg          : std_logic;
    signal mfb_dst_rdy_mid_reg          : std_logic;

begin

    RX_MFB_DST_RDY <= not rx_fifoxm_full;

    -- ========================================================================
    -- RX data preparation
    -- ========================================================================

    rx_mfb_data_arr         <= slv_array_deser(RX_MFB_DATA   , WORD_BLOCKS);
    rx_mfb_meta_regions_arr <= slv_array_deser(RX_MFB_META   , MFB_REGIONS);
    rx_mfb_ts_regions_arr   <= slv_array_deser(RX_MFB_TS     , MFB_REGIONS);
    rx_mfb_sof_pos_arr      <= slv_array_deser(RX_MFB_SOF_POS, MFB_REGIONS);
    rx_mfb_eof_pos_arr      <= slv_array_deser(RX_MFB_EOF_POS, MFB_REGIONS);

    -- -----------------------------------
    --  Convert Metadata and TS to Blocks
    -- -----------------------------------
    meta_and_ts_blocks_p : process(all)
    begin
        rx_mfb_meta_blocks_arr <= (others => (others => '0'));
        rx_mfb_ts_blocks_arr   <= (others => (others => '0'));

        for r in 0 to MFB_REGIONS-1 loop
            rx_mfb_sof_pos_ptr(r) <= to_integer(unsigned(rx_mfb_sof_pos_arr(r)));
            rx_mfb_eof_pos_ptr(r) <= to_integer(unsigned(rx_mfb_eof_pos_arr(r)(EOF_POS_WIDTH-1 downto log2(MFB_BLOCK_SIZE)))); -- Points to a Block with EOF

            rx_mfb_meta_blocks_arr(r*MFB_REGION_SIZE+rx_mfb_sof_pos_ptr(r)) <= rx_mfb_meta_regions_arr(r);
            rx_mfb_ts_blocks_arr  (r*MFB_REGION_SIZE+rx_mfb_sof_pos_ptr(r)) <= rx_mfb_ts_regions_arr  (r);
        end loop;
    end process;

    -- ----------------------------------------------------------------------
    --  Convert SOF, SOF POS, EOF, and EOF POS from Regional to Block effect
    -- ----------------------------------------------------------------------
    sof_eof_p : process(all)
    begin
        rx_fifoxm_in_sof_onehot    <= (others => (others => '0'));
        rx_fifoxm_in_eof_onehot    <= (others => (others => '0'));
        rx_fifoxm_in_eof_pos_items <= (others => (others => (others => '0')));
        for r in 0 to MFB_REGIONS-1 loop
            -- SOF, SOF POS
            -- Just a simple conversion to one-hot format
            if (RX_MFB_SOF(r) = '1') and (RX_MFB_SRC_RDY = '1') then
                for b in 0 to MFB_REGION_SIZE-1 loop
                    if (b = unsigned(rx_mfb_sof_pos_arr(r))) then
                        rx_fifoxm_in_sof_onehot(r)(b) <= '1';
                    end if;
                end loop;
            end if;
            -- EOF, EOF POS
            -- Split EOF POS into 2 parts: MSBs identify the Block, LSBs identify the Item.
            -- Then convert the MSBs part into one-hot (like SOF).
            if (RX_MFB_EOF(r) = '1') and (RX_MFB_SRC_RDY = '1') then
                for b in 0 to MFB_REGION_SIZE-1 loop
                    if (b = unsigned(rx_mfb_eof_pos_arr(r)(EOF_POS_WIDTH-1 downto log2(MFB_BLOCK_SIZE)))) then
                        rx_fifoxm_in_eof_onehot   (r)(b) <= '1'; -- valid for the rx_fifoxm_in_eof_pos_items signal
                        rx_fifoxm_in_eof_pos_items(r)(b) <= rx_mfb_eof_pos_arr(r)(log2(MFB_BLOCK_SIZE)-1 downto 0);
                    end if;
                end loop;
            end if;
        end loop;
    end process;

    rx_mfb_sof_ser <= slv_array_ser(rx_fifoxm_in_sof_onehot); -- SOF on Blocks instead of Regions, therefore also indicates SOF POS
    rx_mfb_eof_ser <= slv_array_ser(rx_fifoxm_in_eof_onehot); -- EOF on Blocks instead of Regions, therefore also indicates a part of EOF POS
    rx_mfb_eof_pos_ser        <= slv_array_2d_ser(rx_fifoxm_in_eof_pos_items); -- only the Item id of the EOF POS (instead of Block&Item id)
    rx_mfb_eof_pos_blocks_arr <= slv_array_deser(rx_mfb_eof_pos_ser, WORD_BLOCKS);

    -- ========================================================================
    -- RX FIFO
    -- ========================================================================

    -- ---------------
    --  RX FIFO input
    -- ---------------
    -- Data
    rx_fifoxm_in_g : for b in 0 to WORD_BLOCKS-1 generate
        rx_fifoxm_din_arr(b) <= rx_mfb_data_arr          (b) &
                                rx_mfb_meta_blocks_arr   (b) &
                                rx_mfb_ts_blocks_arr     (b) &
                                rx_mfb_sof_ser           (b) &
                                rx_mfb_eof_ser           (b) &
                                rx_mfb_eof_pos_blocks_arr(b);
    end generate;
    rx_fifoxm_din <= slv_array_ser(rx_fifoxm_din_arr);

    -- Write
    rx_mfb_pkt_cont_g : for r in 0 to MFB_REGIONS-1 generate 
        rx_mfb_pkt_cont(r+1) <= (    RX_MFB_SOF(r) and not RX_MFB_EOF(r) and not rx_mfb_pkt_cont(r)) or
                                (    RX_MFB_SOF(r) and     RX_MFB_EOF(r) and     rx_mfb_pkt_cont(r)) or
                                (not RX_MFB_SOF(r) and not RX_MFB_EOF(r) and     rx_mfb_pkt_cont(r));
    end generate;
    
    process(CLK)
    begin
        if (rising_edge(CLK)) then
            if (RESET = '1') then
                rx_mfb_pkt_cont(0) <= '0';
            elsif (RX_MFB_SRC_RDY = '1' and RX_MFB_DST_RDY = '1') then
                rx_mfb_pkt_cont(0) <= rx_mfb_pkt_cont(MFB_REGIONS);
            end if;
        end if;
    end process;

    rx_mfb_blocks_to_write_p : process(all)
    begin
        rx_mfb_blocks_to_write <= (others => (others => '0'));
        for r in 0 to MFB_REGIONS-1 loop
            if ((RX_MFB_SOF(r) = '1') and (RX_MFB_EOF(r) = '1')) then
                if (rx_mfb_pkt_cont(r) = '1') then
                    -- inverted approach: make a '1's vector and overwrite it with '0's between SOF and EOF
                    rx_mfb_blocks_to_write(r) <= (others => '1');
                    rx_mfb_blocks_to_write(r)(rx_mfb_sof_pos_ptr(r)-1 downto rx_mfb_eof_pos_ptr(r)+1) <= (others => '0');
                else
                    -- overwrite the '0's vector and with '1's between SOF and EOF
                    rx_mfb_blocks_to_write(r)(rx_mfb_eof_pos_ptr(r) downto rx_mfb_sof_pos_ptr(r)) <= (others => '1');
                end if;
            elsif ((RX_MFB_SOF(r) = '1') and (RX_MFB_EOF(r) = '0')) then
                -- overwrite the '0's vector and with '1's between MSB and SOF
                rx_mfb_blocks_to_write(r)(MFB_REGION_SIZE-1 downto rx_mfb_sof_pos_ptr(r)) <= (others => '1');
            elsif ((RX_MFB_SOF(r) = '0') and (RX_MFB_EOF(r) = '1')) then
                -- overwrite the '0's vector and with '1's between 0 and EOF
                rx_mfb_blocks_to_write(r)(rx_mfb_eof_pos_ptr(r) downto 0) <= (others => '1');
            elsif (rx_mfb_pkt_cont(r) = '1') then
                -- overwrite the '0's vector and with '1's
                rx_mfb_blocks_to_write(r) <= (others => '1');
            end if;
        end loop;
    end process;

    rx_fifoxm_wr <= slv_array_ser(rx_mfb_blocks_to_write) and RX_MFB_SRC_RDY;

    -- ----------------
    --  RX FIFOX Multi
    -- ----------------
    rx_fifoxm_i : entity work.FIFOX_MULTI
    generic map(
        DATA_WIDTH          => RX_FIFO_DATA_WIDTH,
        ITEMS               => FIFO_DEPTH        ,
        WRITE_PORTS         => WORD_BLOCKS       ,
        READ_PORTS          => WORD_BLOCKS       ,
        RAM_TYPE            => "AUTO"            ,
        DEVICE              => DEVICE            ,
        ALMOST_FULL_OFFSET  => 0                 ,
        ALMOST_EMPTY_OFFSET => 0                 ,
        ALLOW_SINGLE_FIFO   => True              ,
        SAFE_READ_MODE      => False
    )
    port map(
        CLK   => CLK,
        RESET => RESET,

        DI     => rx_fifoxm_din  ,
        WR     => rx_fifoxm_wr   ,
        FULL   => rx_fifoxm_full ,
        AFULL  => open           ,

        DO     => rx_fifoxm_dout ,
        RD     => rx_fifoxm_rd   ,
        EMPTY  => rx_fifoxm_empty,
        AEMPTY => open
    );

    -- ----------------
    --  RX FIFO output
    -- ----------------
    rx_fifoxm_dout_arr <= slv_array_deser(rx_fifoxm_dout, WORD_BLOCKS);
    rx_fifoxm_dout_parse_g : for b in 0 to WORD_BLOCKS-1 generate
        -- For easier orientation:
        -- rx_fifoxm_dout_arr : slv_array_t(WORD_BLOCKS-1 downto 0)(RX_FIFO_DATA_WIDTH-1 downto 0), where
        -- RX_FIFO_DATA_WIDTH = BLOCK_WIDTH + MFB_META_WIDTH + TS_WIDTH + 1 + 1 + max(1,log2(MFB_BLOCK_SIZE)).
        rx_fifoxm_out_data         (b) <= rx_fifoxm_dout_arr(b)(RX_FIFO_DATA_WIDTH                                         -1 downto RX_FIFO_DATA_WIDTH-BLOCK_WIDTH                        );
        rx_fifoxm_out_meta_blocks  (b) <= rx_fifoxm_dout_arr(b)(RX_FIFO_DATA_WIDTH-BLOCK_WIDTH                             -1 downto RX_FIFO_DATA_WIDTH-BLOCK_WIDTH-MFB_META_WIDTH         );
        rx_fifoxm_out_ts_blocks    (b) <= rx_fifoxm_dout_arr(b)(RX_FIFO_DATA_WIDTH-BLOCK_WIDTH-MFB_META_WIDTH              -1 downto RX_FIFO_DATA_WIDTH-BLOCK_WIDTH-MFB_META_WIDTH-TS_WIDTH);
        rx_fifoxm_out_sof_onehot   (b) <= rx_fifoxm_dout_arr(b)(RX_FIFO_DATA_WIDTH-BLOCK_WIDTH-MFB_META_WIDTH-TS_WIDTH     -1                                                              );
        rx_fifoxm_out_eof_onehot   (b) <= rx_fifoxm_dout_arr(b)(RX_FIFO_DATA_WIDTH-BLOCK_WIDTH-MFB_META_WIDTH-TS_WIDTH-1   -1                                                              );
        rx_fifoxm_out_eof_pos_items(b) <= rx_fifoxm_dout_arr(b)(RX_FIFO_DATA_WIDTH-BLOCK_WIDTH-MFB_META_WIDTH-TS_WIDTH-1-1 -1 downto 0                                                     );
    end generate;

    -- ========================================================================
    -- Packet transmitting logic
    -- ========================================================================

    rx_fifoxm_out_sof_onehot_vld <= rx_fifoxm_out_sof_onehot and not rx_fifoxm_empty;
    rx_fifoxm_out_eof_onehot_vld <= rx_fifoxm_out_eof_onehot and not rx_fifoxm_empty;

    sof_onehot_region <= slv_array_deser(rx_fifoxm_out_sof_onehot_vld, MFB_REGIONS);
    eof_onehot_region <= slv_array_deser(rx_fifoxm_out_eof_onehot_vld, MFB_REGIONS);

    -- --------------------------------
    --  MFB control signals recreation
    -- --------------------------------
    sof_eof_g : for r in 0 to MFB_REGIONS-1 generate
        -- SOF
        sof(r) <= or sof_onehot_region(r);
        -- SOF POS
        gen_enc_sofpos_i : entity work.gen_enc
        generic map(
            ITEMS  => MFB_REGION_SIZE,
            DEVICE => DEVICE
        )
        port map(
            DI     => sof_onehot_region(r),
            ADDR   => sof_pos_region   (r)
        );

        -- EOF
        eof(r) <= or eof_onehot_region(r);
        -- EOF POS
        gen_enc_eofpos_i : entity work.gen_enc
        generic map(
            ITEMS  => MFB_REGION_SIZE,
            DEVICE => DEVICE
        )
        port map(
            DI     => eof_onehot_region    (r),
            ADDR   => eof_pos_blocks_region(r)
        );
        eof_pos_items_region(r) <= rx_fifoxm_out_eof_pos_items((r*MFB_REGION_SIZE) + to_integer(unsigned(eof_pos_blocks_region(r))));
        eof_pos_region(r) <= eof_pos_blocks_region(r) & eof_pos_items_region(r);

        -- Address to Block with SOF
        sof_pos_ptr(r) <= to_integer(unsigned(sof_pos_region(r)));
    end generate;

    -- ---------------------
    --  Metadata recreation
    -- ---------------------
    fifoxm_out_meta_g : for r in 0 to MFB_REGIONS-1 generate
        rx_fifoxm_out_meta_regions(r) <= rx_fifoxm_out_meta_blocks(sof_pos_ptr(r));
    end generate;

    -- ---------------------------
    --  RX FIFOX Multi read logic
    -- ---------------------------
    -- read Blocks only up to the first EOF
    -- -> the next SOF will be at Block 0
    eof_rd_vec_p : process(all)
    begin
        eof_rd_vec <= (others => not rx_fifoxm_empty(WORD_BLOCKS-1));
        for b in 0 to WORD_BLOCKS-1 loop
            if (rx_fifoxm_out_eof_onehot_vld(b) = '1') then
                eof_rd_vec(WORD_BLOCKS-1 downto b+1) <= (others => '0');
                eof_rd_vec(b downto 0) <= (others => '1');
                exit;
            end if;
        end loop;
    end process;

    -- The SOF and TS is always at Block 0
    ts_ok(0) <= '1' when (stored_time_diff_fixed(0) >= unsigned(rx_fifoxm_out_ts_blocks(0))) else '0';
    eof_rd_vec_en <= '0' when ((rx_fifoxm_out_sof_onehot_vld(0) = '1') and (ts_ok(0) = '0')) else '1';

    rx_fifoxm_rd <= (eof_rd_vec and eof_rd_vec_en) and mfb_dst_rdy_mid_reg;

    -- ========================================================================
    -- Time logic
    -- ========================================================================

    sof_read_g : for r in 0 to MFB_REGIONS-1 generate
        sof_read(r) <= sof(r) and (or rx_fifoxm_rd((r+1)*MFB_REGION_SIZE-1 downto r*MFB_REGION_SIZE+sof_pos_ptr(r)));
    end generate;

    reset_g : if TS_FORMAT=0 generate
        -- Store new value of CURRENT_TIME with each read SOF
        update_stored_time <= or sof_read;
    else generate
        -- Store new value of CURRENT_TIME when the first SOF is read
        update_stored_time <= first_sof_read;

        first_sof_read <= (or sof_read) and waiting_for_first_sof;
        process(CLK)
        begin
            if rising_edge(CLK) then
                if (RESET = '1') or (TIME_RESET = '1') then
                    waiting_for_first_sof <= '1';
                end if;
                if ((or sof_read) = '1') then
                    waiting_for_first_sof <= '0';
                end if;
            end if;
        end process;
    end generate;

    -- Get the duration of a single clock period in [ns]
    process(CLK)
    begin
        if rising_edge(CLK) then
            current_time_reg <= unsigned(CURRENT_TIME);
        end if;
    end process;
    one_clk_period_time_diff <= resize(unsigned(CURRENT_TIME)-current_time_reg  , TS_WIDTH);

    -- Update the time difference that is then used for comparison with the packet's Timestamp
    process(CLK)
    begin
        if rising_edge(CLK) then
            -- Accumulate time until update_stored_time='1'
            stored_time_diff <= resize(stored_time_diff+one_clk_period_time_diff, TS_WIDTH);
            if (update_stored_time = '1') then
                -- Basically a reset, but to the duration of one clock period instead of 0 [ns]
                stored_time_diff <= one_clk_period_time_diff;
            end if;
            if (RESET = '1') then
                stored_time_diff <= (others => '0');
            end if;
        end if;
    end process;

    stored_time_diff_fixed(0) <= stored_time_diff;
    -- when on of the previous Regions with SOF were read, "fix" the time in the current word (set it to 0 ns)
    fix_time_g : for r in 0 to MFB_REGIONS-2 generate
        stored_time_diff_fixed(r+1) <= stored_time_diff when (or sof_read(r downto 0) = '0') else (others => '0');
    end generate;

    -- ========================================================================
    -- Middle register
    -- ========================================================================

    process(CLK)
    begin
        if rising_edge(CLK) then
            if (mfb_dst_rdy_mid_reg = '1') then
                mfb_data_mid_reg    <= slv_array_ser(rx_fifoxm_out_data);
                mfb_meta_mid_reg    <= slv_array_ser(rx_fifoxm_out_meta_regions);
                mfb_sof_pos_mid_reg <= slv_array_ser(sof_pos_region);
                mfb_eof_pos_mid_reg <= slv_array_ser(eof_pos_region);
                mfb_sof_mid_reg     <= sof_read;
                mfb_eof_mid_reg     <= eof;
                mfb_src_rdy_mid_reg <= or rx_fifoxm_rd;
            end if;
            if (RESET = '1') then
                mfb_src_rdy_mid_reg <= '0';
            end if;
        end if;
    end process;

    -- ========================================================================
    -- TX MFB FIFOX
    -- ========================================================================

    tx_mfb_fifox_i : entity work.MFB_FIFOX
    generic map(
        REGIONS             => MFB_REGIONS    ,
        REGION_SIZE         => MFB_REGION_SIZE,
        BLOCK_SIZE          => MFB_BLOCK_SIZE ,
        ITEM_WIDTH          => MFB_ITEM_WIDTH ,
        META_WIDTH          => MFB_META_WIDTH ,
        FIFO_DEPTH          => FIFO_DEPTH     ,
        RAM_TYPE            => "AUTO"         ,
        DEVICE              => DEVICE         ,
        ALMOST_FULL_OFFSET  => 0              ,
        ALMOST_EMPTY_OFFSET => 0          
    )
    port map(
        CLK => CLK,
        RST => RESET,

        RX_DATA     => mfb_data_mid_reg   ,
        RX_META     => mfb_meta_mid_reg   ,
        RX_SOF_POS  => mfb_sof_pos_mid_reg,
        RX_EOF_POS  => mfb_eof_pos_mid_reg,
        RX_SOF      => mfb_sof_mid_reg    ,
        RX_EOF      => mfb_eof_mid_reg    ,
        RX_SRC_RDY  => mfb_src_rdy_mid_reg,
        RX_DST_RDY  => mfb_dst_rdy_mid_reg,

        TX_DATA     => TX_MFB_DATA        ,
        TX_META     => TX_MFB_META        ,
        TX_SOF_POS  => TX_MFB_SOF_POS     ,
        TX_EOF_POS  => TX_MFB_EOF_POS     ,
        TX_SOF      => TX_MFB_SOF         ,
        TX_EOF      => TX_MFB_EOF         ,
        TX_SRC_RDY  => TX_MFB_SRC_RDY     ,
        TX_DST_RDY  => TX_MFB_DST_RDY     ,

        FIFO_STATUS => open               ,
        FIFO_AFULL  => open               ,
        FIFO_AEMPTY => open
    );

end architecture;
