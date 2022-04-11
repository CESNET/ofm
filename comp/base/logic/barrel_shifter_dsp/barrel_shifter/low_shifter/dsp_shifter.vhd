-- dsp_shifter.vhd: Barrel shifter with one dsp
-- Copyright (C) 2015 CESNET
-- Author(s): Mario Kuka <xkukam00@stud.fit.vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause
--
-- $Id$
--
-- TODO:
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;
Library UNISIM;
use UNISIM.vcomponents.all;

--! \brief DSP slice ALU entity
entity DSP_SHIFTER is
   generic (
      --! Input pipeline registers (0, 1)
      REG_IN      : integer := 0;
      --! Output pipeline register (0, 1)
      REG_OUT     : integer := 0;
      --! enable cascade input (0, 1)
      EN_CAS_IN   : integer := 0;
      --! enable configure cascade out
      EN_CON_CAS_OUT    : integer := 0;
      UP                : integer   := 0;
      DOWN              : integer := 0
   );
   port (
      --! Clock input
      CLK      : in  std_logic;
      --! Reset input
      RESET    : in  std_logic;
      --! Data input
      A        : in  std_logic_vector(23 downto 0);
      --! Number of shift 
      SHIFT    : in  std_logic_vector(16 downto 0);
      --! cascade out
      OUT_CAS  : out std_logic_vector(15 downto 0);
      --! cascade in
      IN_CAS   : in std_logic_vector(15 downto 0);
      --! Clock enable for input pipeline registers
      CE_IN    : in  std_logic;
      --! Clock enable for output pipeline registers
      CE_OUT   : in  std_logic;
      --! Data output
      P        : out std_logic_vector(23 downto 0)
   );
end DSP_SHIFTER;

--! Vitrex-7 architecture of MUL48
architecture V7_DSP of DSP_SHIFTER is

   --! signals
   signal zeros   : std_logic_vector(63 downto 0);
   signal A_DSP   : std_logic_vector(24 downto 0);
   signal B_DSP   : std_logic_vector(17 downto 0);
   signal P_DSP   : std_logic_vector(47 downto 0);
   signal P_CAS_OUT     : std_logic_vector(47 downto 0);
   signal P_CAS_IN      : std_logic_vector(47 downto 0);
   signal opmode        : std_logic_vector(6 downto 0);

begin  
   zeros <= (others => '0');

   A_DSP <= '0' & A;
   B_DSP <= '0' & SHIFT;
   P <= P_DSP(23 downto 0);

   GEN_NORMAL_CAS_OUT: if(EN_CON_CAS_OUT = 0) generate
      OUT_CAS <= P_CAS_OUT(39 downto 24);
   end generate;
   
   GEN_CON_CAS_OUT: if(EN_CON_CAS_OUT = 1) generate
      OUT_CAS <= P_CAS_OUT(UP downto DOWN);
   end generate;

   P_CAS_IN <= zeros(47 downto 16) & IN_CAS;
   
   GEN_OPMODE_CAS_ON: if(EN_CAS_IN = 1) generate
      opmode <= "0010101";
   end generate;
   
   GEN_OPMODE_CAS_OFF: if(EN_CAS_IN = 0) generate
      opmode <= "0000101";
   end generate;

   --! DSP slice instantion
   DSP48E1_inst : DSP48E1
   generic map (
      -- Feature Control Attributes: Data Path Selection
      A_INPUT => "DIRECT",   -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
      B_INPUT => "DIRECT",   -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
      USE_DPORT => TRUE,     -- Select D port usage (TRUE or FALSE)
      USE_MULT => "DYNAMIC", -- Select multiplier usage ("MULTIPLY", "DYNAMIC", or "NONE")
      -- Pattern Detector Attributes: Pattern Detection Configuration
      AUTORESET_PATDET => "NO_RESET",   -- "NO_RESET", "RESET_MATCH", "RESET_NOT_MATCH" 
      MASK => X"3fffffffffff",          -- 48-bit mask value for pattern detect (1=ignore)
      PATTERN => X"000000000000",       -- 48-bit pattern match for pattern detect
      SEL_MASK => "MASK",               -- "C", "MASK", "ROUNDING_MODE1", "ROUNDING_MODE2" 
      SEL_PATTERN => "PATTERN",         -- Select pattern value ("PATTERN" or "C")
      USE_PATTERN_DETECT => "NO_PATDET",-- Enable pattern detect ("PATDET" or "NO_PATDET")
      -- Register Control Attributes: Pipeline Register Configuration
      ACASCREG => 0,         -- Number of pipeline stages between A/ACIN and ACOUT (0, 1 or 2)
      ADREG => 0,            -- Number of pipeline stages for pre-adder (0 or 1)
      ALUMODEREG => 0,       -- Number of pipeline stages for ALUMODE (0 or 1)
      AREG => 0,             -- Number of pipeline stages for A (0, 1 or 2)
      BCASCREG => 0,         -- Number of pipeline stages between B/BCIN and BCOUT (0, 1 or 2)
      BREG => 0,             -- Number of pipeline stages for B (0, 1 or 2)
      CARRYINREG => 0,       -- Number of pipeline stages for CARRYIN (0 or 1)
      CARRYINSELREG => 0,    -- Number of pipeline stages for CARRYINSEL (0 or 1)
      CREG => 0,             -- Number of pipeline stages for C (0 or 1)
      DREG => REG_IN,        -- Number of pipeline stages for D (0 or 1)
      INMODEREG => 0,        -- Number of pipeline stages for INMODE (0 or 1)
      MREG => 0,             -- Number of multiplier pipeline stages (0 or 1)
      OPMODEREG => 1,        -- Number of pipeline stages for OPMODE (0 or 1)
      PREG => REG_OUT,       -- Number of pipeline stages for P (0 or 1)
      USE_SIMD => "ONE48"    -- SIMD selection ("ONE48", "TWO24", "FOUR12")
   ) port map (
      -- Cascade: 30-bit (each) output: Cascade Ports
      ACOUT => open,                -- 30-bit output: A port cascade output
      BCOUT => open,                -- 18-bit output: B port cascade output
      CARRYCASCOUT => open,         -- 1-bit output: Cascade carry output
      MULTSIGNOUT => open,          -- 1-bit output: Multiplier sign cascade output
      PCOUT => P_CAS_OUT,           -- 48-bit output: Cascade output
      -- Control: 1-bit (each) output: Control Inputs/Status Bits
      OVERFLOW => open,             -- 1-bit output: Overflow in add/acc output
      PATTERNBDETECT => open,       -- 1-bit output: Pattern bar detect output
      PATTERNDETECT => open,        -- 1-bit output: Pattern detect output
      UNDERFLOW => open,            -- 1-bit output: Underflow in add/acc output
      -- Data: 4-bit (each) output: Data Ports
      CARRYOUT => open,             -- 4-bit output: Carry output
      P => P_DSP,                   -- 48-bit output: Primary data output
      -- Cascade: 30-bit (each) input: Cascade Ports
      ACIN => zeros(29 downto 0),   -- 30-bit input: A cascade data input
      BCIN => zeros(17 downto 0),   -- 18-bit input: B cascade input
      CARRYCASCIN => '0',           -- 1-bit input: Cascade carry input
      MULTSIGNIN => '0',            -- 1-bit input: Multiplier sign input
      PCIN => P_CAS_IN,             -- 48-bit input: P cascade input
      -- Control: 4-bit (each) input: Control Inputs/Status Bits
      ALUMODE => "0000",            -- 4-bit input: ALU control input (X XOR Z)
      CARRYINSEL => "000",          -- 3-bit input: Carry select input
      CEINMODE => '1',              -- 1-bit input: Clock enable input for INMODEREG
      CLK => CLK,                   -- 1-bit input: Clock input
      INMODE => "00111",            -- 5-bit input: INMODE control input
      OPMODE => opmode,             -- 7-bit input: Operation mode input
      RSTINMODE => '0',             -- 1-bit input: Reset input for INMODEREG
      -- Data: 30-bit (each) input: Data Ports
      A => zeros(47 downto 18),     -- 30-bit input: A data input
      B => B_DSP(17 downto 0),      -- 18-bit input: B data input
      C => zeros(47 downto 0),      -- 48-bit input: C data input
      CARRYIN => '0',               -- 1-bit input: Carry input signal
      D => A_DSP(24 downto 0),      -- 25-bit input: D data input
      -- Reset/Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
      CEA1 => '1',           -- 1-bit input: Clock enable input for 1st stage AREG
      CEA2 => '1',           -- 1-bit input: Clock enable input for 2nd stage AREG
      CEAD => '1',           -- 1-bit input: Clock enable input for ADREG
      CEALUMODE => '1',      -- 1-bit input: Clock enable input for ALUMODERE
      CEB1 => CE_IN,         -- 1-bit input: Clock enable input for 1st stage BREG
      CEB2 => CE_IN,         -- 1-bit input: Clock enable input for 2nd stage BREG
      CEC => '1',            -- 1-bit input: Clock enable input for CREG
      CECARRYIN => '1',      -- 1-bit input: Clock enable input for CARRYINREG
      CECTRL => '1',         -- 1-bit input: Clock enable input for OPMODEREG and CARRYINSELREG
      CED => CE_IN,          -- 1-bit input: Clock enable input for DREG
      CEM => '1',            -- 1-bit input: Clock enable input for MREG
      CEP => CE_OUT,         -- 1-bit input: Clock enable input for PREG
      RSTA => RESET,         -- 1-bit input: Reset input for AREG
      RSTALLCARRYIN => RESET,-- 1-bit input: Reset input for CARRYINREG
      RSTALUMODE => RESET,   -- 1-bit input: Reset input for ALUMODEREG
      RSTB => RESET,         -- 1-bit input: Reset input for BREG
      RSTC => RESET,         -- 1-bit input: Reset input for CREG
      RSTCTRL => RESET,      -- 1-bit input: Reset input for OPMODEREG and CARRYINSELREG
      RSTD => RESET,         -- 1-bit input: Reset input for DREG and ADREG
      RSTM => RESET,         -- 1-bit input: Reset input for MREG
      RSTP => RESET          -- 1-bit input: Reset input for PREG
   );
end V7_DSP;
