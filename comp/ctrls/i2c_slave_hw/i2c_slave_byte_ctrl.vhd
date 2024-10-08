-- i2c_slave_byte_ctrl.vhd: Byte slave controller of I2C bus
-- Copyright (C) 2010 CESNET
-- Author(s): Viktor Puš <pus@liberouter.org>
--
-- SPDX-License-Identifier: BSD-3-Clause
--
-- $Id$
--
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity i2c_slave_byte_ctrl is
   generic (
      FILTER_LENGTH  : integer := 4;
      FILTER_SAMPLING: integer := 2
   );
   port (
      CLK      : in std_logic;
      RESET    : in std_logic;

      --* Command code input
      CMD      : in  std_logic_vector(1 downto 0);
      --* Data word if command is reply
      DIN      : in  std_logic_vector(7 downto 0);
      --* Device address to be checked
      DEV_ADDR : in  std_logic_vector(7 downto 0);
      --* Device address mask (1=bit masked)
      DEV_ADDR_MASK:in  std_logic_vector(7 downto 0);
      --* ACK value at the end of byte if CMD was ACCEPT, and the recieved byte
      --* matched DEV_ADDR with DEV_ADDR_MASK. If byte didn't match, no ACK
      --* will be generated.
      ACK_IN   : in  std_logic;
      --* Command valid (pulse)
      CMD_VLD  : in  std_logic;
      --* Ready to accept command
      CMD_RDY  : out std_logic;

      --* Command done (pulse)
      CMD_ACK  : out std_logic; -- command done
      --* The word had ACK, NACK otherwise (if ACK wasn't generated by myself)
      ACK_OUT  : out std_logic;
      --* Data word if command was accept
      DOUT     : out std_logic_vector(7 downto 0);

      --* START condidion detected (pulse)
      START    : out std_logic;
      --* STOP condidion detected (pulse)
      STOP     : out std_logic;

      --+ i2c lines
      SCL_I   : in  std_logic;  -- i2c clock line input
      SCL_O   : out std_logic; -- i2c clock line output
      SCL_OEN : out std_logic; -- i2c clock line output enable, active low
      SDA_I   : in  std_logic;  -- i2c data line input
      SDA_O   : out std_logic; -- i2c data line output
      SDA_OEN : out std_logic  -- i2c data line output enable, active low
   );
end entity i2c_slave_byte_ctrl;

architecture structural of i2c_slave_byte_ctrl is

   constant I2C_ACCEPT_BYTE      : std_logic_vector(1 downto 0) := "01";
   constant I2C_REPLY_BYTE       : std_logic_vector(1 downto 0) := "10";

   constant I2C_ACCEPT_BIT       : std_logic_vector(1 downto 0) := "01";
   constant I2C_REPLY_BIT        : std_logic_vector(1 downto 0) := "10";

   signal iCMD_RDY         : std_logic;

   -- IN = from design to I2C slave controller
   signal shreg_din        : std_logic_vector(7 downto 0);
   signal shreg_din_sh     : std_logic;
   signal reg_ack_in       : std_logic;
   signal reg_dev_addr     : std_logic_vector(7 downto 0);
   signal reg_dev_addr_mask: std_logic_vector(7 downto 0);

   -- OUT = from I2C controller to design
   signal shreg_dout       : std_logic_vector(7 downto 0);
   signal shreg_dout_we    : std_logic;

   -- Bit controller signals
   signal core_cmd         : std_logic_vector(1 downto 0);
   signal core_cmd_vld     : std_logic;
   signal core_cmd_rdy     : std_logic;
   signal core_din         : std_logic;
   signal core_ack         : std_logic;
   signal core_dout        : std_logic;
   signal core_start       : std_logic;
   signal core_stop        : std_logic;

   -- Data counter
   signal dcnt             : std_logic_vector(2 downto 0);
   signal dcnt_ld          : std_logic;
   signal dcnt_en          : std_logic;

   -- FSM
   type states is (st_idle, st_read, st_read_cmd, st_write,
                   st_write_cmd, st_ack, st_read_ack_cmd, st_write_ack_cmd);
   signal state            : states;
   signal next_state       : states;

begin

   --* Store input command, reply byte shift register
   shreg_din_p : process(CLK)
   begin
      if CLK'event and CLK = '1' then
         if iCMD_RDY = '1' and CMD_VLD = '1' then
            shreg_din      <= DIN;
            reg_ack_in     <= ACK_IN;
            reg_dev_addr   <= DEV_ADDR;
            reg_dev_addr_mask<=DEV_ADDR_MASK;
         elsif shreg_din_sh = '1' then
            shreg_din(7 downto 1) <= shreg_din(6 downto 0);
         end if;
      end if;
   end process;

   --* accept byte shift register
   shift_register: process(CLK)
   begin
      if (CLK'event and CLK = '1') then
         if (shreg_dout_we = '1') then
            shreg_dout <= shreg_dout(6 downto 0) & core_dout;
         end if;
      end if;
   end process shift_register;

   DOUT <= SHREG_DOUT;

	--* bit controller instantion
	bit_ctrl: entity work.i2c_slave_bit_ctrl
   generic map(
      FILTER_LENGTH  => FILTER_LENGTH,
      FILTER_SAMPLING=> FILTER_SAMPLING
   )
   port map(
		CLK     => CLK,
		RESET   => RESET,

		CMD     => core_cmd,
		DIN     => core_din,
      CMD_VLD => core_cmd_vld,
      CMD_RDY => core_cmd_rdy,

		CMD_ACK => core_ack,
		DOUT    => core_dout,

      START   => core_start,
      STOP    => core_stop,

		SCL_I   => SCL_I,
		SCL_O   => SCL_O,
		SCL_OEN => SCL_OEN,
		SDA_I   => SDA_I,
		SDA_O   => SDA_O,
		SDA_OEN => SDA_OEN
	);
	START   <= core_start;
   STOP    <= core_stop;
   ACK_OUT <= core_dout;

   --* data counter
   data_cnt: process(CLK)
   begin
      if (CLK'event and CLK = '1') then
         if (RESET = '1') then
           dcnt <= (others => '0');
         else
            if (dcnt_ld = '1') then
               dcnt <= (others => '1');  -- load counter with 7
            elsif (dcnt_en = '1') then
               dcnt <= dcnt -1;
            end if;
         end if;
      end if;
   end process data_cnt;

   --* FSM state memory
   state_reg_p : process(CLK)
   begin
      if CLK'event and CLK = '1' then
         if RESET = '1' or core_start = '1' then
            -- START also resets the controller!
            state <= st_idle;
         else
            state <= next_state;
         end if;
      end if;
   end process;

   --* Next state computation
   next_state_p : process(state, CMD, CMD_VLD, iCMD_RDY, core_start,
                          dcnt, core_ack, core_dout, core_cmd_rdy,
                          reg_dev_addr, reg_dev_addr_mask, shreg_dout)
   begin
      next_state <= state; -- Stay in current state by default

      case state is
         when st_idle =>
            if (CMD_VLD = '1') and (iCMD_RDY = '1') then
               if CMD = I2C_ACCEPT_BYTE then
                  next_state <= st_read_cmd;
               end if;
               if CMD = I2C_REPLY_BYTE then
                  next_state <= st_write_cmd;
               end if;
            end if;

         -- Issue read command
         when st_read_cmd =>
            if core_cmd_rdy = '1' then
               next_state <= st_read;
            end if;

         -- Wait for read command to complete
         when st_read =>
            if core_ack = '1' then
               if dcnt = "111" then
                  if ((not((shreg_dout(6 downto 0) & core_dout)
                           xor reg_dev_addr))
                      or reg_dev_addr_mask) = "11111111" then
                     next_state <= st_write_ack_cmd; -- Addres match
                  else
                     next_state <= st_read_ack_cmd; -- No address match
                  end if;
               else
                  next_state <= st_read_cmd;
               end if;
            end if;

         -- Issue write command
         when st_write_cmd =>
            if core_cmd_rdy = '1' then
               next_state <= st_write;
            end if;

         -- Wait for write command to complete
         when st_write =>
            if core_ack = '1' then
               if dcnt = "111" then
                  next_state <= st_read_ack_cmd;
               else
                  next_state <= st_write_cmd;
               end if;
            end if;

         -- Issue read command (ACK bit)
         when st_read_ack_cmd =>
            if core_cmd_rdy = '1' then
               next_state <= st_ack;
            end if;

         -- Issue write command (ACK bit)
         when st_write_ack_cmd =>
            if core_cmd_rdy = '1' then
               next_state <= st_ack;
            end if;

         -- Wait for command to complete
         when st_ack =>
            if core_ack = '1' then
               next_state <= st_idle;
            end if;

         when others =>
      end case;
   end process;

   -- FSM output logic
   output_logic_p : process(state, core_ack, core_cmd_rdy, dcnt, shreg_din,
                            reg_ack_in)
   begin
      dcnt_en <= '0';
      dcnt_ld <= '0';
      core_cmd <= I2C_ACCEPT_BIT;
      core_cmd_vld <= '0';
      core_din <= '1';
      shreg_din_sh <= '0';
      shreg_dout_we <= '0';
      CMD_ACK <= '0';
      iCMD_RDY <= '0';

      case state is
         when st_idle =>
            iCMD_RDY <= '1';
            dcnt_ld <= '1';

         when st_read_cmd =>
            core_cmd <= I2C_ACCEPT_BIT;
            core_cmd_vld <= '1';
            if core_cmd_rdy = '1' then
               dcnt_en <= '1';
            end if;

         when st_read =>
            if core_ack = '1' then
               shreg_dout_we <= '1';
            end if;

         when st_write_cmd =>
            core_cmd <= I2C_REPLY_BIT;
            core_din <= shreg_din(7);
            core_cmd_vld <= '1';
            if core_cmd_rdy = '1' then
               shreg_din_sh <= '1';
               dcnt_en <= '1';
            end if;

         when st_write =>

         when st_write_ack_cmd =>
            core_cmd <= I2C_REPLY_BIT;
            core_din <= reg_ack_in;
            core_cmd_vld <= '1';

         when st_read_ack_cmd =>
            core_CMD <= I2C_ACCEPT_BIT;
            core_cmd_vld <= '1';

         when st_ack =>
            if core_ack = '1' then
               CMD_ACK <= '1';
            end if;

         when others =>
      end case;
   end process;

   CMD_RDY <= iCMD_RDY;

end architecture structural;

