//-- scoreboard.sv: Scoreboard for verification
//-- Copyright (C) 2021 CESNET z. s. p. o.
//-- Copyright (C) 2023 CESNET z. s. p. o.
//-- Author(s): Radek Iša <isa@censet.cz>

//-- SPDX-License-Identifier: BSD-3-Clause

`uvm_analysis_imp_decl(_data)
`uvm_analysis_imp_decl(_meta)

class model_bind#(ITEM_WIDTH, META_WIDTH) extends uvm_common::fifo#(uvm_common::model_item#(model_data#(ITEM_WIDTH, META_WIDTH)));
    `uvm_component_param_utils(uvm_splitter_simple::model_bind#(ITEM_WIDTH, META_WIDTH))

    typedef model_bind#(ITEM_WIDTH, META_WIDTH) this_type;
    uvm_analysis_imp_data#(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH), this_type) data;
    uvm_analysis_imp_meta#(uvm_logic_vector::sequence_item #(META_WIDTH), this_type)      meta;

    protected uvm_common::model_item#(model_data#(ITEM_WIDTH, META_WIDTH)) tmp[$];
    protected string tag_name;

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void flush();
        super.flush();
        tmp.delete();
    endfunction

    virtual function int unsigned used();
        return (super.used() || tmp.size() != 0);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        data = new("data", this);
        meta = new("meta", this);

        if (!uvm_config_db #(string)::get(this, "", "tag", tag_name)) begin
            tag_name = this.get_full_name();
        end
    endfunction

    function void write_data(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH) tr);
        uvm_common::model_item#(model_data#(ITEM_WIDTH, META_WIDTH)) item;

        if (tmp.size() == 0 || tmp[0].item.data != null) begin
            item = uvm_common::model_item#(model_data#(ITEM_WIDTH, META_WIDTH))::type_id::create("item", this);
            item.tag = tag_name;
            item.start[{tag_name, " DATA"}] = $time();
            item.item = model_data#(ITEM_WIDTH, META_WIDTH)::type_id::create("item_item", this);
            item.item.data = tr;
            tmp.push_back(item);
        end else begin
            item = tmp.pop_front();
            item.start[{tag_name, " DATA"}] = $time();
            item.item.data = tr;
            this.push_back(item);
        end
    endfunction

    function void write_meta(uvm_logic_vector::sequence_item #(META_WIDTH) tr);
        uvm_common::model_item#(model_data#(ITEM_WIDTH, META_WIDTH)) item;

        if (tmp.size() == 0 || tmp[0].item.meta != null) begin
            item = uvm_common::model_item#(model_data#(ITEM_WIDTH, META_WIDTH))::type_id::create("item", this);
            item.tag = tag_name;
            item.start[{tag_name, " META"}] = $time();
            item.item = model_data#(ITEM_WIDTH, META_WIDTH)::type_id::create("item_item", this);
            item.item.meta = tr; 
            tmp.push_back(item);
        end else begin
            item = tmp.pop_front();
            item.start[{tag_name, " META"}] = $time();
            item.item.meta = tr;
            this.push_back(item);
        end
    endfunction
endclass

class comparer_data #(ITEM_WIDTH, META_WIDTH) extends uvm_common::comparer_base_ordered#(model_data#(ITEM_WIDTH, META_WIDTH), uvm_logic_vector_array::sequence_item#(ITEM_WIDTH));
    `uvm_component_param_utils(uvm_splitter_simple::comparer_data #(ITEM_WIDTH, META_WIDTH))

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function int unsigned compare(uvm_common::model_item #(MODEL_ITEM) tr_model, uvm_common::dut_item #(DUT_ITEM) tr_dut);
        return tr_model.item.data.compare(tr_dut.in_item);
    endfunction

    virtual function string message(uvm_common::model_item #(MODEL_ITEM) tr_model, uvm_common::dut_item #(DUT_ITEM) tr_dut);
        string msg = "";
        $swrite(msg, "%s\n\tDUT PACKET %s\n\n",   msg, tr_dut.convert2string());
        $swrite(msg, "%s\n\tMODEL PACKET%s\n\n",  msg, tr_model.convert2string());
        return msg;
    endfunction
endclass

class comparer_meta #(ITEM_WIDTH, META_WIDTH) extends uvm_common::comparer_base_ordered#(model_data#(ITEM_WIDTH, META_WIDTH), uvm_logic_vector::sequence_item #(META_WIDTH));
    `uvm_component_param_utils(uvm_splitter_simple::comparer_meta #(ITEM_WIDTH, META_WIDTH))

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function int unsigned compare(uvm_common::model_item #(MODEL_ITEM) tr_model, uvm_common::dut_item #(DUT_ITEM) tr_dut);
        return tr_model.item.meta.compare(tr_dut.in_item);
    endfunction

    virtual function string message(uvm_common::model_item #(MODEL_ITEM) tr_model, uvm_common::dut_item #(DUT_ITEM) tr_dut);
        string msg = "";
        $swrite(msg, "%s\n\tDUT PACKET %s\n\n",   msg, tr_dut.convert2string());
        $swrite(msg, "%s\n\tMODEL PACKET%s\n\n",  msg, tr_model.convert2string());
        return msg;
    endfunction
endclass


class scoreboard #(ITEM_WIDTH, META_WIDTH, CHANNELS) extends uvm_scoreboard;
    `uvm_component_param_utils(uvm_splitter_simple::scoreboard #(ITEM_WIDTH, META_WIDTH, CHANNELS))

    uvm_analysis_export #(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH))               input_data;
    uvm_analysis_export #(uvm_logic_vector::sequence_item #($clog2(CHANNELS) + META_WIDTH)) input_meta;

    uvm_analysis_export #(uvm_logic_vector_array::sequence_item#(ITEM_WIDTH))    out_data[CHANNELS];
    uvm_analysis_export #(uvm_logic_vector::sequence_item #(META_WIDTH))         out_meta[CHANNELS];

    typedef scoreboard #(ITEM_WIDTH, META_WIDTH, CHANNELS) this_type;
    uvm_analysis_imp_reset#(uvm_reset::sequence_item, this_type) analysis_imp_reset;

    protected model #(ITEM_WIDTH, META_WIDTH, CHANNELS) m_model;

    //COMPARERS
    protected comparer_data #(ITEM_WIDTH, META_WIDTH) compare_data[CHANNELS];
    protected comparer_meta #(ITEM_WIDTH, META_WIDTH) compare_meta[CHANNELS];

    // Contructor of scoreboard.
    function new(string name, uvm_component parent);
        super.new(name, parent);
        input_data = new("input_data", this);
        input_meta = new("input_meta", this);

        for (int unsigned it = 0; it < CHANNELS; it++) begin
            string it_str;
            it_str.itoa(it);

            out_data[it]        = new({"out_data_", it_str}, this);
            out_meta[it]        = new({"out_meta_", it_str}, this);
        end

        analysis_imp_reset = new("analysis_imp_reset", this);
    endfunction

    function void build_phase(uvm_phase phase);
        m_model    = model #(ITEM_WIDTH, META_WIDTH, CHANNELS)::type_id::create("m_model", this);
        m_model.in = model_bind#(ITEM_WIDTH, $clog2(CHANNELS) + META_WIDTH)::type_id::create("m_model_bind", m_model);

        for (int it = 0; it < CHANNELS; it++) begin
            string it_string;

            it_string.itoa(it);
            compare_data[it] = comparer_data #(ITEM_WIDTH, META_WIDTH)::type_id::create({"compare_data_", it_string}, this);
            compare_meta[it] = comparer_meta #(ITEM_WIDTH, META_WIDTH)::type_id::create({"compare_meta_", it_string}, this);
            compare_meta[it].model_tr_timeout_set(50000ns);
        end

    endfunction

    function void connect_phase(uvm_phase phase);
        model_bind#(ITEM_WIDTH, $clog2(CHANNELS) + META_WIDTH)  m_model_input;

        $cast(m_model_input, m_model.in);
        input_data.connect(m_model_input.data);
        input_meta.connect(m_model_input.meta);


        for (int it = 0; it < CHANNELS; it++) begin
            string i_string;

            m_model.out[it].connect(compare_data[it].analysis_imp_model);
            m_model.out[it].connect(compare_meta[it].analysis_imp_model);
            out_data[it].connect(compare_data[it].analysis_imp_dut);
            out_meta[it].connect(compare_meta[it].analysis_imp_dut);
        end
    endfunction

    function int unsigned used();
        int unsigned ret = 0;

        for (int unsigned it = 0; it < CHANNELS; it++) begin
            ret |= compare_data[it].used();
            ret |= compare_meta[it].used();
        end
        return ret;
    endfunction

    function int unsigned success();
        int unsigned ret = 0;

        for (int unsigned it = 0; it < CHANNELS; it++) begin
            ret |= compare_data[it].success();
            ret |= compare_meta[it].success();
        end
        return ret;
    endfunction

    function void write_reset(uvm_reset::sequence_item tr);
        if (tr.reset == 1'b1) begin
            m_model.reset();
            for (int unsigned it = 0; it < CHANNELS; it++) begin
                compare_data[it].flush();
                compare_meta[it].flush();
            end
        end
    endfunction


    function void report_phase(uvm_phase phase);
        string msg = "";

        if (this.success() && this.used() == 0) begin
            `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION SUCCESS      ----\n\t---------------------------------------"}, UVM_NONE)
        end else begin
            `uvm_info(get_type_name(), {msg, "\n\n\t---------------------------------------\n\t----     VERIFICATION FAIL      ----\n\t---------------------------------------"}, UVM_NONE)
        end
    endfunction

endclass
