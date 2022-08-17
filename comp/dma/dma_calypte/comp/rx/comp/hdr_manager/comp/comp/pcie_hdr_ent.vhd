-- addr_manager_ent.vhd: manages free space and addresses for PCIe transactions
-- Copyright (c) 2022 CESNET z.s.p.o.
-- Author(s): Radek Iša <isa@cesnet.cz>, Vladislav Valek <xvalek14@vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-CLause


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.math_pack.all;


-- -----------------------------------------------------------------------------
-- PCIE_HDR_GEN
-- -----------------------------------------------------------------------------
-- This component generates pcie headers depends on device.

entity PCIE_HDR_GEN is
    generic (
            --SUPPORTED DEVICES (ULTRASCALE)
            --DEVICE        : string  := "ULTRASCALE"
            DEVICE        : string
        );

    port (
        --=====================================================================
        -- REQUIRED DATA FOR PCIE HEADERS 
        --=====================================================================
        ADDR           : in std_logic_vector(64-1 downto 0);
        DWORD_COUNT    : in std_logic_vector(11-1 downto 0);
        TAG            : in std_logic_vector(8-1  downto 0);

        --=====================================================================
        -- GENERATED PCIE HEADER 
        --=====================================================================
        PCIE_HDR      : out std_logic_vector(128-1 downto 0);
        -- 0 => PCIE_HDR(3*32-1 downto 0) bits are valid,
        -- 1 => PCIE_HDR(4*32-1 downto 0) bits are valid
        PCIE_HDR_SIZE : out std_logic
    );
end entity;
