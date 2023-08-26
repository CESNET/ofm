-- mp_bram.vhd: Multi-ported BRAM
-- Copyright (C) 2023 CESNET z. s. p. o.
-- Author(s): Oliver Gurka <oliver.gurka@cesnet.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.math_pack.all;
use work.type_pack.all;

-- Multi-port BRAM. Currently supports only one write port. This will change in future.
-- Amount of read ports is not restricted.
entity MP_BRAM is
    generic (
        -- Data word width in bits. If BLOCK_ENABLE is True then DATA_WIDTH must
        -- be N*BLOCK_WIDTH.
        DATA_WIDTH     : integer := 1;
        -- Depth of BRAM in number of the data words.
        ITEMS          : integer := 4096;
        -- Enable masking of WR_DATA signal per BLOCK_WIDTH.
        BLOCK_ENABLE   : boolean := False;
        -- Width of one data block. Allowed values are 8 or 9. The parameter is
        -- ignored when BLOCK_ENABLE=False.
        BLOCK_WIDTH    : natural := 8;
        -- Output directly from BRAM or throw register (better timing).
        OUTPUT_REG     : boolean := True;
        -- Width of read metadata signal
        METADATA_WIDTH : integer := 0;
        -- Amount of write ports, currently supports just 1 write port.
        WRITE_PORTS    : natural := 1;

        -- Amount of read ports. For each read port, BRAM is replicated to provide one
        -- read port.
        READ_PORTS     : natural := 2;

        -- The DEVICE parameter allows the correct selection of the RAM
        -- implementation according to the FPGA used. Supported values are:
        --
        -- * "7SERIES"
        -- * "ULTRASCALE"
        -- * "STRATIX10"
        -- * "ARRIA10"
        -- * "AGILEX"
        DEVICE         : string := "AGILEX"
    );
    port (
        CLK         : in    std_logic;
        RESET       : in    std_logic;

        -- =====================================================================
        --  WRITE PORTS
        -- =====================================================================
        -- Enable of write port.
        WR_EN       : in  std_logic_vector(WRITE_PORTS - 1 downto 0);
        -- Block enable of written data, used only when BLOCK_ENABLE = True.
        WR_BE       : in  slv_array_t(WRITE_PORTS - 1 downto 0)(max((DATA_WIDTH/BLOCK_WIDTH),1)-1 downto 0);
        -- Write address.
        WR_ADDR     : in  slv_array_t(WRITE_PORTS - 1 downto 0)(log2(ITEMS)-1 downto 0); 
        -- Write data input.
        WR_DATA     : in  slv_array_t(WRITE_PORTS - 1 downto 0)(DATA_WIDTH-1 downto 0);

        -- =====================================================================
        -- READ PORTS
        -- =====================================================================
        -- Read enable signal, it is only used to generate RD_DATA_VLD.
        RD_EN       : in  std_logic_vector(READ_PORTS - 1 downto 0);
        -- Clock enable of read port.
        RD_PIPE_EN  : in  std_logic_vector(READ_PORTS - 1 downto 0); 
        -- Metadata propagated when RD_PIPE_EN=='1' (valid on RD_EN)
        RD_META_IN  : in  slv_array_t(READ_PORTS - 1 downto 0)(METADATA_WIDTH-1 downto 0) := (others => (others => '0'));
        -- Read address.
        RD_ADDR     : in  slv_array_t(READ_PORTS - 1 downto 0)(log2(ITEMS)-1 downto 0);
        -- Read data output.
        RD_DATA     : out slv_array_t(READ_PORTS - 1 downto 0)(DATA_WIDTH-1 downto 0);
        -- Metadata propagated when RD_PIPE_EN=='1' (valid on RD_DATA_VLD)
        RD_META_OUT : out slv_array_t(READ_PORTS - 1 downto 0)(METADATA_WIDTH-1 downto 0);
        -- Valid bit of output read data.
        RD_DATA_VLD : out std_logic_vector(READ_PORTS - 1 downto 0)
    );
end entity;

architecture FULL of MP_BRAM is

begin

    assert WRITE_PORTS = 1
        report "[MP_BRAM]: Currently supports only one write port!"
        severity failure;
    
    rd1_wrn_g : if WRITE_PORTS = 1 generate
        brams_g : for i in 0 to READ_PORTS - 1 generate
            bram_i : entity work.SDP_BRAM
            generic map (
                DATA_WIDTH      => DATA_WIDTH,
                ITEMS           => ITEMS,
                BLOCK_ENABLE    => BLOCK_ENABLE,
                BLOCK_WIDTH     => BLOCK_WIDTH,
                COMMON_CLOCK    => True,
                OUTPUT_REG      => OUTPUT_REG,
                METADATA_WIDTH  => METADATA_WIDTH,
                DEVICE          => DEVICE
            ) port map (
                WR_CLK          => CLK,
                WR_RST          => RESET,
    
                WR_EN           => WR_EN(0),
                WR_BE           => WR_BE(0),
                WR_ADDR         => WR_ADDR(0),
                WR_DATA         => WR_DATA(0),
    
                RD_CLK          => CLK,
                RD_RST          => RESET,
    
                RD_EN           => RD_EN(i),
                RD_PIPE_EN      => RD_PIPE_EN(i),
                RD_META_IN      => RD_META_IN(i),
                RD_ADDR         => RD_ADDR(i),
                RD_DATA         => RD_DATA(i),
                RD_META_OUT     => RD_META_OUT(i),
                RD_DATA_VLD     => RD_DATA_VLD(i)
            );
        end generate;
    end generate;
    
end architecture;