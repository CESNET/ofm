-- mfb_fork.vhd: Fork component for MFB
-- Copyright (C) 2019 CESNET z. s. p. o.
-- Author(s): Lukas Kekely <kekely@cesnet.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_misc.all;
use work.math_pack.all;



entity MFB_FORK is
  generic(
    OUTPUT_PORTS   : integer := 2; -- any possitive value
    -- Frame size restrictions: none
    REGIONS        : integer := 4; -- any possitive value
    REGION_SIZE    : integer := 8; -- any possitive value
    BLOCK_SIZE     : integer := 8; -- any possitive value
    ITEM_WIDTH     : integer := 8; -- any possitive value
    META_WIDTH     : integer := 0; -- any possitive value
    USE_DST_RDY    : boolean := true;
    VERSION        : string := "logic"
      -- Do not care when USE_DST_RDY is false.
      -- "logic"    - Fork waits with each word for all TX ports to set DST_RDY in the same cycle. Pure logic implementation.
      -- "register" - Fork can send each word independently to each TX port as soon as they are ready. Registers are used to store some flags, but logic functions are simpler for larger forks.
      -- "simple"   - Same behaviour as "logic", but using simpler logic on SRC_RDY and DST_RDY with a potencial of logic loop creation. USE WITH CARE!
  );
  port(
    CLK            : in std_logic;
    RESET          : in std_logic;

    RX_DATA       : in std_logic_vector(REGIONS*REGION_SIZE*BLOCK_SIZE*ITEM_WIDTH-1 downto 0);
    RX_META       : in std_logic_vector(REGIONS*META_WIDTH-1 downto 0) := (others => '0');
    RX_SOF_POS    : in std_logic_vector(REGIONS*max(1,log2(REGION_SIZE))-1 downto 0);
    RX_EOF_POS    : in std_logic_vector(REGIONS*max(1,log2(REGION_SIZE*BLOCK_SIZE))-1 downto 0);
    RX_SOF        : in std_logic_vector(REGIONS-1 downto 0);
    RX_EOF        : in std_logic_vector(REGIONS-1 downto 0);
    RX_SRC_RDY    : in std_logic;
    RX_DST_RDY    : out std_logic;

    TX_DATA       : out std_logic_vector(OUTPUT_PORTS*REGIONS*REGION_SIZE*BLOCK_SIZE*ITEM_WIDTH-1 downto 0);
    TX_META       : out std_logic_vector(OUTPUT_PORTS*REGIONS*META_WIDTH-1 downto 0);
    TX_SOF_POS    : out std_logic_vector(OUTPUT_PORTS*REGIONS*max(1,log2(REGION_SIZE))-1 downto 0);
    TX_EOF_POS    : out std_logic_vector(OUTPUT_PORTS*REGIONS*max(1,log2(REGION_SIZE*BLOCK_SIZE))-1 downto 0);
    TX_SOF        : out std_logic_vector(OUTPUT_PORTS*REGIONS-1 downto 0);
    TX_EOF        : out std_logic_vector(OUTPUT_PORTS*REGIONS-1 downto 0);
    TX_SRC_RDY    : out std_logic_vector(OUTPUT_PORTS-1 downto 0);
    TX_DST_RDY    : in std_logic_vector(OUTPUT_PORTS-1 downto 0)
  );
end entity;



architecture arch of MFB_FORK is

  constant DATA_WIDTH : integer := REGIONS*REGION_SIZE*BLOCK_SIZE*ITEM_WIDTH;
  constant SOF_POS_WIDTH : integer := REGIONS*max(1,log2(REGION_SIZE));
  constant EOF_POS_WIDTH : integer := REGIONS*max(1,log2(REGION_SIZE*BLOCK_SIZE));

begin

  -- Data forking
  base_fork_gen: for i in 1 to OUTPUT_PORTS generate
    TX_DATA(i*DATA_WIDTH-1 downto (i-1)*DATA_WIDTH)<= RX_DATA;
    TX_META(i*REGIONS*META_WIDTH-1 downto (i-1)*REGIONS*META_WIDTH)<= RX_META;
    TX_SOF_POS(i*SOF_POS_WIDTH-1 downto (i-1)*SOF_POS_WIDTH)<= RX_SOF_POS;
    TX_EOF_POS(i*EOF_POS_WIDTH-1 downto (i-1)*EOF_POS_WIDTH)<= RX_EOF_POS;
    TX_SOF(i*REGIONS-1 downto (i-1)*REGIONS)<= RX_SOF;
    TX_EOF(i*REGIONS-1 downto (i-1)*REGIONS)<= RX_EOF;
  end generate;


  -- Control forking
  no_dst_rdy_gen: if not USE_DST_RDY generate
    TX_SRC_RDY <= (others => RX_SRC_RDY);
  end generate;

  logic_fork_gen: if USE_DST_RDY and VERSION="logic" generate
    RX_DST_RDY <= and_reduce(TX_DST_RDY);
    port_gen: for i in 0 to OUTPUT_PORTS-1 generate
      signal ready_base : std_logic_vector(OUTPUT_PORTS-1 downto 0);
    begin
      process(RX_SRC_RDY,TX_DST_RDY)
      begin
        ready_base <= TX_DST_RDY;
        ready_base(i) <= RX_SRC_RDY; -- do not care about this TX port's DST_RDY to prevent logic loops, but care about SRC_RDY from RX
      end process;
      TX_SRC_RDY(i) <= and_reduce(ready_base);
    end generate;
  end generate;

  register_fork_generate: if USE_DST_RDY and VERSION="register" generate
    signal dst_rdy : std_logic;
    signal send_reg, src_rdy : std_logic_vector(OUTPUT_PORTS-1 downto 0);
  begin
    RX_DST_RDY <= dst_rdy;
    TX_SRC_RDY <= src_rdy;
    dst_rdy <= and_reduce(TX_DST_RDY or send_reg);
    src_rdy <= (OUTPUT_PORTS-1 downto 0 => RX_SRC_RDY) and not send_reg;
    send_register: process(CLK)
    begin
      if CLK'event and CLK='1' then
        if RESET='1' or dst_rdy='1' then
          send_reg <= (others => '0');
        else
          send_reg <= send_reg or (src_rdy and TX_DST_RDY);
        end if;
      end if;
    end process;
  end generate;

  simple_fork_gen: if USE_DST_RDY and VERSION="simple" generate
    signal fork_ready : std_logic;
  begin
    fork_ready <= RX_SRC_RDY and and_reduce(TX_DST_RDY);
    RX_DST_RDY <= fork_ready;
    TX_SRC_RDY <= (others => fork_ready);
  end generate;

end architecture;
