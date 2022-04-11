-- pci_ext_cap.vhd: Extended capability handler for PCI
-- Copyright (C) 2017 CESNET
-- Author(s): Martin Spinler <spinler@cesnet.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.math_pack.all;
use work.type_pack.all;
use work.dtb_pkg.all;

entity PCI_EXT_CAP is
generic (
    VSEC_BASE_ADDRESS       : integer := 16#400#;
    VSEC_NEXT_POINTER       : integer := 16#000#;
    ENDPOINT_ID             : integer := 0;
    ENDPOINT_ID_ENABLE      : boolean := false;
    DEVICE_TREE_ENABLE      : boolean := true;
    CFG_EXT_READ_DV_HOTFIX  : boolean := true
);
-- Interface description
port (
    CLK                     : in  std_logic;
    CFG_EXT_READ            : in  std_logic;
    CFG_EXT_WRITE           : in  std_logic;
    CFG_EXT_REGISTER        : in  std_logic_vector(9 downto 0);
    CFG_EXT_FUNCTION        : in  std_logic_vector(7 downto 0);
    CFG_EXT_WRITE_DATA      : in  std_logic_vector(31 downto 0);
    CFG_EXT_WRITE_BE        : in  std_logic_vector(3 downto 0);
    CFG_EXT_READ_DATA       : out std_logic_vector(31 downto 0);
    CFG_EXT_READ_DV         : out std_logic
);
end entity;

architecture behavioral of PCI_EXT_CAP is

    constant VSEC_BASE_REG  : integer := VSEC_BASE_ADDRESS / 4;

    function dtb_words(data : in std_logic_vector) return integer is
    begin
        return (data'length / 8 + 3) / 4;
    end function;

    function init_mem_32b (data : in std_logic_vector) return slv_array_t is
        variable init : slv_array_t(0 to dtb_words(data)-1)(31 downto 0);
    begin
        for i in 0 to dtb_words(data)-1 loop
            for j in 0 to 3 loop
                if (data'length / 8 > i*4+j) then
                    init(i)(j*8+7 downto j*8) := data(i*32+j*8+7 downto i*32+j*8);
                else
                    init(i)(j*8+7 downto j*8) := (others => '0');
                end if;
            end loop;
        end loop;
        return init;
    end function;

    signal dtb_pf0          : slv_array_t(0 to dtb_words(DTB_PF0_DATA)-1)(31 downto 0)  := init_mem_32b(DTB_PF0_DATA);
    signal dtb_vf0          : slv_array_t(0 to dtb_words(DTB_VF0_DATA)-1)(31 downto 0)  := init_mem_32b(DTB_VF0_DATA);

    attribute ram_style     : string;
    attribute ramstyle      : string; -- for Quartus
    attribute ram_style of dtb_pf0  : signal is "block";
    attribute ram_style of dtb_vf0  : signal is "block";
    attribute ramstyle  of dtb_pf0  : signal is "M20K"; -- M20K, MLAB
    attribute ramstyle  of dtb_vf0  : signal is "M20K"; -- M20K, MLAB

    signal reg_dv           : std_logic := '0';
    signal reg_dtb_pf0_addr : std_logic_vector(log2(dtb_words(DTB_PF0_DATA))-1 downto 0);
    signal reg_dtb_vf0_addr : std_logic_vector(log2(dtb_words(DTB_VF0_DATA))-1 downto 0);
    signal reg_dtb_pf0_data : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_dtb_vf0_data : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_cfg_ext_read_data : std_logic_vector(31 downto 0);

    signal cfg_register     : integer;
    signal cfg_function     : integer;

begin

   -- Address space:
   -- 0x00: PCI-SIG spec: Vendor-Specific Extended Capability Header
   --       Next capability Offset & Capability Version & PCI Express Extended Capability ID
   --       0x000 & 0x1 & 0x000B
   -- 0x04: PCI-SIG spec: Vendor-Specific Header: DTB capability
   --       VSEC Length & VSEC Rev & VSEC ID
   --       0x020 & 0x1 & 0x0D7B
   -- 0x08: Endpoint ID flag (1b) & Reserved (27b) & Endpoint ID (4b)
   -- 0x0C: DTB real length
   -- 0x10: DTB address register
   -- 0x14: DTB data register (RO)
   -- 0x18: Reserved
   -- 0x1C: Reserved

    cfg_register    <= to_integer(unsigned(CFG_EXT_REGISTER));
    cfg_function    <= to_integer(unsigned(CFG_EXT_FUNCTION));

    addr_dec: process(all)
    begin
        if (CFG_EXT_READ = '1') then
            if    (cfg_register = VSEC_BASE_REG + 0) then
                CFG_EXT_READ_DATA <= std_logic_vector(to_unsigned(VSEC_NEXT_POINTER, 12)) & X"1" & X"000B";
            elsif (cfg_register = VSEC_BASE_REG + 1) then
                CFG_EXT_READ_DATA <= X"020" & X"1" & X"0D7B";
            elsif (cfg_register = VSEC_BASE_REG + 2) then
                if (ENDPOINT_ID_ENABLE) then
                    CFG_EXT_READ_DATA <= X"8000000" & std_logic_vector(to_unsigned(ENDPOINT_ID, 4));
                else
                    CFG_EXT_READ_DATA <= (others => '0');
                end if;
            elsif (cfg_register = VSEC_BASE_REG + 3) then
                if (DEVICE_TREE_ENABLE) then
                    CFG_EXT_READ_DATA <= std_logic_vector(to_unsigned(DTB_PF0_DATA'length, 32)) when cfg_function = 0 else
                                         std_logic_vector(to_unsigned(DTB_VF0_DATA'length, 32));
                else
                    CFG_EXT_READ_DATA <= (others => '0');
                end if;
            elsif (cfg_register = VSEC_BASE_REG + 4) then
                if (DEVICE_TREE_ENABLE) then
                    CFG_EXT_READ_DATA <= (31 downto log2(dtb_words(DTB_PF0_DATA)) => '0') & reg_dtb_pf0_addr when cfg_function = 0 else
                                         (31 downto log2(dtb_words(DTB_VF0_DATA)) => '0') & reg_dtb_vf0_addr;
                else
                    CFG_EXT_READ_DATA <= (others => '0');
                end if;
            elsif (cfg_register = VSEC_BASE_REG + 5) then
                if (DEVICE_TREE_ENABLE) then
                    CFG_EXT_READ_DATA <= reg_dtb_pf0_data when cfg_function = 0 else reg_dtb_vf0_data;
                else
                    CFG_EXT_READ_DATA <= (others => '0');
                end if;
            elsif (cfg_register = VSEC_BASE_REG + 6) then
                CFG_EXT_READ_DATA <= (others => '0');
            elsif (cfg_register = VSEC_BASE_REG + 7) then
                CFG_EXT_READ_DATA <= (others => '0');
            else
                CFG_EXT_READ_DATA <= (others => '0');
            end if;
        else
            CFG_EXT_READ_DATA <= reg_cfg_ext_read_data;
        end if;
    end process;

    CFG_EXT_READ_DV         <= reg_dv;

    dtb_regp : process(CLK)
    begin
        if rising_edge(CLK) then
            if (DEVICE_TREE_ENABLE) then
                reg_dtb_pf0_data <= dtb_pf0(to_integer(unsigned(reg_dtb_pf0_addr)));
                if (log2(dtb_words(DTB_VF0_DATA)) > 0) then
                    reg_dtb_vf0_data <= dtb_vf0(to_integer(unsigned(reg_dtb_vf0_addr)));
                else
                    reg_dtb_vf0_data <= (others => '0');
                end if;
            end if;
            reg_cfg_ext_read_data <= CFG_EXT_READ_DATA;

            if (CFG_EXT_READ = '1' and reg_dv = '0' and (CFG_EXT_READ_DV_HOTFIX or (cfg_register >= VSEC_BASE_REG and cfg_register < VSEC_BASE_REG + 8))) then
            -- Here is a bug, with this line the design reboots machine on Virtex 7 (CfgRead without Completion)
            --if (CFG_EXT_READ = '1' and reg_dv = '0' and cfg_register >= VSEC_BASE_REG and cfg_register < VSEC_BASE_REG + 8) then
                reg_dv <= '1';
            else
                reg_dv <= '0';
            end if;

            if (CFG_EXT_WRITE = '1' and cfg_register = VSEC_BASE_REG + 4) then
                if (cfg_function = 0) then
                    reg_dtb_pf0_addr    <= CFG_EXT_WRITE_DATA(log2(dtb_words(DTB_PF0_DATA))-1 downto 0);
                else
                    reg_dtb_vf0_addr    <= CFG_EXT_WRITE_DATA(log2(dtb_words(DTB_VF0_DATA))-1 downto 0);
                end if;
            end if;
        end if;
    end process;

end architecture;
