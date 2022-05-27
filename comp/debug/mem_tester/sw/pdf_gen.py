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
        pass
        #self.set_y(-15)
        #self.set_font('Arial', 'I', 8)
        #self.cell(0, 10, 'Page ' + str(self.page_no()) + '/{nb}', 0, 0, 'C')

class PDFGen:
    def __init__(self, cardInfoFile, resultFile):
        self.cardInfoFile   = cardInfoFile
        self.resultFile     = resultFile

        pdf = PDF()
        pdf.alias_nb_pages()
        self.pdf = pdf

        pdf.add_page()
        self.heading("Memory tester report", 22)

        self.heading("Card info", 15)
        self.from_file(self.cardInfoFile)

        self.heading("Info about measurement and testing", 15)
        self.text(
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



    def heading(self, text, size):
        self.pdf.set_font('Times', 'B', size)
        self.pdf.cell(0, (2 / 3) * size, text, 0, 1)

    def text(self, text):
        self.pdf.set_font('Times', '', 12)
        self.pdf.multi_cell(0, 5, text)
        #self.pdf.ln()

    def from_file(self, file):
        with open(file, 'r') as f:
            txt = f.read()
        self.pdf.set_font('Times', '', 12)
        self.pdf.multi_cell(0, 5, txt)
        self.pdf.ln()

    def image(self, path, scale):
        width = pdf_w * scale
        self.pdf.image(path, (pdf_w - width) / 2, None, width)

    def measured_flow(self, data):
        self.text("Max data flow (write / read) = {0} Gb/s / {1} Gb/s".format(
            round(data["write_flow"].max(), 2),
            round(data["read_flow"].max() , 2)))
        self.text("Min data flow (write / read) = {0} Gb/s / {1} Gb/s".format(
            round(data["write_flow"].min(), 2),
            round(data["read_flow"].min() , 2)))
        self.text("There were transfered {0} - {1} AMM words in each test (for different burst counts)".format(
            int(data["write_words"].min()),
            int(data["write_words"].max())))

    def measured_lat(self, data):
        self.text("Min / avg / max latency = {0} ns / {1} ns / {2} ns".format(
            int(data["min_latency"].min()),
            int(np.average(data["avg_latency"])),
            int(data["max_latency"].max()) ))

    def report(self, fig_path, index, dev_info, data_seq, data_rand, data_seq_o, data_rand_o):
        self.pdf.add_page()
        self.heading("Memory interface: {0}".format(index + 1), 18)

        self.heading("AMM interface parameters", 15)
        self.text("DATA_WIDTH = {0}".format(int(dev_info["AMM_DATA_WIDTH"])))
        self.text("ADDR_WIDTH = {0}".format(int(dev_info["AMM_ADDR_WIDTH"])))
        self.text("BURST_COUNT_WIDTH = {0}".format(int(dev_info["AMM_BURST_WIDTH"])))
        self.text("FREQ = {0} MHz".format(dev_info["AMM_FREQ"] / 10 ** 6))
        self.pdf.ln()

        if data_seq["err_cnt"].max() != 0:
            self.text("Errors found during tests:")
            self.image(fig_path + "{0}_seq_errs.png".format(index), 0.8)
            self.pdf.add_page()
        else:
            self.text("No errors found during tests")

        self.heading("Data flow", 15)
        self.image(fig_path + "{0}_seq_flow.png".format(index), 0.8)
        self.image(fig_path + "{0}_rand_flow.png".format(index), 0.8)
        self.heading("Sequential indexing", 13)
        self.measured_flow(data_seq)
        self.heading("Random indexing", 13)
        self.measured_flow(data_rand)

        self.pdf.add_page()
        self.heading("Latency - full speed", 15)
        self.image(fig_path + "{0}_seq_lat.png" .format(index), 0.8)
        self.image(fig_path + "{0}_rand_lat.png" .format(index), 0.8)
        self.heading("Sequential indexing", 13)
        self.measured_lat(data_seq)
        self.heading("Random indexing", 13)
        self.measured_lat(data_rand)

        self.pdf.add_page()
        self.heading("Sequential indexing", 13)
        self.image(fig_path + "{0}_seq_hist.png" .format(index), 0.8)
        self.image(fig_path + "{0}_seq_spectrogram.png" .format(index), 0.8)
        self.heading("Random indexing", 13)
        self.image(fig_path + "{0}_rand_hist.png" .format(index), 0.8)
        self.image(fig_path + "{0}_rand_spectrogram.png" .format(index), 0.8)

        self.pdf.add_page()
        self.heading("Latency - max. one simultaneous read transaction", 15)
        self.image(fig_path + "{0}_seq_o_lat.png" .format(index), 0.8)
        self.image(fig_path + "{0}_rand_o_lat.png" .format(index), 0.8)
        self.heading("Sequential indexing", 13)
        self.measured_lat(data_seq_o)
        self.heading("Random indexing", 13)
        self.measured_lat(data_rand_o)

        self.pdf.add_page()
        self.heading("Sequential indexing", 13)
        self.image(fig_path + "{0}_seq_o_hist.png" .format(index), 0.8)
        self.image(fig_path + "{0}_seq_o_spectrogram.png" .format(index), 0.8)
        self.heading("Random indexing", 13)
        self.image(fig_path + "{0}_rand_o_hist.png" .format(index), 0.8)
        self.image(fig_path + "{0}_rand_o_spectrogram.png" .format(index), 0.8)

        self.pdf.add_page()
        self.heading("Zoom to average latencies", 13)
        self.image(fig_path + "{0}_seq_o_lat_avg.png" .format(index), 0.8)
        self.image(fig_path + "{0}_rand_o_lat_avg.png" .format(index), 0.8)


    def fin(self):
        self.pdf.output(self.resultFile, 'F')