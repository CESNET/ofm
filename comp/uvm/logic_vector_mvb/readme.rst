.. readme.rst: Documentation of single component
.. Copyright (C) 2022 CESNET z. s. p. o.
.. Author(s): Radek Iša <isa@cesnet.cz>
..
.. SPDX-License-Identifier: BSD-3-Clause

..  logic_vector to mvb enviroment
.. _logic_vector_mvb:

****************************
logic_vector_mvb environment
****************************
This environment convert logic_vector transaction to mvb transactions.


The environment is configured by four parameters: For more information see :ref:`mvb documentation<mvb_bus>`.

============== =
Parameter
============== =
ITEMS
ITEMS_WIDTH
============== =

Top sequencers and sequences
------------------------------
In RX directin there is one sequencer which generates logic_vector transactions. Transaction are going to be ordered with random delay put into mvb transactions.

In the TX direction there is one sequencer of type mvb::sequencer #() which generate DST_RDY signal.

Both environment send logic_vector transaction throught analysis_export.


Configuration
------------------------------

config class have 3 variables.

===============   ======================================================
Variable          Description
===============   ======================================================
active            Set to UVM_ACTIVE if agent is active otherwise UVM_PASSIVE
interface_name    name of interface under which you can find it in uvm config database
seq_cfg           Configure low level sequence which convert logic_vector to mvb words
===============   ======================================================

Top level of environment contains reset_sync class which is required for reset synchronization. The example shows how to connect the reset to logic_vector_array_mfb environment and basic configuration.

.. code-block:: systemverilog

    class test extends uvm_test
        `uvm_componet_utils(test::base)
        reset::agent                m_resets;
        logic_vector_mvb::env_rx#(...) m_env;

        function new(string name, uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
             logic_vector_mvb::config_item m_cfg;

             m_resets = reset::agent::type_id::create("m_reset", this);

             m_cfg = new();
             m_cfg.active = UVM_ACTIVE;
             m_cfg.interface_name = "MFB_IF";
             m_cfg.meta_behav     = config_item::META_SOF;
             m_cfg.cfg = new();
             m_cfg.cfg.space_size_set(128, 1024);
             uvm_config_db#(logic_vector_mvb_env::config_item)::set(this, "m_eth", "m_config", m_cfg);
             m_env = logic_vector_mvb::env_rx#(...)::type_id::create("m_env", this);
        endfunction

         function void connect_phase(uvm_phase phase);
            m_reset.sync_connect(m_env.reset_sync);
         endfunction
    endclass


Low sequence configuration
--------------------------

configuration object `config_sequence` contain one function.

=========================  ======================  ======================================================
Variable                   Type                    Description
=========================  ======================  ======================================================
space_size_set(min, max)   [bytes]                 set min and max space between two logic_vector items in mvb transaction.
=========================  ======================  ======================================================


RX Inner sequences
------------------------------

For the RX direction exists one base sequence class "sequence_simple_rx_base" which simplifies creating others sequences. It processes the reset signal and exports virtual
function create_sequence_item. In this function can child create mvb::sequence_item what they like.

The environment have three sequences. Table below describes them. In default RX env runs sequence_lib_rx.

==========================       ======================================================
Sequence                         Description
==========================       ======================================================
sequence_rand_rx                 base random sequence. This sequence is behavioral very variably.
sequence_burst_rx                Operate in burst mode.
sequence_full_speed_rx           if sequence get data then send them as quicky as possible.
sequence_stop_rx                 Sequence dosnt send any data. Sumulate no data on interface.
sequence_lib_rx                  randomly run pick and run previous sequences
==========================       ======================================================


    An example below shows how to change the inner sequence to test maximal throughput. Environment run the sequence_full_speed_rx instead of the sequence_lib_rx.

.. code-block:: systemverilog

    class mvb_rx_speed#(...) extends logic_vector_mvb_env::sequence_lib_rx#(...);

        function new(string name = "mvb_rx_speed");
            super.new(name);
            init_sequence_library();
        endfunction

        virtual function void init_sequence(config_sequence param_cfg = null);
            if (param_cfg == null) begin
                this.cfg = new();
            end else begin
                this.cfg = param_cfg;
            end
            this.add_sequence(logic_vector_mvb_env::sequence_full_speed_rx #(REGIONS, REGION_SIZE, BLOCK_SIZE, ITEM_WIDTH, META_WIDTH)::get_type());
        endfunction
    endclass


    class test extends uvm_test
        `uvm_componet_utils(test::base)
        logic_vector_mvb::env_rx#(...) m_env;

        function new(string name, uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            ...
             logic_vector_mvb_env::sequence_lib_rx#(...)::type_id::set_inst_override(mvb_rx_speed#(...)::get_type(),
             {this.get_full_name(), ".m_env.*"});
             m_env = logic_vector_mvb::env_rx#(...)::type_id::create("m_env", this);
        endfunction
    endclass
