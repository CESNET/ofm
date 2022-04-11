-- mfb_user_packet_gen.vhd: MFB user packet generator
-- Copyright (C) 2018 CESNET
-- Author(s): Jakub Cabal <cabal@cesnet.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.math_pack.all;
use work.type_pack.all;

entity MFB_USER_PACKET_GEN is
   generic(
      -- =======================================================================
      -- MFB BUS CONFIGURATION: 
      -- =======================================================================
      REGIONS     : natural := 2; -- any power of two
      REGION_SIZE : natural := 8; -- any power of two
      BLOCK_SIZE  : natural := 8; -- any power of two
      ITEM_WIDTH  : natural := 8; -- any positive
      -- =======================================================================
      -- USER PACKET GENERATOR CONFIGURATION: 
      -- =======================================================================
      -- This parameter determines maximum length of generated packet.
      LEN_WIDTH   : natural := 14;
      -- Set correct device type, is used for choose best FIFOX settings.
      DEVICE      : string  := "ULTRASCALE"
   );
   port(
      -- =======================================================================
      -- CLOCK AND RESET
      -- =======================================================================
      CLK         : in  std_logic;
      RESET       : in  std_logic;
      -- =======================================================================
      -- INPUT INTERFACE WITH INSTRUCTIONS OF PACKET GENERATION (MVB INTERFACE)
      -- =======================================================================
      -- Length of the generated packet. Minimum length is 60 MFB items. Maximum
      -- length is 2^LEN_WIDTH-1 MFB items.
      GEN_DATA    : in  std_logic_vector(REGIONS*LEN_WIDTH-1 downto 0);
      -- Valid of the packet generation.
      GEN_VLD     : in  std_logic_vector(REGIONS-1 downto 0);
      -- Source ready of the MVB like bus.
      GEN_SRC_RDY : in  std_logic;
      -- Destination ready of the MVB like bus.
      GEN_DST_RDY : out std_logic;
      -- =======================================================================
      -- OUTPUT MFB INTERFACE
      -- =======================================================================
      TX_DATA     : out std_logic_vector(REGIONS*REGION_SIZE*BLOCK_SIZE*ITEM_WIDTH-1 downto 0);
      TX_SOF_POS  : out std_logic_vector(REGIONS*max(1,log2(REGION_SIZE))-1 downto 0);
      TX_EOF_POS  : out std_logic_vector(REGIONS*max(1,log2(REGION_SIZE*BLOCK_SIZE))-1 downto 0);
      TX_SOF      : out std_logic_vector(REGIONS-1 downto 0);
      TX_EOF      : out std_logic_vector(REGIONS-1 downto 0);
      TX_SRC_RDY  : out std_logic;
      TX_DST_RDY  : in  std_logic
   );
end MFB_USER_PACKET_GEN;

architecture FULL of MFB_USER_PACKET_GEN is

   constant SOF_POS_WIDTH  : natural := log2(REGION_SIZE);
   constant EOF_POS_WIDTH  : natural := log2(REGION_SIZE*BLOCK_SIZE);
   constant BLOCK_WIDTH    : natural := log2(BLOCK_SIZE);
   constant WORD_CNT_WIDTH : natural := LEN_WIDTH-log2(REGIONS)-EOF_POS_WIDTH;

   signal s_pkt_len                 : slv_array_t(REGIONS-1 downto 0)(LEN_WIDTH-1 downto 0);
   signal s_pkt_end_offset          : slv_array_t(REGIONS-1 downto 0)(LEN_WIDTH-1 downto 0);

   signal s_fifo_pkt_wr             : std_logic_vector(REGIONS-1 downto 0);
   signal s_fifo_pkt_full           : std_logic;
   signal s_fifo_pkt_len_ser        : std_logic_vector(REGIONS*LEN_WIDTH-1 downto 0);
   signal s_fifo_pkt_len            : slv_array_t(REGIONS-1 downto 0)(LEN_WIDTH-1 downto 0);
   signal s_fifo_pkt_gen_n          : std_logic_vector(REGIONS-1 downto 0);
   signal s_fifo_pkt_gen            : std_logic_vector(REGIONS-1 downto 0);
   signal s_fifo_pkt_ack            : std_logic_vector(REGIONS-1 downto 0);
   signal s_fifo_pkt_rd             : std_logic_vector(REGIONS-1 downto 0);

   signal s_muxed_pkt_len           : slv_array_t(REGIONS-1 downto 0)(LEN_WIDTH-1 downto 0);
   signal s_muxed_pkt_gen           : std_logic_vector(REGIONS-1 downto 0);
   signal s_word_cnt                : slv_array_t(REGIONS+1-1 downto 0)(WORD_CNT_WIDTH-1 downto 0);

   signal s_mux_sel                 : slv_array_t(REGIONS-1 downto 0)(log2(REGIONS)-1 downto 0);
   signal s_region_full             : std_logic_vector(REGIONS-1 downto 0);
   signal s_eof_offset_new          : slv_array_t(REGIONS-1 downto 0)(LEN_WIDTH-1 downto 0);

   signal s_eof_offset_prev         : slv_array_t(REGIONS+1-1 downto 0)(LEN_WIDTH-1 downto 0);
   signal s_eof_offset_prev_word    : slv_array_t(REGIONS-1 downto 0)(WORD_CNT_WIDTH-1 downto 0);
   signal s_eof_offset_prev_region  : slv_array_t(REGIONS-1 downto 0)(log2(REGIONS)-1 downto 0);
   signal s_eof_prev_word_ok        : std_logic_vector(REGIONS-1 downto 0);
   signal s_eof_prev_region_ok      : std_logic_vector(REGIONS-1 downto 0);
   signal s_eof_prev_ok             : std_logic_vector(REGIONS-1 downto 0);

   signal s_eof_offset_curr         : slv_array_t(REGIONS-1 downto 0)(LEN_WIDTH-1 downto 0);
   signal s_eof_offset_curr_regions : slv_array_t(REGIONS-1 downto 0)(WORD_CNT_WIDTH+log2(REGIONS)-1 downto 0);
   signal s_eof_curr_ok             : std_logic_vector(REGIONS-1 downto 0);

   signal s_need_set_eof            : std_logic_vector(REGIONS+1-1 downto 0);
   signal s_set_sof                 : std_logic_vector(REGIONS-1 downto 0);
   signal s_set_eof                 : std_logic_vector(REGIONS-1 downto 0);
   signal s_set_sof_possible        : std_logic_vector(REGIONS-1 downto 0);
   signal s_sof_pos                 : slv_array_t(REGIONS-1 downto 0)(SOF_POS_WIDTH-1 downto 0);
   signal s_sof_pos_ext             : slv_array_t(REGIONS-1 downto 0)(EOF_POS_WIDTH-1 downto 0);
   signal s_eof_pos                 : slv_array_t(REGIONS-1 downto 0)(EOF_POS_WIDTH-1 downto 0);

   signal s_tx_sof                  : std_logic_vector(REGIONS-1 downto 0);
   signal s_tx_eof                  : std_logic_vector(REGIONS-1 downto 0);
   signal s_tx_eof_pos              : slv_array_t(REGIONS-1 downto 0)(EOF_POS_WIDTH-1 downto 0);
   signal s_tx_sof_pos              : slv_array_t(REGIONS-1 downto 0)(SOF_POS_WIDTH-1 downto 0);
   signal s_tx_src_rdy              : std_logic;

begin

   s_fifo_pkt_wr <= GEN_VLD and GEN_SRC_RDY;
   GEN_DST_RDY <= not s_fifo_pkt_full;

   s_pkt_len <= slv_array_downto_deser(GEN_DATA,REGIONS,LEN_WIDTH);
   pkt_end_offset_g : for r in 0 to REGIONS-1 generate
      s_pkt_end_offset(r) <= std_logic_vector(unsigned(s_pkt_len(r)) - 1);
   end generate;
   
   -- FIFOX multi of generated packet length
   fifox_multi_i : entity work.FIFOX_MULTI
   generic map(
      DATA_WIDTH          => LEN_WIDTH,
      ITEMS               => REGIONS*16,
      WRITE_PORTS         => REGIONS,
      READ_PORTS          => REGIONS,
      RAM_TYPE            => "AUTO",
      DEVICE              => DEVICE,
      SAFE_READ_MODE      => false,
      ALMOST_FULL_OFFSET  => 1,
      ALMOST_EMPTY_OFFSET => 1
   )
   port map(
      CLK    => CLK,
      RESET  => RESET,

      DI     => slv_array_ser(s_pkt_end_offset,REGIONS,LEN_WIDTH),
      WR     => s_fifo_pkt_wr,
      FULL   => s_fifo_pkt_full,
      AFULL  => open,

      DO     => s_fifo_pkt_len_ser,
      RD     => s_fifo_pkt_rd,
      EMPTY  => s_fifo_pkt_gen_n,
      AEMPTY => open
   );

   s_fifo_pkt_rd <= s_fifo_pkt_ack and TX_DST_RDY;
   s_fifo_pkt_gen <= not s_fifo_pkt_gen_n;
   s_fifo_pkt_len <= slv_array_downto_deser(s_fifo_pkt_len_ser,REGIONS,LEN_WIDTH);

   -----------------------------------------------------------------------------
   -- SELECTING OF INSTRUCTIONS
   -----------------------------------------------------------------------------

   instruction_one_region_g : if REGIONS = 1 generate
      s_muxed_pkt_len(0) <= s_fifo_pkt_len(0);
      s_muxed_pkt_gen(0) <= s_fifo_pkt_gen(0);
   end generate;

   instruction_mux_g : if REGIONS > 1 generate
      instruction_mux_g2 : for r in 0 to REGIONS-1 generate
         s_muxed_pkt_len(r) <= s_fifo_pkt_len(to_integer(unsigned(s_mux_sel(r))));
         s_muxed_pkt_gen(r) <= s_fifo_pkt_gen(to_integer(unsigned(s_mux_sel(r))));
      end generate;
   end generate;

   -----------------------------------------------------------------------------
   -- MFB WORD COUNTER
   -----------------------------------------------------------------------------

   word_cnt_reg_p : process (CLK)
   begin
      if (rising_edge(CLK)) then
         if (RESET = '1') then
            s_word_cnt(0) <= (others => '0');
         elsif (TX_DST_RDY = '1') then
            s_word_cnt(0) <= std_logic_vector(unsigned(s_word_cnt(REGIONS)) + 1);
         end if;
      end if;
   end process;

   word_cnt_g : for r in 0 to REGIONS-1 generate
      s_word_cnt(r+1) <= (others => '0') when (s_set_sof_possible(r) = '1') else s_word_cnt(r);
   end generate;

   -----------------------------------------------------------------------------
   -- PACKET GENERATION
   -----------------------------------------------------------------------------

   eof_offset_prev_reg_p : process (CLK)
   begin
      if (rising_edge(CLK)) then
         if (TX_DST_RDY = '1') then
            s_eof_offset_prev(0) <= s_eof_offset_prev(REGIONS);
         end if;
      end if;
   end process;

   need_set_eof_per_wb_reg_p : process (CLK)
   begin
      if (rising_edge(CLK)) then
         if (RESET = '1') then
            s_need_set_eof(0) <= '0';
         elsif (TX_DST_RDY = '1') then
            s_need_set_eof(0) <= s_need_set_eof(REGIONS);
         end if;
      end if;
   end process;

   -- first header is every time on zero position
   s_mux_sel(0) <= (others => '0');
   mux_sel_g : for r in 1 to REGIONS-1 generate
      -- select next header only when you accepted previous header
      s_mux_sel(r) <= (std_logic_vector(unsigned(s_mux_sel(r-1)) + 1)) when (s_tx_sof(r-1) = '1') else s_mux_sel(r-1);
   end generate;

   pkt_gen_g : for r in 0 to REGIONS-1 generate

      s_sof_pos_ext(r) <= s_sof_pos(r) & std_logic_vector(unsigned(to_unsigned(0,BLOCK_WIDTH)));

      -- create new EOF offset signal
      s_eof_offset_new(r) <= std_logic_vector(unsigned(s_muxed_pkt_len(r)) + (r*REGION_SIZE*BLOCK_SIZE) + unsigned(s_sof_pos_ext(r)));

      -- create signal with previous EOF offset signal
      -- index are shifted by one: index 0 is EOF offset from last region of previous word,
      -- index 1 is EOF offset from first region of current word,...
      s_eof_offset_prev(r+1) <= s_eof_offset_new(r) when (s_set_sof_possible(r) = '1') else s_eof_offset_prev(r);

      -- unpack current EOF offset to word and region part
      s_eof_offset_prev_word(r)   <= s_eof_offset_prev(r)(LEN_WIDTH-1 downto log2(REGIONS)+EOF_POS_WIDTH);
      s_eof_offset_prev_region(r) <= s_eof_offset_prev(r)(log2(REGIONS)+EOF_POS_WIDTH-1 downto EOF_POS_WIDTH);
      s_region_full(r) <= and s_eof_offset_prev(r)(EOF_POS_WIDTH-1 downto BLOCK_WIDTH);

      -- checking if the position matches the EOF offset
      s_eof_prev_word_ok(r)   <= '1' when (unsigned(s_eof_offset_prev_word(r)) = unsigned(s_word_cnt(r))) else '0';
      s_eof_prev_region_ok(r) <= '1' when (REGIONS = 1) or (unsigned(s_eof_offset_prev_region(r)) = to_unsigned(r,log2(REGIONS))) else '0';
      s_eof_prev_ok(r)        <= s_eof_prev_word_ok(r) and s_eof_prev_region_ok(r);

      -- the current EOF offset
      s_eof_offset_curr(r) <= s_muxed_pkt_len(r);
      s_eof_offset_curr_regions(r) <= s_eof_offset_curr(r)(LEN_WIDTH-1 downto EOF_POS_WIDTH);
      s_eof_curr_ok(r) <= '1' when (unsigned(s_eof_offset_curr_regions(r)) = 0) else '0';

      s_set_sof(r) <= s_muxed_pkt_gen(r) and (not s_need_set_eof(r) or (s_need_set_eof(r) and s_eof_prev_ok(r) and not s_region_full(r)));
      s_set_eof(r) <= (s_need_set_eof(r) and s_eof_prev_ok(r)) or (not s_need_set_eof(r) and s_eof_curr_ok(r) and s_muxed_pkt_gen(r));

      s_set_sof_possible(r) <= (not s_need_set_eof(r)) or (s_need_set_eof(r) and s_eof_prev_ok(r));

      -- control of creating EOF signal 
      s_need_set_eof(r+1) <='1' when ((s_set_sof(r) = '1' and s_set_eof(r) = '0') or (s_set_sof(r) = '1' and s_set_eof(r) = '1' and s_need_set_eof(r) = '1')) else
                            '0' when (s_set_eof(r) = '1') else s_need_set_eof(r);

      s_sof_pos(r) <= (others => '1') when (s_need_set_eof(r) = '1') else (others => '0');
      s_eof_pos(r) <= s_eof_offset_prev(r)(EOF_POS_WIDTH-1 downto 0) when (s_need_set_eof(r) = '1') else s_eof_offset_curr(r)(EOF_POS_WIDTH-1 downto 0);

      s_tx_sof(r)     <= s_set_sof(r);
      s_tx_eof(r)     <= s_set_eof(r);
      s_tx_sof_pos(r) <= s_sof_pos(r);
      s_tx_eof_pos(r) <= s_eof_pos(r);
   end generate;

   -- create valid (source ready) of output MFB
   s_tx_src_rdy <= (or s_tx_sof) or s_need_set_eof(0);

   fifo_pkt_ack_p : process (s_tx_sof)
      variable var_cnt    : integer range 0 to REGIONS;
      variable var_accept : std_logic_vector(REGIONS-1 downto 0);
   begin
      var_accept := (others => '0');
      var_cnt := 0;
      temp_or : for r in 0 to REGIONS-1 loop
         if (s_tx_sof(r) = '1') then
            var_accept(var_cnt) := '1';
            var_cnt := var_cnt + 1;
         end if;
      end loop;
      s_fifo_pkt_ack <= var_accept;
   end process;

   -----------------------------------------------------------------------------
   -- OUTPUT REGISTERS
   -----------------------------------------------------------------------------

   -- Data are force GND.
   TX_DATA <= (others => '0');

   tx_reg_p : process (CLK)
   begin
      if (rising_edge(CLK)) then
         if (TX_DST_RDY = '1') then
            TX_SOF_POS <= slv_array_ser(s_tx_sof_pos,REGIONS,SOF_POS_WIDTH);
            TX_EOF_POS <= slv_array_ser(s_tx_eof_pos,REGIONS,EOF_POS_WIDTH);
            TX_SOF     <= s_tx_sof;
            TX_EOF     <= s_tx_eof;
         end if;
      end if;
   end process;

   tx_vld_reg_p : process (CLK)
   begin
      if (rising_edge(CLK)) then
         if (RESET = '1') then
            TX_SRC_RDY <= '0';
         elsif (TX_DST_RDY = '1') then
            TX_SRC_RDY <= s_tx_src_rdy;
         end if;
      end if;
   end process;

end architecture;
