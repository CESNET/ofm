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

-- This component limits output speed according to given Timestamps via the :vhdl:portsignal:`RX_MFB_TIMESTAMP <mfb_timestamp_limiter.rx_mfb_timestamp>` port.
-- There are 2 Timestamp formats that are currently supported (see the :vhdl:genconstant:`TIMESTAMP_FORMAT <mfb_packet_delayer.timestamp_format>` generic).
-- The incoming packets are split into queues (e.g., per each DMA Channel), where the order of packets is kept the same.
-- Then in each Queue, the :ref:`MFB Packet Delayer component <mfb_packet_delayer>` outputs each packet when the time is right.
-- Finally, the packets from all Queues are merged back into a single stream (no order is kept here).
--
-- The Packet Delayers use a time source, according to which they calculate the time that has passed and whether a packet is due to be sent.
-- The default is to use the so-called Time Counter (see diagram below), which is basically a counter that increments its value by the duration of one clock period derived from the
-- value of the :vhdl:genconstant:`CLK_FREQUENCY <mfb_timestamp_limiter.clk_frequency>` generic.
-- Another option is to use an external time source, for example, the TSU (for better precision).
-- In this case, set the :vhdl:genconstant:`EXTERNAL_TIME_SRC <mfb_timestamp_limiter.external_time_src>` generic to ``True`` and connect your time source to the
-- :vhdl:portsignal:`EXTERNAL_TIME <mfb_timestamp_limiter.external_time>` port.
--
-- The MI interface enables the user to reset Time in the Packet Delayers.
-- This is useful when using the :vhdl:genconstant:`Timestamp format 1 <mfb_timestamp_limiter.timestamp_format>`,
-- where the time is being incremented in each clock cycle since the very first packet after boot/reset passes through.
-- You can simply reset all Packet Delayers (all Queues) by setting the MI_RESET_REG register, or you can
-- select specific Queues by setting the MI_SEL_QUEUE_REG register before setting the MI_RESET_REG register.
-- After writing a **1** to the MI_RESET_REG register to issue the reset, its value automatically returns back to **0**.
--
-- **MI address space**
--
-- +----------------+----------------------------------------------------+
-- | Address offset | MI Register                                        |
-- +================+====================================================+
-- |           0x00 | Reset register (write only)                        |
-- +----------------+----------------------------------------------------+
-- |           0x04 | Select Queues for reset register                   |
-- +----------------+----------------------------------------------------+
--
entity MFB_TIMESTAMP_LIMITER is
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

    MI_DATA_WIDTH         : natural := 32;
    MI_ADDR_WIDTH         : natural := 32;

    -- Freq of the CLK signal (in Hz).
    CLK_FREQUENCY         : natural := 200000000;
    -- Width of Timestamps (in bits).
    TIMESTAMP_WIDTH       : natural := 48;
    -- Format of Timestamps. Options:
    --
    -- - ``0`` number of NS between individual packets,
    -- - ``1`` number of NS from RESET.
    TIMESTAMP_FORMAT      : natural := 0;
    -- Select Time source. Options:
    --
    -- True - use external source of time (port :vhdl:portsignal:`EXTERNAL_TIME <mfb_timestamp_limiter.external_time>`),
    -- False (default) - internal "Time Counter" with increment given by CLK_FREQUENCY.
    EXTERNAL_TIME_SRC     : boolean := False;
    -- Number of Items in the Packet Delayer's RX FIFO (the main buffer).
    BUFFER_SIZE           : natural := 2048;
    -- The number of Queues (DMA Channels).
    QUEUES                : natural := 1;

    -- FPGA device name: ULTRASCALE, STRATIX10, AGILEX, ...
    DEVICE                : string := "STRATIX10"
);
port(
    -- =====================================================================
    --  Clock and Reset
    -- =====================================================================

    CLK              : in  std_logic;
    RESET            : in  std_logic;

    -- Connect your own Time source to this port (used when the :vhdl:genconstant:`EXTERNAL_TIME_SRC <mfb_timestamp_limiter.external_time_src>` generic is ``True``).
    EXTERNAL_TIME    : in  std_logic_vector(64-1 downto 0);

    -- =====================================================================
    --  RX MFB STREAM
    -- =====================================================================

    RX_MFB_DATA      : in  std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
    -- Valid with SOF.
    RX_MFB_META      : in  std_logic_vector(MFB_REGIONS*MFB_META_WIDTH-1 downto 0) := (others => '0');
    -- ID of the packet's DMA channel or queue.
    RX_MFB_QUEUE     : in  std_logic_vector(MFB_REGIONS*max(1,log2(QUEUES))-1 downto 0) := (others => '0');
    -- Timestamps are valid with each SOF.
    RX_MFB_TIMESTAMP : in  std_logic_vector(MFB_REGIONS*TIMESTAMP_WIDTH-1 downto 0) := (others => '0');
    RX_MFB_SOF_POS   : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    RX_MFB_EOF_POS   : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    RX_MFB_SOF       : in  std_logic_vector(MFB_REGIONS-1 downto 0);
    RX_MFB_EOF       : in  std_logic_vector(MFB_REGIONS-1 downto 0);
    RX_MFB_SRC_RDY   : in  std_logic;
    RX_MFB_DST_RDY   : out std_logic;

    -- =====================================================================
    --  TX MFB STREAM
    -- =====================================================================

    TX_MFB_DATA      : out std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
    -- Valid with SOF.
    TX_MFB_META      : out std_logic_vector(MFB_REGIONS*MFB_META_WIDTH-1 downto 0);
    TX_MFB_SOF_POS   : out std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
    TX_MFB_EOF_POS   : out std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
    TX_MFB_SOF       : out std_logic_vector(MFB_REGIONS-1 downto 0);
    TX_MFB_EOF       : out std_logic_vector(MFB_REGIONS-1 downto 0);
    TX_MFB_SRC_RDY   : out std_logic;
    TX_MFB_DST_RDY   : in  std_logic;

    -- =====================================================================
    --  MI INTERFACE
    -- =====================================================================

    MI_DWR     : in  std_logic_vector(MI_DATA_WIDTH-1 downto 0);
    MI_ADDR    : in  std_logic_vector(MI_ADDR_WIDTH-1 downto 0);
    MI_BE      : in  std_logic_vector(MI_DATA_WIDTH/8-1 downto 0); -- Not supported!
    MI_WR      : in  std_logic;
    MI_RD      : in  std_logic;
    MI_ARDY    : out std_logic;
    MI_DRD     : out std_logic_vector(MI_DATA_WIDTH-1 downto 0);
    MI_DRDY    : out std_logic
);
end entity;

architecture FULL of MFB_TIMESTAMP_LIMITER is

    -- ========================================================================
    --                                CONSTANTS
    -- ========================================================================

    -- MI REG ADDR for: reset of Time counters in Packet Delayers.
    -- Reset Time in ``all`` (default) or selected Queues (according to MI_SEL_QUEUE_REG).
    -- Not readable.
    constant MI_RESET_REG     : integer := 0;
    -- MI REG ADDR for: select Queues to be reset.
    -- Each bit corresponds to one Queue (bit mask).
    -- Set '1' to perform the reset. Default value is (others => '1');
    -- MAX 32 Queues! For more Queues you need to add more MI regs for the selection.
    constant MI_SEL_QUEUE_REG : integer := 4;

    constant MFB_REGION_WIDTH : natural := MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH;
    constant MFB_WORD_WIDTH   : natural := MFB_REGIONS*MFB_REGION_WIDTH;
    constant MFB_SOFPOS_WIDTH : natural := max(1,log2(MFB_REGION_SIZE));
    constant MFB_EOFPOS_WIDTH : natural := max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE));

    constant MFB_META_COMB_WIDTH : natural := MFB_META_WIDTH + TIMESTAMP_WIDTH;

    -- Clock period in nanoseconds
    constant CLK_PERIOD         : natural := integer(real(1)/real(CLK_FREQUENCY)*real(10**9));
    -- Counter increment (in ns)
    constant TIME_CNT_INC       : std_logic_vector := std_logic_vector(to_unsigned(CLK_PERIOD, log2(CLK_PERIOD)));

    -- ========================================================================
    --                                 SIGNALS
    -- ========================================================================

    signal mi_addr_int          : integer range 2**4-1 downto 0;

    signal time_reset_en        : std_logic;
    signal queue_sel_en         : std_logic;

    signal time_reset_reg       : std_logic;
    signal sel_queue_reg        : std_logic_vector(MI_DATA_WIDTH-1 downto 0) := (others => '1');

    signal time_reset_edge      : std_logic;
    signal time_reset_pulse     : std_logic;

    signal pd_time_reset        : std_logic_vector(QUEUES-1 downto 0);

    signal time_cnt             : std_logic_vector(64-1 downto 0);
    signal input_time           : std_logic_vector(64-1 downto 0);

    signal rx_mfb_meta_arr      : slv_array_t     (MFB_REGIONS-1 downto 0)(MFB_META_WIDTH-1 downto 0);
    signal rx_mfb_ts_arr        : slv_array_t     (MFB_REGIONS-1 downto 0)(TIMESTAMP_WIDTH-1 downto 0);
    signal rx_mfb_comb_meta_arr : slv_array_t     (MFB_REGIONS-1 downto 0)(MFB_META_COMB_WIDTH-1 downto 0);
    signal rx_mfb_comb_meta     : std_logic_vector(MFB_REGIONS*            MFB_META_COMB_WIDTH-1 downto 0);

    signal rx_pd_comb_meta      : slv_array_t   (QUEUES-1 downto 0)(MFB_REGIONS*            MFB_META_COMB_WIDTH-1 downto 0);
    signal rx_pd_comb_meta_arr  : slv_array_2d_t(QUEUES-1 downto 0)(MFB_REGIONS-1 downto 0)(MFB_META_COMB_WIDTH-1 downto 0);
    signal rx_pd_meta_arr       : slv_array_2d_t(QUEUES-1 downto 0)(MFB_REGIONS-1 downto 0)(MFB_META_WIDTH-1 downto 0);
    signal rx_pd_ts_arr         : slv_array_2d_t(QUEUES-1 downto 0)(MFB_REGIONS-1 downto 0)(TIMESTAMP_WIDTH-1 downto 0);

    signal rx_pd_data           : slv_array_t     (QUEUES-1 downto 0)(MFB_WORD_WIDTH-1 downto 0);
    signal rx_pd_meta           : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS*MFB_META_WIDTH-1 downto 0);
    signal rx_pd_ts             : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS*TIMESTAMP_WIDTH-1 downto 0);
    signal rx_pd_sof_pos        : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS*MFB_SOFPOS_WIDTH-1 downto 0);
    signal rx_pd_eof_pos        : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS*MFB_EOFPOS_WIDTH-1 downto 0);
    signal rx_pd_sof            : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS-1 downto 0);
    signal rx_pd_eof            : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS-1 downto 0);
    signal rx_pd_src_rdy        : std_logic_vector(QUEUES-1 downto 0);
    signal rx_pd_dst_rdy        : std_logic_vector(QUEUES-1 downto 0);
    
    signal tx_pd_data           : slv_array_t     (QUEUES-1 downto 0)(MFB_WORD_WIDTH-1 downto 0);
    signal tx_pd_meta           : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS*MFB_META_WIDTH-1 downto 0);
    signal tx_pd_sof_pos        : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS*MFB_SOFPOS_WIDTH-1 downto 0);
    signal tx_pd_eof_pos        : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS*MFB_EOFPOS_WIDTH-1 downto 0);
    signal tx_pd_sof            : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS-1 downto 0);
    signal tx_pd_eof            : slv_array_t     (QUEUES-1 downto 0)(MFB_REGIONS-1 downto 0);
    signal tx_pd_src_rdy        : std_logic_vector(QUEUES-1 downto 0);
    signal tx_pd_dst_rdy        : std_logic_vector(QUEUES-1 downto 0);

begin

    assert (QUEUES > 0) and (QUEUES <= 32)
        report "TIMESTAMP LIMITER: Currently supported number of Queues is between 0 and 32 (inclusive)!" & LF &
               "In case of needing more, simply add more MI_SEL_QUEUE_REG registers." & LF
        severity Failure;

    -- ========================================================================
    -- MI logic
    -- ========================================================================

    MI_ARDY <= MI_RD or MI_WR;

    -- ---------------
    --  MI read logic
    -- ---------------
    mi_addr_int <= to_integer(unsigned(MI_ADDR(4-1 downto 0)));
    process (CLK)
    begin
        if (rising_edge(CLK)) then
            case mi_addr_int is
                when MI_SEL_QUEUE_REG => MI_DRD <= sel_queue_reg;
                when others           => MI_DRD <= X"0000BEEF";
            end case;
        end if;
    end process;

    mi_drdy_reg_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
            MI_DRDY <= MI_RD;
            if (RESET = '1') then
                MI_DRDY <= '0';
            end if;
        end if;
    end process;

    -- ----------------
    --  MI write logic
    -- ----------------
    time_reset_en <= '1' when (MI_WR = '1') and (mi_addr_int = MI_RESET_REG    ) else '0';
    queue_sel_en  <= '1' when (MI_WR = '1') and (mi_addr_int = MI_SEL_QUEUE_REG) else '0';

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (time_reset_en = '1') then
                time_reset_reg <= MI_DWR(0);
            end if;
            if (RESET = '1') or (time_reset_edge = '1') then
                time_reset_reg <= '0';
            end if;
        end if;
    end process;

    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (queue_sel_en = '1') then
                sel_queue_reg <= MI_DWR;
            end if;
            if (RESET = '1') then
                sel_queue_reg <= (others => '1');
            end if;
        end if;
    end process;

    -- ------------------
    --  Time reset logic
    -- ------------------
    -- Detect rising edge of the time_reset_reg signal.
    edge_detect_i : entity work.EDGE_DETECT
    port map(
        CLK  => CLK,
        DI   => time_reset_reg,
        EDGE => time_reset_edge
    );

    -- Use the detected edge to extend the reset pulse.
    pulse_extend_i : entity work.PULSE_EXTEND
    generic map(
        N => 5
    )
    port map(
        RST => RESET,
        CLK => CLK,
        I   => time_reset_edge,
        O   => time_reset_pulse
    );

    -- Time reset finalization
    pd_time_reset <= sel_queue_reg(QUEUES-1 downto 0) when (time_reset_pulse = '1') else (others => '0');

    -- ========================================================================
    -- Time counter
    -- ========================================================================
    
    time_cnt_i : entity work.DSP_COUNTER
    generic map (
        INPUT_WIDTH  => log2(CLK_PERIOD),
        OUTPUT_WIDTH => 64,
        INPUT_REGS   => True,
        DEVICE       => DEVICE,
        DSP_ENABLE   => True
    )
    port map (
        CLK        => CLK,
        CLK_EN     => '1',
        RESET      => RESET,
        INCREMENT  => TIME_CNT_INC,
        MAX_VAL    => (others => '1'),
        RESULT     => time_cnt
    );

    -- ========================================================================
    -- Time selection
    -- ========================================================================

    time_sel_g : if (EXTERNAL_TIME_SRC) generate
        input_time <= EXTERNAL_TIME;
    else generate
        input_time <= time_cnt;
    end generate;
            
    -- ========================================================================
    -- Input MFB Splitter
    -- ========================================================================

    rx_mfb_meta_arr <= slv_array_deser(RX_MFB_META     , MFB_REGIONS);
    rx_mfb_ts_arr   <= slv_array_deser(RX_MFB_TIMESTAMP, MFB_REGIONS);

    rx_splitter_g : for r in 0 to MFB_REGIONS-1 generate
        rx_mfb_comb_meta_arr(r) <= rx_mfb_meta_arr(r) & rx_mfb_ts_arr(r);
    end generate;

    rx_mfb_comb_meta <= slv_array_ser(rx_mfb_comb_meta_arr);

    mfb_splitter_tree_i : entity work.MFB_SPLITTER_SIMPLE_GEN
    generic map(
        SPLITTER_OUTPUTS => QUEUES         ,
        REGIONS          => MFB_REGIONS    ,
        REGION_SIZE      => MFB_REGION_SIZE,
        BLOCK_SIZE       => MFB_BLOCK_SIZE ,
        ITEM_WIDTH       => MFB_ITEM_WIDTH ,
        META_WIDTH       => MFB_META_COMB_WIDTH
    )
    port map(
        CLK             => CLK,
        RESET           => RESET,

        RX_MFB_SEL      => RX_MFB_QUEUE    ,
        RX_MFB_DATA     => RX_MFB_DATA     ,
        RX_MFB_META     => rx_mfb_comb_meta,
        RX_MFB_SOF      => RX_MFB_SOF      ,
        RX_MFB_EOF      => RX_MFB_EOF      ,
        RX_MFB_SOF_POS  => RX_MFB_SOF_POS  ,
        RX_MFB_EOF_POS  => RX_MFB_EOF_POS  ,
        RX_MFB_SRC_RDY  => RX_MFB_SRC_RDY  ,
        RX_MFB_DST_RDY  => RX_MFB_DST_RDY  ,

        TX_MFB_DATA     => rx_pd_data      ,
        TX_MFB_META     => rx_pd_comb_meta ,
        TX_MFB_SOF      => rx_pd_sof       ,
        TX_MFB_EOF      => rx_pd_eof       ,
        TX_MFB_SOF_POS  => rx_pd_sof_pos   ,
        TX_MFB_EOF_POS  => rx_pd_eof_pos   ,
        TX_MFB_SRC_RDY  => rx_pd_src_rdy   ,
        TX_MFB_DST_RDY  => rx_pd_dst_rdy
    );

    -- ========================================================================
    -- Packet Delayers
    -- ========================================================================

    packet_delayers_g : for q in 0 to QUEUES-1 generate

        rx_pd_comb_meta_arr(q) <= slv_array_deser(rx_pd_comb_meta(q), MFB_REGIONS);
        rx_splitter_g : for r in 0 to MFB_REGIONS-1 generate
            rx_pd_meta_arr(q)(r) <= rx_pd_comb_meta_arr(q)(r)(MFB_META_COMB_WIDTH-1 downto TIMESTAMP_WIDTH);
            rx_pd_ts_arr  (q)(r) <= rx_pd_comb_meta_arr(q)(r)(TIMESTAMP_WIDTH-1 downto 0);
        end generate;

        rx_pd_meta(q) <= slv_array_ser(rx_pd_meta_arr(q));
        rx_pd_ts  (q) <= slv_array_ser(rx_pd_ts_arr  (q));

        packet_delayer_i : entity work.MFB_PACKET_DELAYER
        generic map(
            MFB_REGIONS     => MFB_REGIONS     ,
            MFB_REGION_SIZE => MFB_REGION_SIZE ,
            MFB_BLOCK_SIZE  => MFB_BLOCK_SIZE  ,
            MFB_ITEM_WIDTH  => MFB_ITEM_WIDTH  ,
            MFB_META_WIDTH  => MFB_META_WIDTH  ,

            TS_WIDTH        => TIMESTAMP_WIDTH ,
            TS_FORMAT       => TIMESTAMP_FORMAT,
            FIFO_DEPTH      => BUFFER_SIZE     ,
            DEVICE          => DEVICE
        )
        port map(
            CLK   => CLK,
            RESET => RESET,

            TIME_RESET     => pd_time_reset(q),
            CURRENT_TIME   => input_time      ,

            RX_MFB_DATA    => rx_pd_data   (q),
            RX_MFB_META    => rx_pd_meta   (q),
            RX_MFB_TS      => rx_pd_ts     (q),
            RX_MFB_SOF_POS => rx_pd_sof_pos(q),
            RX_MFB_EOF_POS => rx_pd_eof_pos(q),
            RX_MFB_SOF     => rx_pd_sof    (q),
            RX_MFB_EOF     => rx_pd_eof    (q),
            RX_MFB_SRC_RDY => rx_pd_src_rdy(q),
            RX_MFB_DST_RDY => rx_pd_dst_rdy(q),

            TX_MFB_DATA    => tx_pd_data   (q),
            TX_MFB_META    => tx_pd_meta   (q),
            TX_MFB_SOF_POS => tx_pd_sof_pos(q),
            TX_MFB_EOF_POS => tx_pd_eof_pos(q),
            TX_MFB_SOF     => tx_pd_sof    (q),
            TX_MFB_EOF     => tx_pd_eof    (q),
            TX_MFB_SRC_RDY => tx_pd_src_rdy(q),
            TX_MFB_DST_RDY => tx_pd_dst_rdy(q)
        );
            
    end generate;

    -- ========================================================================
    -- Output MFB Merger
    -- ========================================================================

    mfb_merger_tree_i : entity work.MFB_MERGER_SIMPLE_GEN
    generic map(
        MERGER_INPUTS   => QUEUES         ,
        MFB_REGIONS     => MFB_REGIONS    ,
        MFB_REGION_SIZE => MFB_REGION_SIZE,
        MFB_BLOCK_SIZE  => MFB_BLOCK_SIZE ,
        MFB_ITEM_WIDTH  => MFB_ITEM_WIDTH ,
        MFB_META_WIDTH  => MFB_META_WIDTH ,
        MASKING_EN      => True           ,
        CNT_MAX         => 64
    )
    port map(
        CLK             => CLK,
        RST             => RESET,

        RX_MFB_DATA     => tx_pd_data    ,
        RX_MFB_META     => tx_pd_meta    ,
        RX_MFB_SOF      => tx_pd_sof     ,
        RX_MFB_EOF      => tx_pd_eof     ,
        RX_MFB_SOF_POS  => tx_pd_sof_pos ,
        RX_MFB_EOF_POS  => tx_pd_eof_pos ,
        RX_MFB_SRC_RDY  => tx_pd_src_rdy ,
        RX_MFB_DST_RDY  => tx_pd_dst_rdy ,

        TX_MFB_DATA     => TX_MFB_DATA   ,
        TX_MFB_META     => TX_MFB_META   ,
        TX_MFB_SOF      => TX_MFB_SOF    ,
        TX_MFB_EOF      => TX_MFB_EOF    ,
        TX_MFB_SOF_POS  => TX_MFB_SOF_POS,
        TX_MFB_EOF_POS  => TX_MFB_EOF_POS,
        TX_MFB_SRC_RDY  => TX_MFB_SRC_RDY,
        TX_MFB_DST_RDY  => TX_MFB_DST_RDY
    );

end architecture;
