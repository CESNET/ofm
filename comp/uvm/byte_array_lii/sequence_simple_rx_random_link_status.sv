/*
 * file       : sequence_simple_rx_random_link_status.sv
 * Copyright (C) 2021 CESNET z. s. p. o.
 * description: LII sequence
 * date       : 2021
 * author     : Daniel Kriz <xkrizd01@vutbr.cz>
 *
 * SPDX-License-Identifier: BSD-3-Clause
*/

import crc32_ethernet_pkg::*;

//RX MAC
// This low level sequence define how can data looks like.
// This sequence generate random gaps between frames and simulate basic functionality of RX MAC
// So it can be used in RX MAC as an input sequence
// In this sequence is link status randomize
// There is also logic vector sequence item for generation of error signals
// In the end of the packet is generate CRC and last chunk of data
class sequence_simple_rx_random_link_status #(DATA_WIDTH, FAST_SOF, META_WIDTH, LOGIC_WIDTH) extends sequence_simple #(DATA_WIDTH, FAST_SOF, META_WIDTH, LOGIC_WIDTH);

    `uvm_object_param_utils(byte_array_lii_env::sequence_simple_rx_random_link_status #(DATA_WIDTH, FAST_SOF, META_WIDTH, LOGIC_WIDTH))

    // -----------------------
    // Parameters.
    // -----------------------

    localparam BYTE_NUM = DATA_WIDTH/8;

    common::rand_rdy link_status;
    common::rand_length number_of_idles;


    localparam BYTES_VLD_LENGTH        = $clog2(DATA_WIDTH/8)+1;
    logic [31 : 0] crc;
    logic [BYTES_VLD_LENGTH : 0] bytes = '0;
    logic last_chunk                   = 1'b1;

    // Constructor - creates new instance of this class
    function new(string name = "sequence");
        super.new("sequence_simple_rx_random_link_status");
        link_status     = common::rand_rdy_swap::new(3000, 1);
        number_of_idles = common::rand_length_rand::new;
    endfunction

    // Method which define how the transaction will look.
    virtual task create_sequence_item();
        for (int i = 0; i < frame.data.size(); i = i + BYTE_NUM) begin
            // Together with finish_item initiate operation of sequence item (handshake with driver).
            if (link_down == 1'b1) begin
                send_empty();
                link_down = 1'b0;
            end
            start_item(req);
            if (!req.randomize()) `uvm_fatal(this.get_full_name(), "failed to radnomize");
            void'(link_status.randomize());
            frame_cnt++;

            set_default();

            req.link_status = link_status.m_value;
            // First chunk has SOF = 1
            if (i == 0) begin
                void'(number_of_idles.randomize());
                // Gaps generator logic
                while (number_of_idles.m_value != 0) begin
                    number_of_idles.m_value--;
                    if (req.link_status == 1'b0) begin
                        set_meta();
                        link_down    = 1'b1;
                        finish_item(req);
                        send_same();
                        return;
                    end else begin
                        finish_item(req);
                        send_same();
                    end
                    start_item(req);
                    void'(link_status.randomize());
                    req.link_status = link_status.m_value;
                    req.meta     = '0;
                    if (link_down == 1'b1 && number_of_idles.m_value == 0) begin
                        number_of_idles.m_value++;
                        link_down = 1'b0;
                    end
                end
                // Preambule logic
                while (preambule_done != 1'b1) begin
                    if (idle_done == 1'b0) begin
                        // First chunk has SOF = 1
                        req.sof   = 1'b1;
                        req.data  = idle;
                        idle_done = 1'b1;
                        if (req.link_status == 1'b0) begin
                            set_meta();
                            link_down    = 1'b1;
                            finish_item(req);
                            send_same();
                            return;
                        end else begin
                            finish_item(req);
                            send_same();
                        end
                    end else begin
                        req.sof        = 1'b0;
                        req.data       = preambule;
                        preambule_done = 1'b1;
                        if (req.link_status == 1'b0) begin
                            set_meta();
                            link_down    = 1'b1;
                            finish_item(req);
                            send_same();
                            return;
                        end else begin
                            finish_item(req);
                            send_same();
                        end
                    end
                    start_item(req);
                    void'(link_status.randomize());
                    set_default();
                    req.link_status = link_status.m_value;
                end
            end

            if (number_of_idles.m_value == 0) begin

                if ((frame.data.size() % BYTE_NUM) == 0) begin
                    bytes = BYTE_NUM;
                end else begin
                    bytes = (frame.data.size() % BYTE_NUM);
                end

                // Data are divided to 32 bytes long chunks, which are sended to driver.
                req.data = {<< byte{frame.data[i +: BYTE_NUM]}};
                //FOR RX MAC
                if (i + BYTE_NUM >= frame.data.size()) begin
                    req.eeof = 1'b1;
                    req.edb = bytes;
                    crc = ~crc32_ethernet(frame.data, 32'hffffffff);
                    case (int'(bytes))
                        1:
                        begin
                            req.data[31 : 8] = crc[23 : 0];
                            last_chunk = 1'b0;
                        end
                        2:
                        begin
                            req.data[31 : 16] = crc[15 : 0];
                            last_chunk = 1'b0;
                        end
                        3:
                        begin
                            req.data[31 : 24] = crc[7 : 0];
                            last_chunk = 1'b0;
                        end
                        4:
                        begin
                            last_chunk = 1'b0;
                        end
                    endcase
                end else begin
                    req.data = {<< byte{frame.data[i +: BYTE_NUM]}};
                end

                if (req.link_status == 1'b0) begin
                    set_meta();
                    link_down    = 1'b1;
                    if (meta.data[0] == 1'b1) begin
                        $write("LINK STATUS: %b DATA: %h\n", meta.data, req.data);
                    end
                    finish_item(req);
                    send_same();
                    return;
                end else begin
                    finish_item(req);
                    send_same();
                end

            end
        end
        if (last_chunk == 1'b0) begin
            start_item(req);
            if (!req.randomize()) `uvm_fatal(this.get_full_name(), "failed to radnomize");
            void'(link_status.randomize());
            set_default();
            req.eof         = 1'b1;
            req.bytes_vld   = bytes;

            req.link_status = link_status.m_value;
            set_meta();
            case (int'(bytes))
                1:
                begin
                    req.data[7 : 0] = crc[31 : 24];
                    req.data[31 : 8] = '0;
                end
                2:
                begin
                    req.data[15 : 0] = crc[31 : 16];
                    req.data[31 : 16] = '0;
                end
                3:
                begin
                    req.data[23 : 0] = crc[31 : 8];
                    req.data[31 : 24] = '0;
                end
                4:
                begin
                    req.data = crc;
                end
            endcase
            last_chunk = 1'b1;
            finish_item(req);
            send_same();
        end
    endtask

    virtual task send_empty();
        start_item(req);
        void'(link_status.randomize());
        set_default();
        req.link_status = link_status.m_value;
        finish_item(req);
        send_same();
    endtask

endclass