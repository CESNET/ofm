--! dps_pipe_3x48.vhd
--!
--! \file
--! \Author: Mario Kuka <xkukam00@stud.fit.vutbr.cz>
--!
--! \section License
--!
--! Copyright (C) 2015 CESNET
--!
--! SPDX-License-Identifier: BSD-3-Clause
--!

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;
Library UNISIM;
use UNISIM.vcomponents.all;

--! \brief DSP slice ALU entity
entity DSP_PIPE_3x48 is
   generic (
      --! number of registers, max 3
      NUM_REGS : integer := 1
   );
   port (
      --! Clock input
      CLK      : in  std_logic;
      --! Reset input
      RESET    : in  std_logic;
      --! clock enbale for registres
      CE       : in std_logic;
      --! input data
      DATA_IN  : in std_logic_vector(47 downto 0);
      --! output data
      DATA_OUT : out std_logic_vector(47 downto 0)
   );
end entity;

architecture full of DSP_PIPE_3x48 is
   --! signals
   signal zeros      : std_logic_vector(63 downto 0);
begin  

   zeros <= X"0000000000000000";

   --! DSP slice instantion
   DSP48E1_inst : DSP48E1
   generic map (
      -- Feature Control Attributes: Data Path Selection
      A_INPUT => "DIRECT",   -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
      B_INPUT => "DIRECT",   -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
      USE_DPORT => TRUE,     -- Select D port usage (TRUE or FALSE)
      USE_MULT => "NONE",    -- Select multiplier usage ("MULTIPLY", "DYNAMIC", or "NONE")
      -- Pattern Detector Attributes: Pattern Detection Configuration
      AUTORESET_PATDET => "NO_RESET",  -- "NO_RESET", "RESET_MATCH", "RESET_NOT_MATCH" 
      MASK => X"000000000000",         -- 48-bit mask value for pattern detect (1=ignore)
      PATTERN => X"000000000000",      -- 48-bit pattern match for pattern detect
      SEL_MASK => "MASK",              -- "C", "MASK", "ROUNDING_MODE1", "ROUNDING_MODE2" 
      SEL_PATTERN => "PATTERN",              -- Select pattern value ("PATTERN" or "C")
      USE_PATTERN_DETECT => "NO_PATDET",     -- Enable pattern detect ("PATDET" or "NO_PATDET")
      -- Register Control Attributes: Pipeline Register Configuration
      ACASCREG => ((NUM_REGS mod 4) - 1),    -- Number of pipeline stages between A/ACIN and ACOUT (0, 1 or 2)
      ADREG => 0,                            -- Number of pipeline stages for pre-adder (0 or 1)
      ALUMODEREG => 0,                       -- Number of pipeline stages for ALUMODE (0 or 1)
      AREG => ((NUM_REGS mod 4) - 1),        -- Number of pipeline stages for A (0, 1 or 2)
      BCASCREG => ((NUM_REGS mod 4) - 1),    -- Number of pipeline stages between B/BCIN and BCOUT (0, 1 or 2)
      BREG => ((NUM_REGS mod 4) - 1),        -- Number of pipeline stages for B (0, 1 or 2)
      CARRYINREG => 0,       -- Number of pipeline stages for CARRYIN (0 or 1)
      CARRYINSELREG => 0,    -- Number of pipeline stages for CARRYINSEL (0 or 1)
      CREG => 0,             -- Number of pipeline stages for C (0 or 1)
      DREG => 0,             -- Number of pipeline stages for D (0 or 1)
      INMODEREG => 0,        -- Number of pipeline stages for INMODE (0 or 1)
      MREG => 0,             -- Number of multiplier pipeline stages (0 or 1)
      OPMODEREG => 0,        -- Number of pipeline stages for OPMODE (0 or 1)
      PREG => NUM_REGS/NUM_REGS,             -- Number of pipeline stages for P (0 or 1)
      USE_SIMD => "ONE48"    -- SIMD selection ("ONE48", "TWO24", "FOUR12")
   ) port map (
      -- Cascade: 30-bit (each) output: Cascade Ports
      ACOUT => open,                -- 30-bit output: A port cascade output
      BCOUT => open,                -- 18-bit output: B port cascade output
      CARRYCASCOUT => open,         -- 1-bit output: Cascade carry output
      MULTSIGNOUT => open,          -- 1-bit output: Multiplier sign cascade output
      PCOUT => open,                -- 48-bit output: Cascade output
      -- Control: 1-bit (each) output: Control Inputs/Status Bits
      OVERFLOW => open,             -- 1-bit output: Overflow in add/acc output
      PATTERNBDETECT => open,       -- 1-bit output: Pattern bar detect output
      PATTERNDETECT => open,        -- 1-bit output: Pattern detect output
      UNDERFLOW => open,            -- 1-bit output: Underflow in add/acc output
      -- Data: 4-bit (each) output: Data Ports
      CARRYOUT => open,             -- 4-bit output: Carry output
      P => DATA_OUT,                -- 48-bit output: Primary data output
      -- Cascade: 30-bit (each) input: Cascade Ports
      ACIN => zeros(29 downto 0),   -- 30-bit input: A cascade data input
      BCIN => zeros(17 downto 0),   -- 18-bit input: B cascade input
      CARRYCASCIN => '0',           -- 1-bit input: Cascade carry input
      MULTSIGNIN => '0',            -- 1-bit input: Multiplier sign input
      PCIN => zeros(47 downto 0),   -- 48-bit input: P cascade input
      -- Control: 4-bit (each) input: Control Inputs/Status Bits
      ALUMODE => "0000",            -- 4-bit input: ALU control input (X XOR Z)
      CARRYINSEL => "000",          -- 3-bit input: Carry select input
      CEINMODE => '1',              -- 1-bit input: Clock enable input for INMODEREG
      CLK => CLK,                   -- 1-bit input: Clock input
      INMODE => "00000",            -- 5-bit input: INMODE control input
      OPMODE => "0000011",          -- 7-bit input: Operation mode input
      RSTINMODE => '0',             -- 1-bit input: Reset input for INMODEREG
      -- Data: 30-bit (each) input: Data Ports
      A => DATA_IN(47 downto 18),   -- 30-bit input: A data input
      B => DATA_IN(17 downto 0),    -- 18-bit input: B data input
      C => zeros(47 downto 0),      -- 48-bit input: C data input
      CARRYIN => '0',               -- 1-bit input: Carry input signal
      D => zeros(24 downto 0),      -- 25-bit input: D data input
      -- Reset/Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
      CEA1 => CE,             -- 1-bit input: Clock enable input for 1st stage AREG
      CEA2 => CE,             -- 1-bit input: Clock enable input for 2nd stage AREG
      CEAD => '1',            -- 1-bit input: Clock enable input for ADREG
      CEALUMODE => '1',       -- 1-bit input: Clock enable input for ALUMODERE
      CEB1 => CE,             -- 1-bit input: Clock enable input for 1st stage BREG
      CEB2 => CE,             -- 1-bit input: Clock enable input for 2nd stage BREG
      CEC => '1',             -- 1-bit input: Clocik enable input for CREG
      CECARRYIN => '1',       -- 1-bit input: Clock enable input for CARRYINREG
      CECTRL => '1',          -- 1-bit input: Clock enable input for OPMODEREG and CARRYINSELREG
      CED => '1',             -- 1-bit input: Clock enable input for DREG
      CEM => '1',             -- 1-bit input: Clock enable input for MREG
      CEP => CE,              -- 1-bit input: Clock enable input for PREG
      RSTA => RESET,          -- 1-bit input: Reset input for AREG
      RSTALLCARRYIN => RESET, -- 1-bit input: Reset input for CARRYINREG
      RSTALUMODE => RESET,    -- 1-bit input: Reset input for ALUMODEREG
      RSTB => RESET,          -- 1-bit input: Reset input for BREG
      RSTC => RESET,          -- 1-bit input: Reset input for CREG
      RSTCTRL => RESET,       -- 1-bit input: Reset input for OPMODEREG and CARRYINSELREG
      RSTD => RESET,          -- 1-bit input: Reset input for DREG and ADREG
      RSTM => RESET,          -- 1-bit input: Reset input for MREG
      RSTP => RESET           -- 1-bit input: Reset input for PREG
   );
end architecture;
