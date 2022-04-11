-- ptc_mfb2pcie_axi.vhd: MFB to PCIE AXI convertor
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

entity PTC_MFB2PCIE_AXI is
   generic(
      -- =======================================================================
      -- Target device specification
      -- =======================================================================
      -- Supported devices: "7SERIES", "ULTRASCALE"
      DEVICE           : string  := "ULTRASCALE";
      -- =======================================================================
      -- MFB BUS CONFIGURATION: 
      -- =======================================================================
      -- Supported configuration is MFB(2,1,8,32) for PCIe on UltraScale+
      -- Supported configuration is MFB(1,1,8,32) for PCIe on Virtex 7 Series
      MFB_REGIONS      : natural := 2;
      MFB_REGION_SIZE  : natural := 1;
      MFB_BLOCK_SIZE   : natural := 8;
      MFB_ITEM_WIDTH   : natural := 32;
      -- =======================================================================
      -- AXI BUS CONFIGURATION: 
      -- =======================================================================
      -- DATA=512, RQ=137 for Gen3x16 PCIe (Virtex UltraScale+) - with straddling!
      -- DATA=256, RQ=60  for Gen3x16 PCIe (Virtex 7 Series) - with straddling!
      AXI_DATA_WIDTH   : natural := 512;
      AXI_RQUSER_WIDTH : natural := 137

      -- UltraScale+ RQ user:
      -- (
      -- TODO
      -- -1 downto 0)

      -- Virtex 7 Series RQ user:
      -- (
      -- MFB_REGOINS*MFB_REG_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH/8      -- parity (zeros)
      -- 4                                                             -- seq num (zeros)
      -- 12                                                            -- tph (zeros)
      -- 1                                                             -- discontinue (error) (zero)
      -- 3                                                             -- Addr Offset (zeros)
      -- (MFB_REGIONS*MFB_REG_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH)/8    -- Last byte Enable
      -- (MFB_REGIONS*MFB_REG_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH)/8    -- First byte Enable
      -- -1 downto 0)
   );
   port(
      -- =======================================================================
      -- CLOCK AND RESET
      -- =======================================================================
      CLK            : in  std_logic;
      RESET          : in  std_logic;
      -- =======================================================================
      -- INPUT MFB INTERFACE
      -- =======================================================================
      RX_MFB_DATA    : in  std_logic_vector(MFB_REGIONS*MFB_REGION_SIZE*MFB_BLOCK_SIZE*MFB_ITEM_WIDTH-1 downto 0);
      RX_MFB_SOF_POS : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE))-1 downto 0);
      RX_MFB_EOF_POS : in  std_logic_vector(MFB_REGIONS*max(1,log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE))-1 downto 0);
      RX_MFB_SOF     : in  std_logic_vector(MFB_REGIONS-1 downto 0);
      RX_MFB_EOF     : in  std_logic_vector(MFB_REGIONS-1 downto 0);
      RX_MFB_SRC_RDY : in  std_logic;
      RX_MFB_DST_RDY : out std_logic;
      -- PCIe transaction length last and first DWORD byte enable (MSB -> last byte, LSB -> first byte)
      RX_MFB_BE      : in  std_logic_vector(MFB_REGIONS*8-1 downto 0);
      -- =======================================================================
      -- OUTPUT AXI REQUESTER REQUEST INTERFACE (RQ)
      -- =======================================================================
      -- Data bus
      RQ_DATA        : out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
      -- Set of signals with sideband information about transferred transaction
      RQ_USER        : out std_logic_vector(AXI_RQUSER_WIDTH-1 downto 0);
      -- Indication of the last word of a transaction
      RQ_LAST        : out std_logic;
      -- Indication of valid data
      -- each bit determines validity of different Dword (1 Dword = 4 Bytes)
      RQ_KEEP        : out std_logic_vector(AXI_DATA_WIDTH/32-1 downto 0);
      -- PCIe core is ready to receive a transaction
      RQ_READY       : in  std_logic;
      -- User application sends valid data
      RQ_VALID       : out std_logic
   );
end PTC_MFB2PCIE_AXI;

architecture FULL of PTC_MFB2PCIE_AXI is

   constant EOF_POS_WIDTH : natural := log2(MFB_REGION_SIZE*MFB_BLOCK_SIZE);

   signal s_rx_mfb_eof_pos_arr : slv_array_t(MFB_REGIONS-1 downto 0)(EOF_POS_WIDTH-1 downto 0);
   signal s_rx_mfb_be_arr      : slv_array_t(MFB_REGIONS-1 downto 0)(8-1 downto 0);

   signal s_rq_last            : std_logic;
   signal s_rq_keep            : std_logic_vector(AXI_DATA_WIDTH/32-1 downto 0);

   signal s_is_sop             : std_logic_vector(1 downto 0);
   signal s_is_sop0_ptr        : std_logic_vector(1 downto 0);
   signal s_is_sop1_ptr        : std_logic_vector(1 downto 0);

   signal s_is_eop             : std_logic_vector(1 downto 0);
   signal s_is_eop0_ptr        : std_logic_vector(3 downto 0);
   signal s_is_eop1_ptr        : std_logic_vector(3 downto 0);

   signal s_first_be0          : std_logic_vector(3 downto 0);
   signal s_last_be0           : std_logic_vector(3 downto 0);

   signal s_first_be1          : std_logic_vector(3 downto 0);
   signal s_last_be1           : std_logic_vector(3 downto 0);

   signal s_first_be           : std_logic_vector(7 downto 0);
   signal s_last_be            : std_logic_vector(7 downto 0);

   signal s_rq_user            : std_logic_vector(AXI_RQUSER_WIDTH-1 downto 0);

begin

   -- --------------------------------------------------------------------------
   --  PREPARE AXI SIGNALS
   -- --------------------------------------------------------------------------

   -- is high when is word with end of packet, in straddle mode is not useful
   s_rq_last <= or RX_MFB_EOF;

   ultrascale_tuser_gen : if DEVICE="ULTRASCALE" generate
      -- create array of end of frame position
      s_rx_mfb_eof_pos_arr <= slv_array_downto_deser(RX_MFB_EOF_POS,MFB_REGIONS,EOF_POS_WIDTH);

      -- create array of byte enables
      s_rx_mfb_be_arr <= slv_array_downto_deser(RX_MFB_BE,MFB_REGIONS,8);

      -- keep in straddle mode is not useful therefore, all bits are set to VCC
      s_rq_keep <= (others => '1');

      -- create SOP flags and pointers for AXI
      s_is_sop(0) <= or RX_MFB_SOF;
      s_is_sop(1) <= and RX_MFB_SOF;
      s_is_sop0_ptr <= "10" when (RX_MFB_SOF = "10") else "00";
      s_is_sop1_ptr <= "10";

      -- create EOP flags and pointers for AXI
      s_is_eop(0) <= or RX_MFB_EOF;
      s_is_eop(1) <= and RX_MFB_EOF;
      s_is_eop0_ptr <= '1' & s_rx_mfb_eof_pos_arr(1) when (RX_MFB_EOF = "10") else '0' & s_rx_mfb_eof_pos_arr(0);
      s_is_eop1_ptr <= '1' & s_rx_mfb_eof_pos_arr(1);

      -- set byte enables for first packet in word
      s_first_be0 <= s_rx_mfb_be_arr(0)(3 downto 0) when RX_MFB_SOF(0) = '1' else s_rx_mfb_be_arr(1)(3 downto 0);
      s_last_be0  <= s_rx_mfb_be_arr(0)(7 downto 4) when RX_MFB_SOF(0) = '1' else s_rx_mfb_be_arr(1)(7 downto 4);

      -- set byte enables for second packet in word
      s_first_be1 <= s_rx_mfb_be_arr(1)(3 downto 0);
      s_last_be1  <= s_rx_mfb_be_arr(1)(7 downto 4);

      -- prepare byte enables for request interface
      s_first_be <= s_first_be1 & s_first_be0;
      s_last_be  <= s_last_be1 & s_last_be0;

      -- create request user signal
      s_rq_user <= (AXI_RQUSER_WIDTH-1 downto 36 => '0') & s_is_eop1_ptr & s_is_eop0_ptr & s_is_eop &
                   s_is_sop1_ptr & s_is_sop0_ptr & s_is_sop & "0000" & s_last_be & s_first_be;
   end generate;

   virtex7series_tuser_gen : if DEVICE="7SERIES" generate
      -- keep signal serves as valid for each DWORD of RQ_DATA signal
      s_rq_keep_pr : process (RX_MFB_EOF,RX_MFB_SRC_RDY,RX_MFB_EOF_POS)
      begin
         if (RX_MFB_SRC_RDY='0') then -- no data
            s_rq_keep <= (others => '0');
         elsif (RX_MFB_EOF(0)='1') then -- end of data
            s_rq_keep <= (others => '0');
            for i in 0 to AXI_DATA_WIDTH/32-1 loop
               s_rq_keep(i) <= '1';
               exit when (i=to_integer(unsigned(RX_MFB_EOF_POS)));
            end loop;
         else -- start or middle of data
            s_rq_keep <= (others => '1');
         end if;
      end process;

      -- create request user signal
      s_rq_user <= (AXI_RQUSER_WIDTH-1 downto 8 => '0') & RX_MFB_BE;
   end generate;

   -- --------------------------------------------------------------------------
   --  AXI SIGNALS ASSIGNMENT
   -- --------------------------------------------------------------------------

   RX_MFB_DST_RDY <= RQ_READY;

   RQ_DATA  <= RX_MFB_DATA;
   RQ_USER  <= s_rq_user;
   RQ_LAST  <= s_rq_last;
   RQ_KEEP  <= s_rq_keep;
   RQ_VALID <= RX_MFB_SRC_RDY;

end architecture;
