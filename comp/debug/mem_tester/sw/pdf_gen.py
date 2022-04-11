#!/usr/bin/env python3
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>

from fpdf import FPDF
import numpy as np

pdf_w = 210
pdf_h = 297

margin_x = 3.4
margin_y = 4.0

class PDF(FPDF):
    #def header(self):
    #    # Logo
    #    self.image('flow_seq.png', 10, 8, 33)
    #    # Arial bold 15
    #    self.set_font('Arial', 'B', 15)
    #    # Move to the right
    #    self.cell(80)
    #    # Title
    #    self.cell(30, 10, 'Title', 1, 0, 'C')
    #    # Line break
    #    self.ln(20)

    def footer(self):
        self.set_y(-15)
        self.set_font('Arial', 'I', 8)
        self.cell(0, 10, 'Page ' + str(self.page_no()) + '/{nb}', 0, 0, 'C')

def heading(pdf, text, size):
    pdf.set_font('Times', 'B', size)
    pdf.cell(0, (2 / 3) * size, text, 0, 1)

def text(pdf, text):
    pdf.set_font('Times', '', 12)
    pdf.multi_cell(0, 5, text)
    #pdf.ln()

def from_file(pdf, file):
    with open(file, 'r') as f:
        txt = f.read()
    pdf.set_font('Times', '', 12)
    pdf.multi_cell(0, 5, txt)
    pdf.ln()

def image(pdf, path, scale):
    width = pdf_w * scale
    pdf.image(path, (pdf_w - width) / 2, None, width)

def pdf_init(card_info_file):
    pdf = PDF()
    pdf.alias_nb_pages()

    pdf.add_page()
    heading(pdf, "Memory tester report", 22)

    heading(pdf, "Card info", 15)
    from_file(pdf, card_info_file)

    heading(pdf, "Info about measurement and testing", 15)
    text(pdf, 
        "The test was performed using mem-tester component "
        "which tries to write and read pseudo-random numbers "
        "to every address of the external memory "
        "and checks if all data were saved and loaded correctly."
        "The amm-probe measures word count, latency and ticks "
        "during this test.\n"
        "There were performed multiple of these tests with different "
        "burst counts (AMM transaction lengths) and with sequention or "
        "random indexing. "
        "Error checking is performed only during sequential indexing. "
        "Because the mem-tester generates as much transactions as possible, "
        "average latencies are due to transaction overlaping larger. "
        "Therefore there was performed another test where "
        "maximal paralel transaction count was limited to 1. "
        "All of these situations are displayed using graphs bellow. "
        )

    return pdf

def measured_flow(pdf, data):
    text(pdf, "Max data flow (write / read) = {0} Gb/s / {1} Gb/s".format(
        round(data["write_flow"].max(), 2),
        round(data["read_flow"].max() , 2)))
    text(pdf, "Min data flow (write / read) = {0} Gb/s / {1} Gb/s".format(
        round(data["write_flow"].min(), 2),
        round(data["read_flow"].min() , 2)))
    text(pdf, "There were transfered {0} - {1} AMM words in each test (for different burst counts)".format(
        int(data["write_words"].min()),
        int(data["write_words"].max())))

def measured_lat(pdf, data):
    text(pdf, "Min / avg / max latency = {0} ns / {1} ns / {2} ns".format(
        int(data["lat_min"].min()),
        int(np.average(data["lat_avg"])),
        int(data["lat_max"].max()) ))

def pdf_report(pdf, fig_path, index, dev_info, data_seq, data_rand, data_seq_o, data_rand_o):
    pdf.add_page()
    heading(pdf, "Memory interface: {0}".format(index + 1), 18)

    heading(pdf, "AMM interface parameters", 15)
    text(pdf, "DATA_WIDTH = {0}".format(int(dev_info["AMM"]["DATA_WIDTH"])))
    text(pdf, "ADDR_WIDTH = {0}".format(int(dev_info["AMM"]["ADDR_WIDTH"])))
    text(pdf, "BURST_COUNT_WIDTH = {0}".format(int(dev_info["AMM"]["BURST_WIDTH"])))
    text(pdf, "FREQ = {0} MHz".format(dev_info["AMM"]["FREQ"] / 10 ** 6))
    pdf.ln()

    if data_seq["err_cnt"].max() != 0:
        text(pdf, "Errors found during tests:")
        image(pdf, fig_path + "{0}_seq_errs.png".format(index), 0.8)
        pdf.add_page()
    else:
        text(pdf, "No errors found during tests")

    heading(pdf, "Data flow", 15)
    image(pdf, fig_path + "{0}_seq_flow.png".format(index), 0.8)
    image(pdf, fig_path + "{0}_rand_flow.png".format(index), 0.8)

    heading(pdf, "Sequential indexing", 13)
    measured_flow(pdf, data_seq)
    heading(pdf, "Random indexing", 13)
    measured_flow(pdf, data_rand)

    pdf.add_page()
    heading(pdf, "Latency", 15)
    image(pdf, fig_path + "{0}_seq_lat.png" .format(index), 0.8)
    image(pdf, fig_path + "{0}_rand_lat.png" .format(index), 0.8)

    heading(pdf, "Sequential indexing", 13)
    measured_lat(pdf, data_seq)
    heading(pdf, "Random indexing", 13)
    measured_lat(pdf, data_rand)

    pdf.add_page()
    heading(pdf, "Latency - only one simulataneous read transaction", 15)
    heading(pdf, "Sequential indexing", 13)
    image(pdf, fig_path + "{0}_seq_o_lat.png" .format(index), 0.8)
    image(pdf, fig_path + "{0}_seq_o_lat_avg.png" .format(index), 0.8)

    measured_lat(pdf, data_seq_o)

    pdf.add_page()
    heading(pdf, "Random indexing", 13)
    image(pdf, fig_path + "{0}_rand_o_lat.png" .format(index), 0.8)
    image(pdf, fig_path + "{0}_rand_o_lat_avg.png" .format(index), 0.8)

    measured_lat(pdf, data_rand_o)

def pdf_fin(pdf, file):
    pdf.output(file, 'F')