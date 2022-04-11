-- crossbarx_stream.vhd: Universal memory data transfering unit for stream data flow
-- Copyright (C) 2019 CESNET z. s. p. o.
-- Author(s): Jan Kubalek <xkubal11@stud.fit.vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.math_pack.all;
use work.type_pack.all;

-- ----------------------------------------------------------------------------
--                                Description
-- ----------------------------------------------------------------------------
-- This unit is a wrapper over the classic CrossbarX with additional features
-- to support transfer of data in a streaming way. This means that the input
-- data in Transactions must proceed sequencialy and so does the output.
-- Apart from CrossbarX this component contains data buffers and other units
-- for Transaction preprocessing.

-- ----------------------------------------------------------------------------
--                            Entity declaration
-- ----------------------------------------------------------------------------

entity CROSSBARX_STREAM is
generic (
);
port(
    -- ------------------------------------------------------------------------
    -- Clock and reset
    -- ------------------------------------------------------------------------

    RX_CLK             : in  std_logic;
    RX_CLK2            : in  std_logic; -- be double frequency and same source as RX_CLK
    RX_RESET           : in  std_logic;
    TX_CLK             : in  std_logic;
    TX_RESET           : in  std_logic;

    -- ------------------------------------------------------------------------
    -- Input Transactions
    -- ------------------------------------------------------------------------
    -- WARNING: Transactions may only describe data that have already been passed
    --          in the RX DATA interface!

    RX_TRANS_A_COL     : in  slv_array_t     (TRANS_STREAMS-1 downto 0)(log2(BUF_A_COLS)-1 downto 0);
    RX_TRANS_A_ITEM    : in  slv_array_2d_t  (TRANS_STREAMS-1 downto 0)(TRANSS-1 downto 0)(log2(BUF_A_ROWS*ROW_ITEMS/TRANS_STREAMS)-1 downto 0);
    RX_TRANS_B_COL     : in  slv_array_2d_t  (TRANS_STREAMS-1 downto 0)(TRANSS-1 downto 0)(log2(BUF_B_COLS)-1 downto 0);
    RX_TRANS_B_ITEM    : in  slv_array_2d_t  (TRANS_STREAMS-1 downto 0)(TRANSS-1 downto 0)(log2(BUF_B_ROWS*ROW_ITEMS)-1 downto 0);
    RX_TRANS_LEN       : in  slv_array_2d_t  (TRANS_STREAMS-1 downto 0)(TRANSS-1 downto 0)(log2(TRANS_MTU+1)-1 downto 0);
    -- Total number of items from the start of the first valid Transaction
    -- to the end of the last valid Transaction (with no other Transactions being present).
    -- (These values include possible gaps between Transaction data and might
    --  be different for Buffer A and Buffer B.)
    -- The reason why the values aren't computed in this unit is, that it is the user,
    -- who generates the Transactions and he knows best, what is the maximum value
    -- of these signals and can correctly set the _LEN_SUM_WIDTH generics.
    RX_TRANS_A_LEN_SUM : in  slv_array_t     (TRANS_STREAMS-1 downto 0)(A_LEN_SUM_WIDTH-1 downto 0);
    RX_TRANS_B_LEN_SUM : in  slv_array_t     (TRANS_STREAMS-1 downto 0)(B_LEN_SUM_WIDTH-1 downto 0);
    ----
    RX_TRANS_METADATA  : in  slv_array_t     (TRANS_STREAMS-1 downto 0)(METADATA_WIDTH-1 downto 0) := (others => (others => '0'));
    RX_TRANS_VLD       : in  slv_array_t     (TRANS_STREAMS-1 downto 0)(TRANSS-1 downto 0);
    RX_TRANS_SRC_RDY   : in  std_logic_vector(TRANS_STREAMS-1 downto 0);
    RX_TRANS_DST_RDY   : out std_logic_vector(TRANS_STREAMS-1 downto 0);

    -- ------------------------------------------------------------------------
    -- Input Data Stream
    -- ------------------------------------------------------------------------

    RX_MFB_DATA     : in  slv_array_t     (tsel(DATA_DIR,TRANS_STREAMS,1)-1 downto 0)(tsel(DATA_DIR,BUF_A_ROWS/TRANS_STREAMS,BUF_B_ROWS)*ROW_ITEMS*ITEM_WIDTH-1 downto 0);
  --RX_MFB_SOF     -- ignored
  --RX_MFB_EOF     -- ignored
  --RX_MFB_SOF_POS -- ignored
  --RX_MFB_EOF_POS -- ignored
    RX_MFB_SRC_RDY  : in  std_logic_vector(tsel(DATA_DIR,TRANS_STREAMS,1)-1 downto 0);
    RX_MFB_DST_RDY  : out std_logic_vector(tsel(DATA_DIR,TRANS_STREAMS,1)-1 downto 0);

    -- ------------------------------------------------------------------------
    -- Output Data Stream
    -- ------------------------------------------------------------------------

    TX_MFB_DATA     : out slv_array_t     (tsel(DATA_DIR,1,TRANS_STREAMS)-1 downto 0)(tsel(DATA_DIR,BUF_B_ROWS,BUF_A_ROWS/TRANS_STREAMS)*ROW_ITEMS*ITEM_WIDTH-1 downto 0);
    TX_MFB_SOF      : out
    TX_MFB_EOF      : out
    TX_MFB_SOF_POS  : out
    TX_MFB_EOF_POS  : out
    TX_MFB_SRC_RDY  : out std_logic_vector(tsel(DATA_DIR,1,TRANS_STREAMS)-1 downto 0);
    TX_MFB_DST_RDY  : in  std_logic_vector(tsel(DATA_DIR,1,TRANS_STREAMS)-1 downto 0);

    -- Source Buffer read interface
    SRC_BUF_RD_ADDR : out slv_array_t(tsel(DATA_DIR,BUF_A_ROWS,BUF_B_ROWS)-1 downto 0)(log2(tsel(DATA_DIR,BUF_A_COLS,BUF_B_COLS))-1 downto 0);
    SRC_BUF_RD_DATA : in  slv_array_t(tsel(DATA_DIR,BUF_A_ROWS,BUF_B_ROWS)-1 downto 0)((ROW_ITEMS*ITEM_WIDTH)-1 downto 0);

    -- Destination Buffer read interface
    DST_BUF_WR_ADDR : out slv_array_t     (tsel(DATA_DIR,BUF_B_ROWS,BUF_A_ROWS)-1 downto 0)(log2(tsel(DATA_DIR,BUF_B_COLS,BUF_A_COLS))-1 downto 0);
    DST_BUF_WR_DATA : out slv_array_t     (tsel(DATA_DIR,BUF_B_ROWS,BUF_A_ROWS)-1 downto 0)((ROW_ITEMS*ITEM_WIDTH)-1 downto 0);
    DST_BUF_WR_IE   : out slv_array_t     (tsel(DATA_DIR,BUF_B_ROWS,BUF_A_ROWS)-1 downto 0)(ROW_ITEMS-1 downto 0); -- item enable
    DST_BUF_WR_EN   : out std_logic_vector(tsel(DATA_DIR,BUF_B_ROWS,BUF_A_ROWS)-1 downto 0);

    -- A pointer to the first word in Buffer A, that was not yet processed
    BUF_A_PTR       : out slv_array_t(TRANS_STREAMS-1 downto 0)(log2(BUF_A_COLS*BUF_A_ROWS*ROW_ITEMS)-1 downto 0)
);
end entity;

-- ----------------------------------------------------------------------------
--                           Architecture
-- ----------------------------------------------------------------------------

architecture FULL of CROSSBARX_STREAM is

    a

    -- ------------------------------------------------------------------------

begin

    assert ((BUF_A_ROWS/TRANS_STREAMS)*TRANS_STREAMS=BUF_A_ROWS)

    -- ------------------------------------------------------------------------

end architecture;
