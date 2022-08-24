// sequencer.sv: Virtual sequencer
// Copyright (C) 2022 CESNET z. s. p. o.
// Author(s): Daniel Kříž <xkrizd01@vutbr.cz>

// SPDX-License-Identifier: BSD-3-Clause


class virt_sequencer extends uvm_sequencer;
    `uvm_component_param_utils(virt_sequencer)

    uvm_reset::sequencer                   m_reset;
    uvm_logic_vector_array::sequencer #(8) m_byte_array_scr;
    uvm_superpacket_header::sequencer      m_info;
    uvm_superpacket_size::sequencer        m_size;

    function new(string name = "virt_sequencer", uvm_component parent);
        super.new(name, parent);
    endfunction

endclass
