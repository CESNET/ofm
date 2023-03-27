-- mem_logger.vhd: Component for managing and loging statistics about memory bus
-- Copyright (C) 2022 CESNET z. s. p. o.
-- Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause


-- Control IN
-- [MI_DATA_WIDTH]:     MEM_DATA_WIDTH 
-- [MI_DATA_WIDTH]:     MEM_ADDR_WIDTH 
-- [MI_DATA_WIDTH]:     MEM_BURST_COUNT_WIDTH 
-- [MI_DATA_WIDTH]:     MEM_FREQ_KHZ 
--
-- Control OUT
-- 0:                   latency to first read word
--
-- Counters
-- 0:   write ticks (ticks from the first write   to the last)
-- 1:   read  ticks (ticks from the first read    to the last)
-- 2:   total ticks (ticks from the first request to the last)
-- 3:   write req cnt
-- 4:   write req words
-- 5:   read req  cnt
-- 6:   read req  words
-- 7:   read resp words
-- 8:   err - zero burst
-- 9:   err - simult read write
--
-- Values
-- 0:   latency
-- 1:   paralel reads cnt (from FIFO len)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.math_pack.all;
use work.type_pack.all;

-- .. vhdl:autogenerics:: MEM_LOGGER
entity MEM_LOGGER is
generic (    
    MEM_DATA_WIDTH          : integer := 512;
    MEM_ADDR_WIDTH          : integer := 26;
    MEM_BURST_COUNT_WIDTH   : integer := 7;
    MEM_FREQ_KHZ            : integer := 266660;

    MI_DATA_WIDTH           : integer := 32;
    MI_ADDR_WIDTH           : integer := 32;

    -- Specify read latency histogram precision
    HISTOGRAM_BOXES         : integer := 255;
    -- Specify maximum paraller read requests
    MAX_PARALEL_READS       : integer := 64;
    -- Specify read latency ticks count width
    LATENCY_TICKS_WIDTH     : integer := 11;
    DEVICE                  : string  := "ULTRASCALE"
);
port(    
    CLK                     : in  std_logic;
    RST                     : in  std_logic;
    RST_DONE                : out std_logic;

    -- ================================
    -- Memory interface
    -- ================================

    MEM_READY               : in  std_logic;
    MEM_READ                : in  std_logic;
    MEM_WRITE               : in  std_logic;
    MEM_ADDRESS             : in  std_logic_vector(MEM_ADDR_WIDTH - 1 downto 0);
    MEM_READ_DATA           : in  std_logic_vector(MEM_DATA_WIDTH - 1 downto 0);
    MEM_WRITE_DATA          : in  std_logic_vector(MEM_DATA_WIDTH - 1 downto 0);
    MEM_BURST_COUNT         : in  std_logic_vector(MEM_BURST_COUNT_WIDTH - 1 downto 0);
    MEM_READ_DATA_VALID     : in  std_logic;

    -- ==========================
    -- MI bus interface
    -- ==========================

    MI_DWR                  : in  std_logic_vector(MI_DATA_WIDTH - 1 downto 0);
    MI_ADDR                 : in  std_logic_vector(MI_ADDR_WIDTH - 1 downto 0);
    MI_BE                   : in  std_logic_vector(MI_DATA_WIDTH / 8 - 1 downto 0);
    MI_RD                   : in  std_logic;
    MI_WR                   : in  std_logic;
    MI_ARDY                 : out std_logic;
    MI_DRD                  : out std_logic_vector(MI_DATA_WIDTH - 1 downto 0) := (others => '0');
    MI_DRDY                 : out std_logic
);
end entity;

-- =========================================================================

architecture FULL of MEM_LOGGER is
  
    ---------------
    -- Constants --
    ---------------

    constant CNTER_CNT          : integer := 10;
    constant VALUE_CNT          : integer := 2;
    constant CTRLO_WIDTH        : integer := 1;
    constant CTRLI_WIDTH        : integer := 4 * MI_DATA_WIDTH;
    constant CNTER_WIDTH        : integer := MI_DATA_WIDTH;

    constant PARALEL_READS_WIDTH: integer := log2(MAX_PARALEL_READS) + 1;

    constant VALUE_WIDTH        : i_array_t(max(VALUE_CNT - 1, 0) downto 0) := (
        0 => LATENCY_TICKS_WIDTH,
        1 => PARALEL_READS_WIDTH
    );
    constant HIST_EN            : b_array_t(max(VALUE_CNT - 1, 0) downto 0) := (others => true);
    constant SUM_EXTRA_WIDTH    : i_array_t(max(VALUE_CNT - 1, 0) downto 0) := (others => 64);
    constant HIST_BOX_CNT       : i_array_t(max(VALUE_CNT - 1, 0) downto 0) := (
        0 => HISTOGRAM_BOXES,
        1 => MAX_PARALEL_READS / 2
    );
    constant HIST_BOX_WIDTH     : i_array_t(max(VALUE_CNT - 1, 0) downto 0) := (others => 32);

    constant CTRLO_DEFAULT      : std_logic_vector(max(CTRLO_WIDTH - 1, 0) downto 0) := (others => '0');

    constant BURST_MAX          : std_logic_vector(MEM_BURST_COUNT_WIDTH - 1 downto 0) := (others => '1');
    constant BURST_MIN          : std_logic_vector(MEM_BURST_COUNT_WIDTH - 1 downto 0) := std_logic_vector(to_unsigned(1, MEM_BURST_COUNT_WIDTH));

    -------------
    -- Signals --
    -------------

    signal sw_rst               : std_logic;
    signal rst_intern           : std_logic;

    signal ready                : std_logic;
    signal read                 : std_logic;
    signal write                : std_logic;
    signal address              : std_logic_vector(MEM_ADDR_WIDTH - 1 downto 0);
    signal read_data            : std_logic_vector(MEM_DATA_WIDTH - 1 downto 0);
    signal write_data           : std_logic_vector(MEM_DATA_WIDTH - 1 downto 0);
    signal burst_count          : std_logic_vector(MEM_BURST_COUNT_WIDTH - 1 downto 0);
    signal read_data_valid      : std_logic;

    signal wr_req               : std_logic;
    signal rd_req               : std_logic;
    signal rd_resp              : std_logic;
    signal wr_req_invalid       : std_logic;

    signal wr_start             : std_logic;
    signal wr_running           : std_logic;
    signal wr_done              : std_logic;
    signal burst_one            : std_logic;
    signal wr_burst_reg         : std_logic_vector(MEM_BURST_COUNT_WIDTH - 1 downto 0);

    signal rd_start             : std_logic;
    signal rd_running           : std_logic;
    signal rd_done              : std_logic;
    signal rd_burst_one         : std_logic;
    signal rd_burst_reg         : std_logic_vector(MEM_BURST_COUNT_WIDTH - 1 downto 0);
    signal rd_burst             : std_logic_vector(MEM_BURST_COUNT_WIDTH - 1 downto 0);

    signal first_write          : std_logic;
    signal first_read           : std_logic;

    signal cnters_diff          : slv_array_t(max(CNTER_CNT - 1, 0) downto 0)(CNTER_WIDTH - 1 downto 0) := (others => (std_logic_vector(to_unsigned(1, CNTER_WIDTH))));
    signal cnters_submit        : std_logic_vector(max(CNTER_CNT - 1, 0) downto 0) := (others => '1');

    signal latency              : std_logic_vector(LATENCY_TICKS_WIDTH - 1 downto 0);
    signal latency_vld          : std_logic;

    signal ctrlo                : std_logic_vector(CTRLO_WIDTH - 1 downto 0);
    signal latency_to_first     : std_logic;
    signal latency_end          : std_logic;

    signal paralel_reads        : std_logic_vector(max(PARALEL_READS_WIDTH - 1, 1) downto 0);

begin

    -------------------------
    -- Component instances --
    -------------------------

    data_logger_i : entity work.DATA_LOGGER
    generic map (    
        MI_DATA_WIDTH       => MI_DATA_WIDTH  ,
        MI_ADDR_WIDTH       => MI_ADDR_WIDTH  ,
        CNTER_CNT           => CNTER_CNT      ,
        VALUE_CNT           => VALUE_CNT      ,
        CTRLO_WIDTH         => CTRLO_WIDTH    ,
        CTRLI_WIDTH         => CTRLI_WIDTH    ,
        CNTER_WIDTH         => CNTER_WIDTH    ,
        VALUE_WIDTH         => VALUE_WIDTH    ,
        HIST_EN             => HIST_EN        ,
        SUM_EXTRA_WIDTH     => SUM_EXTRA_WIDTH,
        HIST_BOX_CNT        => HIST_BOX_CNT   ,
        HIST_BOX_WIDTH      => HIST_BOX_WIDTH ,
        CTRLO_DEFAULT       => CTRLO_DEFAULT
    )
    port map (    
        CLK                 => CLK        ,
        RST                 => RST        ,
        RST_DONE            => RST_DONE   ,
        SW_RST              => sw_rst     ,

        CTRLO               => ctrlo,
        CTRLI               => (
            std_logic_vector(to_unsigned(MEM_FREQ_KHZ,          MI_DATA_WIDTH)),
            std_logic_vector(to_unsigned(MEM_BURST_COUNT_WIDTH, MI_DATA_WIDTH)),
            std_logic_vector(to_unsigned(MEM_ADDR_WIDTH,        MI_DATA_WIDTH)),
            std_logic_vector(to_unsigned(MEM_DATA_WIDTH,        MI_DATA_WIDTH))
        ),
        CNTERS_INCR         => (
            wr_req and rd_req,
            wr_req_invalid,
            rd_resp,
            rd_req,
            rd_req,
            wr_req,
            wr_start,
            not first_write or not first_read or wr_req or rd_req,
            not first_read  or rd_req,
            not first_write or wr_req     -- Start counting from the first write
        ),
        CNTERS_DIFF         => cnters_diff,
        CNTERS_SUBMIT       => cnters_submit,
        VALUES_VLD          => (
            rd_req,
            latency_vld
        ),
        VALUES              => (
            paralel_reads   &
            latency
        ),

        MI_DWR              => MI_DWR     ,
        MI_ADDR             => MI_ADDR    ,
        MI_BE               => MI_BE      ,
        MI_RD               => MI_RD      ,
        MI_WR               => MI_WR      ,
        MI_ARDY             => MI_ARDY    ,
        MI_DRD              => MI_DRD     ,
        MI_DRDY             => MI_DRDY
    );

    -- Save read burst
    rd_burst_fifo_i : entity work.FIFOX
    generic map (
        DATA_WIDTH  => MEM_BURST_COUNT_WIDTH,
        ITEMS       => MAX_PARALEL_READS,
        DEVICE      => DEVICE
    )
    port map (
        CLK         => CLK,
        RESET       => rst_intern,
    
        DI          => burst_count,
        WR          => rd_req,
        --FULL        => FIFO_FULL,
    
        DO          => rd_burst,
        RD          => rd_start
    );


    latency_meter_i : entity work.LATENCY_METER
    generic map (
        DATA_WIDTH              => LATENCY_TICKS_WIDTH,
        MAX_PARALEL_EVENTS      => MAX_PARALEL_READS,
        DEVICE                  => DEVICE
    )
    port map (
        CLK                     => CLK,
        RST                     => rst_intern,

        START_EVENT             => rd_req,
        END_EVENT               => latency_end,

        LATENCY_VLD             => latency_vld,
        LATENCY                 => latency,
        --FIFO_FULL               => ,
        FIFO_ITEMS              => paralel_reads
    );

    -------------------------
    -- Combinational logic --
    -------------------------

    rst_intern      <= RST or sw_rst;

    wr_req          <= write and ready and not wr_req_invalid;
    rd_req          <= read  and ready;
    rd_resp         <= read_data_valid;
    -- Burst count = 0 is invalid
    wr_req_invalid  <= ((write and not wr_running) or read) and ready and not (or burst_count);

    wr_start    <= wr_req and not wr_running;
    wr_done     <= '1' when ((wr_req = '1' and wr_burst_reg = BURST_MIN and wr_running = '1') or burst_one = '1') else 
                   '0'; 
    burst_one   <= '1' when (wr_req = '1' and wr_running = '0' and burst_count = BURST_MIN) else 
                   '0';

    rd_start    <= rd_resp and not rd_running;
    rd_done     <= '1' when ((rd_resp = '1' and rd_burst_reg = BURST_MIN and rd_running = '1') or rd_burst_one = '1') else 
                   '0'; 
    rd_burst_one<= '1' when (rd_resp = '1' and rd_running = '0' and rd_burst = BURST_MIN) else 
                   '0';

    cnters_diff(6)(MEM_BURST_COUNT_WIDTH - 1 downto 0)  <= burst_count;
    cnters_submit(0)    <= wr_req;
    cnters_submit(1)    <= rd_req;
    cnters_submit(2)    <= wr_req or rd_req;

    latency_to_first    <= ctrlo(0);
    latency_end         <= rd_done when (latency_to_first = '0') else 
                           rd_start;

    ---------------
    -- Registers --
    ---------------

    input_reg_p : process(CLK)
    begin
        if (rising_edge(CLK)) then
            ready               <= MEM_READY          ;
            read                <= MEM_READ           ;
            write               <= MEM_WRITE          ;
            address             <= MEM_ADDRESS        ;
            read_data           <= MEM_READ_DATA      ;
            write_data          <= MEM_WRITE_DATA     ;
            burst_count         <= MEM_BURST_COUNT    ;
            read_data_valid     <= MEM_READ_DATA_VALID;
        end if;
    end process;

    wr_burst_reg_p : process(CLK)
    begin
        if (rising_edge(CLK)) then
            if (wr_start = '1') then
                -- First write word
                wr_burst_reg    <= std_logic_vector(unsigned(burst_count) - 1);
            elsif (wr_req = '1') then
                wr_burst_reg    <= std_logic_vector(unsigned(wr_burst_reg) - 1);
            end if;
        end if;
    end process;

    wr_runnung_p : process(CLK)
    begin
        if (rising_edge(CLK)) then
            if (rst_intern = '1' or wr_done = '1' or burst_one = '1') then
                wr_running  <= '0';
            elsif (wr_req = '1') then
                wr_running  <= '1';
            end if;
        end if;
    end process;

    rd_burst_reg_p : process(CLK)
    begin
        if (rising_edge(CLK)) then
            if (rd_start = '1') then
                -- First write word
                rd_burst_reg    <= std_logic_vector(unsigned(rd_burst) - 1);
            elsif (rd_resp = '1') then
                rd_burst_reg    <= std_logic_vector(unsigned(rd_burst_reg) - 1);
            end if;
        end if;
    end process;

    rd_runnung_p : process(CLK)
    begin
        if (rising_edge(CLK)) then
            if (rst_intern = '1' or rd_done = '1' or rd_burst_one = '1') then
                rd_running  <= '0';
            elsif (rd_resp = '1') then
                rd_running  <= '1';
            end if;
        end if;
    end process;

    first_write_p : process(CLK)
    begin
        if (rising_edge(CLK)) then
            if (rst_intern = '1') then
                first_write <= '1';
            elsif (wr_req = '1') then
                first_write <= '0';
            end if;
        end if;
    end process;

    first_read_p : process(CLK)
    begin
        if (rising_edge(CLK)) then
            if (rst_intern = '1') then
                first_read <= '1';
            elsif (rd_req = '1') then
                first_read <= '0';
            end if;
        end if;
    end process;

end architecture;
