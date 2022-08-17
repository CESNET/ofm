-- addr_manager_ent.vhd: manage free space and addres for pcie transactions
-- Copyright (c) 2022 CESNET z.s.p.o.
-- Author(s): Radek Iša <isa@cesnet.cz>, Vladislav Valek <xvalek14@vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-CLause

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.math_pack.all;
use work.type_pack.all;

architecture FULL of ADDR_MANAGER is

    signal hw_pointers_reg : u_array_t (0 to CHANNELS-1)(POINTER_WIDTH-1 downto 0);
    signal hw_pointer_wr   : std_logic;
    signal hw_pointer_new  : unsigned(POINTER_WIDTH-1 downto 0);
    signal hw_offset       : unsigned(ADDR_WIDTH-1 downto 0);

    signal channel_act_reg     : unsigned(log2(CHANNELS)-1 downto 0);
    signal channel_act_vld_reg : std_logic;

    signal packet_vld  : std_logic;
    signal packet_next : std_logic;

begin



    --=====================================================================
    -- HW pointers
    --=====================================================================
    -- stores the HW pointers internally
    hw_pointers_reg_p : process(CLK)
    begin
        if (rising_edge(CLK)) then
            for IT in 0 to CHANNELS-1 loop

                -- HW pointer is reset after request for channel start has arrived
                if (CHANNEL_RESET(IT) = '1') then

                    hw_pointers_reg(IT) <= (others => '0');

                elsif (hw_pointer_wr = '1' and channel_act_reg = to_unsigned(IT, log2(CHANNELS))) then

                    hw_pointers_reg(IT) <= hw_pointer_new;

                end if;
            end loop;
        end if;
    end process;

    -- TODO :  IN FUTURE if channel num is bigger then we can save some resource with using MEM instead registers
    --hw_pointers : entity  work.sdp_memx
    --generic map (
    --
    --)
    --port map (
    --    CLK   => CLK,
    --    RESET => RESET,
    --    --write
    --    WR_DATA => hw_pointer_data_wr,
    --    WR_ADDR => hw_pointer_channel_wr,
    --    WR_EN   => hw_pointer_en,
    --    --read
    --    RD
    --);

    --=====================================================================
    -- STORE CHANNEL
    --=====================================================================
    channel_act_p : process(CLK)
    begin
        if (rising_edge(CLK)) then

            if (RESET = '1') then

                channel_act_vld_reg <= '0';
                channel_act_reg     <= (others => '0');

            -- awaits for the instruction to process the next packet
            elsif(packet_next = '1') then

                channel_act_vld_reg <= CHANNEL_VLD;
                channel_act_reg     <= unsigned(CHANNEL);

            end if;
        end if;
    end process;

    ADDR_CHANNEL <= CHANNEL when packet_next = '1' else std_logic_vector(channel_act_reg);

    -- writing new values of the HW pointer for the specific channel
    hw_pointer_wr  <= packet_vld;
    -- increment by 1 thus the pointer points to the next block and mask the pointer bits so the pointer would not
    -- overflow
    hw_pointer_new <= unsigned(std_logic_vector(hw_pointers_reg(to_integer(channel_act_reg)) + 1) and ADDR_MASK);

    -- channel_act_vld_reg asserts only if the input CHANNEL_VLD asserts too, for the output address to be valid,
    -- the HW pointer must not match the SW pointer
    packet_vld  <= '1' when channel_act_vld_reg = '1' and hw_pointer_new /= unsigned(ADDR_SW_POINTER) else '0';

    -- the components accepts a new packet either when the processing of the previous has been finished or the
    -- component is in the idle state
    packet_next <= '1' when packet_vld = '1' or channel_act_vld_reg = '0'                             else '0';

    ADDR     <= std_logic_vector(unsigned(ADDR_BASE) + hw_offset);
    OFFSET   <= std_logic_vector(hw_pointers_reg(to_integer(channel_act_reg)));
    ADDR_VLD <= packet_vld;

    POINTER_UPDATE_CHAN <= std_logic_vector(channel_act_reg);
    POINTER_UPDATE_DATA <= std_logic_vector(hw_pointer_new);
    POINTER_UPDATE_EN   <= packet_vld;

    --=============================================================================================================
    -- Addr offset calculation according to the BLOCK_SIZE setting
    --=============================================================================================================
    check_data_alignment_g : if 2**log2(BLOCK_SIZE) = BLOCK_SIZE generate
    begin

        -- assumes addresing to bytes, the new value of the pointer is shifted according to the current BLOCK_SIZE
        -- setting
        hw_offset <=
            (ADDR_WIDTH-1 downto POINTER_WIDTH +log2(BLOCK_SIZE) => '0')
            & hw_pointers_reg(to_integer(channel_act_reg))
            & (log2(BLOCK_SIZE)-1 downto 0 => '0');

    else generate
        signal hw_pointers_offset_reg : u_array_t (0 to CHANNELS-1)(POINTER_WIDTH + log2(BLOCK_SIZE)-1 downto 0);
    begin
        assert (2**log2(BLOCK_SIZE) = BLOCK_SIZE)
            report "ERROR: BLOCK_SIZE which is not power of two is not supported yet actual block size is " & integer'image(BLOCK_SIZE) & ". If you want to try on your own risk, delete this assert"
            severity FAILURE;

        hw_pointers_offsets : process(CLK)
        begin
            if (rising_edge(CLK)) then
                for IT in 0 to CHANNELS-1 loop
                    -- reset is not required because cannel have to be stopped after reset
                    if (CHANNEL_RESET(IT) = '1') then
                        hw_pointers_offset_reg(IT) <= (others => '0');
                    elsif (hw_pointer_wr = '1' and channel_act_reg = to_unsigned(IT, log2(CHANNELS))) then
                        if (hw_pointer_new = 0) then
                            hw_pointers_offset_reg(IT) <= (others => '0');
                        else
                            hw_pointers_offset_reg(IT) <= hw_pointers_offset_reg(IT) + BLOCK_SIZE;
                        end if;
                    end if;
                end loop;
            end if;
        end process;

        hw_offset <= (ADDR_WIDTH-1 downto POINTER_WIDTH-log2(BLOCK_SIZE) => '0') & hw_pointers_offset_reg(to_integer(channel_act_reg));
    end generate;
    --=============================================================================================================

end architecture;
