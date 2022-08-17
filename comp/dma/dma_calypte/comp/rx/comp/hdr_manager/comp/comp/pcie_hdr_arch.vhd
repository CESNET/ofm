library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.math_pack.all;
use work.type_pack.all;


architecture FULL of PCIE_HDR_GEN is
begin


    --=====================================================================
    -- PCIE header for AXI interface 
    --=====================================================================
    DEVICE_ULTRASCALE : if DEVICE = "ULTRASCALE" generate
        signal pcie_hdr_at           : std_logic_vector(2 -1 downto 0);
        signal pcie_hdr_ecrc         : std_logic;
        signal pcie_hdr_attr         : std_logic_vector(3 -1 downto 0);
        signal pcie_hdr_tc           : std_logic_vector(3-1 downto 0);
        signal pcie_hdr_rq_id_e      : std_logic;
        signal pcie_hdr_completer_id : std_logic_vector(16 -1 downto 0);
        signal pcie_hdr_requester_id : std_logic_vector(16 -1 downto 0);
        signal pcie_hdr_poisoned     : std_logic;
        signal pcie_hdr_req_type     : std_logic_vector(4-1 downto 0);
    begin
        pcie_hdr_at               <= "00";
        pcie_hdr_ecrc             <= '0';
        pcie_hdr_attr             <= "000";
        pcie_hdr_tc               <= "000";
        pcie_hdr_rq_id_e          <= '0';
        pcie_hdr_completer_id     <= X"0000";
        pcie_hdr_requester_id     <= X"0000";
        pcie_hdr_poisoned         <= '0';
        pcie_hdr_req_type         <= X"1";


        PCIE_HDR_SIZE             <= '1';    -- axi header is allways size 64b

        PCIE_HDR(64-1 downto 0)   <= ADDR(64-1 downto 2) & pcie_hdr_at;
        PCIE_HDR(96-1 downto 64)  <= pcie_hdr_requester_id
                                     & pcie_hdr_poisoned
                                     & pcie_hdr_req_type
                                     & DWORD_COUNT;

        PCIE_HDR(128-1 downto 96) <= pcie_hdr_ecrc
                                     & pcie_hdr_attr
                                     & pcie_hdr_tc
                                     & pcie_hdr_rq_id_e
                                     & pcie_hdr_completer_id
                                     & TAG;

    end generate;


    --=====================================================================
    -- PCIE header for AVALON interface
    --=====================================================================
    DEVICE_INTEL : if (DEVICE = "STRATIX10" or DEVICE = "AGILEX") generate
        signal pcie_hdr_type         : std_logic;
        signal pcie_hdr_at           : std_logic_vector(2 -1 downto 0);
        signal pcie_hdr_requester_id : std_logic_vector(16 -1 downto 0);
        signal pcie_hdr_tag          : std_logic_vector(10-1  downto 0);
        signal pcie_hdr_last_be      : std_logic_vector(4-1 downto 0);
        signal pcie_hdr_first_be     : std_logic_vector(4-1 downto 0);
        signal pcie_hdr_req_type     : std_logic_vector(2-1 downto 0);
        signal pcie_hdr_tc           : std_logic_vector(3-1 downto 0);
        signal pcie_hdr_ecrc         : std_logic;
        signal pcie_hdr_poisoned     : std_logic;
        signal pcie_hdr_attr         : std_logic_vector(2 -1 downto 0);
    begin
        pcie_hdr_at               <= "00";
        pcie_hdr_requester_id     <= X"0000";
        pcie_hdr_tag              <= "00" & TAG;
        pcie_hdr_last_be          <= "0000";
        pcie_hdr_first_be         <= "0000";

        pcie_hdr_type               <= '1' when (ADDR(64-1 downto 32) /= (64-1 downto 32 => '0')) else '0';
        pcie_hdr_req_type           <=  "11" when pcie_hdr_type = '1' else "10";
        PCIE_HDR_SIZE               <=  pcie_hdr_type; 
        PCIE_HDR(128-1 downto 96)   <=  ADDR(32-1 downto 2) & pcie_hdr_at;
        PCIE_HDR(96-1  downto 64)   <=  ADDR(64-1 downto 32) when pcie_hdr_type = '1' else ADDR(32-1 downto 2) & pcie_hdr_at;

        PCIE_HDR(64-1 downto 32)  <= pcie_hdr_requester_id
                                     & pcie_hdr_tag(8-1 downto 0)
                                     & pcie_hdr_last_be
                                     & pcie_hdr_first_be;

        PCIE_HDR(32-1 downto 0) <= "0" 
                                     & pcie_hdr_type
                                     & (5-1 downto 0 => '0')
                                     & pcie_hdr_tag(9)
                                     & pcie_hdr_tc
                                     & pcie_hdr_tag(8)
                                     & (3-1 downto 0 => '0') 
                                     & pcie_hdr_ecrc
                                     & pcie_hdr_poisoned
                                     & pcie_hdr_attr
                                     & (2-1 downto 0 => '0') 
                                     & DWORD_COUNT;

    end generate;


end architecture;

