-- eth_hdr_pack.vhd: Ethernet Header Package
-- Copyright (C) 2021 CESNET
-- Author: Jakub Cabal <cabal@cesnet.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause

library IEEE;
use IEEE.std_logic_1164.all;

-- -----------------------------------------------------------------------------
--                        Ethernet Header Package
-- -----------------------------------------------------------------------------

-- Items description:
--
-- ============= ==============================================================
-- LENGTH        Lenght of frame in bytes
-- PORT          Source (RX) or destination (TX) Ethernet port of frame
-- ERROR         Global error of frame, masked OR of all error bits
-- ERRORFRAME    Frame with frame error
-- ERRORMINTU    Frame with length below MINTU
-- ERRORMAXTU    Frame with length over MAXTU
-- ERRORCRC      Frame with CRC error
-- ERRORMAC      Frame with MAC error
-- BROADCAST     Frame with Broadcast MAC
-- MULTICAST     Frame with Multicast MAC
-- HITMACVLD     Valid bit of hit CAM memory address
-- HITMAC        Hit CAM memory address of frame MAC
-- TIMESTAMPVLD  Valid bit of timestamp
-- TIMESTAMP     Timestamp of frame
-- DISCARD       Discard frame before transmit
-- ============= ==============================================================
package eth_hdr_pack is

    constant ETH_RX_HDR_LENGTH_W       : natural := 16;
    constant ETH_RX_HDR_PORT_W         : natural := 8;
    constant ETH_RX_HDR_ERROR_W        : natural := 1;
    constant ETH_RX_HDR_ERRORFRAME_W   : natural := 1;
    constant ETH_RX_HDR_ERRORMINTU_W   : natural := 1;
    constant ETH_RX_HDR_ERRORMAXTU_W   : natural := 1;
    constant ETH_RX_HDR_ERRORCRC_W     : natural := 1;
    constant ETH_RX_HDR_ERRORMAC_W     : natural := 1;
    constant ETH_RX_HDR_BROADCAST_W    : natural := 1;
    constant ETH_RX_HDR_MULTICAST_W    : natural := 1;
    constant ETH_RX_HDR_HITMACVLD_W    : natural := 1;
    constant ETH_RX_HDR_HITMAC_W       : natural := 4;
    constant ETH_RX_HDR_TIMESTAMPVLD_W : natural := 1;
    constant ETH_RX_HDR_TIMESTAMP_W    : natural := 64;

    constant ETH_TX_HDR_LENGTH_W       : natural := 16;
    constant ETH_TX_HDR_PORT_W         : natural := 8;
    constant ETH_TX_HDR_DISCARD_W      : natural := 1;

    constant ETH_RX_HDR_LENGTH_O       : natural := 0;
    constant ETH_RX_HDR_PORT_O         : natural := ETH_RX_HDR_LENGTH_O       + ETH_RX_HDR_LENGTH_W;
    constant ETH_RX_HDR_ERROR_O        : natural := ETH_RX_HDR_PORT_O         + ETH_RX_HDR_PORT_W;
    constant ETH_RX_HDR_ERRORFRAME_O   : natural := ETH_RX_HDR_ERROR_O        + ETH_RX_HDR_ERROR_W;
    constant ETH_RX_HDR_ERRORMINTU_O   : natural := ETH_RX_HDR_ERRORFRAME_O   + ETH_RX_HDR_ERRORFRAME_W;
    constant ETH_RX_HDR_ERRORMAXTU_O   : natural := ETH_RX_HDR_ERRORMINTU_O   + ETH_RX_HDR_ERRORMINTU_W;
    constant ETH_RX_HDR_ERRORCRC_O     : natural := ETH_RX_HDR_ERRORMAXTU_O   + ETH_RX_HDR_ERRORMAXTU_W;
    constant ETH_RX_HDR_ERRORMAC_O     : natural := ETH_RX_HDR_ERRORCRC_O     + ETH_RX_HDR_ERRORCRC_W;
    constant ETH_RX_HDR_BROADCAST_O    : natural := ETH_RX_HDR_ERRORMAC_O     + ETH_RX_HDR_ERRORMAC_W;
    constant ETH_RX_HDR_MULTICAST_O    : natural := ETH_RX_HDR_BROADCAST_O    + ETH_RX_HDR_BROADCAST_W;
    constant ETH_RX_HDR_HITMACVLD_O    : natural := ETH_RX_HDR_MULTICAST_O    + ETH_RX_HDR_MULTICAST_W;
    constant ETH_RX_HDR_HITMAC_O       : natural := ETH_RX_HDR_HITMACVLD_O    + ETH_RX_HDR_HITMACVLD_W;
    constant ETH_RX_HDR_TIMESTAMPVLD_O : natural := ETH_RX_HDR_HITMAC_O       + ETH_RX_HDR_HITMAC_W;
    constant ETH_RX_HDR_TIMESTAMP_O    : natural := ETH_RX_HDR_TIMESTAMPVLD_O + ETH_RX_HDR_TIMESTAMPVLD_W;

    constant ETH_TX_HDR_LENGTH_O       : natural := 0;
    constant ETH_TX_HDR_PORT_O         : natural := ETH_TX_HDR_LENGTH_O + ETH_TX_HDR_LENGTH_W;
    constant ETH_TX_HDR_DISCARD_O      : natural := ETH_TX_HDR_PORT_O   + ETH_TX_HDR_PORT_W;

    subtype ETH_RX_HDR_LENGTH          is natural range ETH_RX_HDR_LENGTH_O       + ETH_RX_HDR_LENGTH_W       -1 downto ETH_RX_HDR_LENGTH_O;
    subtype ETH_RX_HDR_PORT            is natural range ETH_RX_HDR_PORT_O         + ETH_RX_HDR_PORT_W         -1 downto ETH_RX_HDR_PORT_O;
    subtype ETH_RX_HDR_ERROR           is natural range ETH_RX_HDR_ERROR_O        + ETH_RX_HDR_ERROR_W        -1 downto ETH_RX_HDR_ERROR_O;
    subtype ETH_RX_HDR_ERRORFRAME      is natural range ETH_RX_HDR_ERRORFRAME_O   + ETH_RX_HDR_ERRORFRAME_W   -1 downto ETH_RX_HDR_ERRORFRAME_O;
    subtype ETH_RX_HDR_ERRORMINTU      is natural range ETH_RX_HDR_ERRORMINTU_O   + ETH_RX_HDR_ERRORMINTU_W   -1 downto ETH_RX_HDR_ERRORMINTU_O;
    subtype ETH_RX_HDR_ERRORMAXTU      is natural range ETH_RX_HDR_ERRORMAXTU_O   + ETH_RX_HDR_ERRORMAXTU_W   -1 downto ETH_RX_HDR_ERRORMAXTU_O;
    subtype ETH_RX_HDR_ERRORCRC        is natural range ETH_RX_HDR_ERRORCRC_O     + ETH_RX_HDR_ERRORCRC_W     -1 downto ETH_RX_HDR_ERRORCRC_O;
    subtype ETH_RX_HDR_ERRORMAC        is natural range ETH_RX_HDR_ERRORMAC_O     + ETH_RX_HDR_ERRORMAC_W     -1 downto ETH_RX_HDR_ERRORMAC_O;
    subtype ETH_RX_HDR_BROADCAST       is natural range ETH_RX_HDR_BROADCAST_O    + ETH_RX_HDR_BROADCAST_W    -1 downto ETH_RX_HDR_BROADCAST_O;
    subtype ETH_RX_HDR_MULTICAST       is natural range ETH_RX_HDR_MULTICAST_O    + ETH_RX_HDR_MULTICAST_W    -1 downto ETH_RX_HDR_MULTICAST_O;
    subtype ETH_RX_HDR_HITMACVLD       is natural range ETH_RX_HDR_HITMACVLD_O    + ETH_RX_HDR_HITMACVLD_W    -1 downto ETH_RX_HDR_HITMACVLD_O;
    subtype ETH_RX_HDR_HITMAC          is natural range ETH_RX_HDR_HITMAC_O       + ETH_RX_HDR_HITMAC_W       -1 downto ETH_RX_HDR_HITMAC_O;
    subtype ETH_RX_HDR_TIMESTAMPVLD    is natural range ETH_RX_HDR_TIMESTAMPVLD_O + ETH_RX_HDR_TIMESTAMPVLD_W -1 downto ETH_RX_HDR_TIMESTAMPVLD_O;
    subtype ETH_RX_HDR_TIMESTAMP       is natural range ETH_RX_HDR_TIMESTAMP_O    + ETH_RX_HDR_TIMESTAMP_W    -1 downto ETH_RX_HDR_TIMESTAMP_O;

    subtype ETH_TX_HDR_LENGTH          is natural range ETH_TX_HDR_LENGTH_O    + ETH_TX_HDR_LENGTH_W -1 downto ETH_TX_HDR_LENGTH_O;
    subtype ETH_TX_HDR_PORT            is natural range ETH_TX_HDR_PORT_O      + ETH_TX_HDR_PORT_W   -1 downto ETH_TX_HDR_PORT_O;
    subtype ETH_TX_HDR_DISCARD         is natural range ETH_TX_HDR_DISCARD_O   + ETH_TX_HDR_DISCARD_W-1 downto ETH_TX_HDR_DISCARD_O;

    constant ETH_RX_HDR_WIDTH          : natural := ETH_RX_HDR_TIMESTAMP_O + ETH_RX_HDR_TIMESTAMP_W;
    constant ETH_TX_HDR_WIDTH          : natural := ETH_TX_HDR_DISCARD_O   + ETH_TX_HDR_DISCARD_W;

end package;

-- -----------------------------------------------------------------------------
--                        Ethernet Header Package body
-- -----------------------------------------------------------------------------

package body eth_hdr_pack is

end package body;
