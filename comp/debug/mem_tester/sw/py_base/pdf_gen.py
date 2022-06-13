#!/usr/bin/env python3
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>

from fpdf import FPDF
from py_base.mem_tester_parser import run_cmd
import numpy as np

pdf_w = 210
pdf_h = 297

margin_x = 3.4
margin_y = 4.0

def float_to_str(nmb, prec):
    f = '{:,.' + str(prec) + 'f}'
    return f.format(nmb).replace(',', ' ')

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
    def __init__(self, resultFile, testScale, textInfo = None):
        self.resultFile = resultFile
        self.testScale = testScale
        self.textInfo   = textInfo

        pdf = PDF()
        pdf.alias_nb_pages()
        self.pdf = pdf

        pdf.add_page()
        self.heading("Memory tester report", 22)

        # Basic info from devTree
        self.heading("Info from device tree", 15)
        self.text("Card-name: {0}".format(run_cmd("nfb-info -q card")))
        self.text("Project:   {0}".format(run_cmd("nfb-info -q project")))

        self.heading("Test parameters", 15)
        self.text("Tests were performed on {0} % of the memory address space (to reduce test duration).".
            format(self.testScale * 100.0))

        if self.textInfo is not None:
            self.heading("User test info", 15)
            self.from_text(self.textInfo)

        self.heading("Info about measurement and testing", 15)
        self.text(
            "This measurement was performed using mem-tester component. "
            "It tests external memory using writes and reads to different addresses. "
            "During these tests the amm-probe measures latency and data flow.\n"

            "Multiple tests with different burst counts and indexing types "
            "were performed.\n"
            "Note: error checking is performed only during sequential indexing.\n"
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
        self.from_text(txt)

    def from_text(self, txt):
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
        self.text("There were transferred {0} - {1} AMM words in each test (for different burst counts)".format(
            int(data["write_words"].min()),
            int(data["write_words"].max())))

    def measured_lat(self, data):
        self.text("Min / avg / max latency = {0} ns / {1} ns / {2} ns".format(
            int(data["min_latency"].min()),
            int(np.average(data["avg_latency"])),
            int(data["max_latency"].max()) ))

    def test_status_single(self, data):
        eccStr  = "True"   if (data["ecc_err_occ"] == True) else "False"
        dur     = '{:.2f}'.format(data["total_time"])
        errCnt  = float_to_str(data["err_cnt"], 0)

        if (data["rw_ticks_ovf"]):
            dur = "counter overflow"
    
        self.text("Test duration: {0} ms".format(dur))
        self.text("ECC flag was set: " + eccStr)
        self.text("Error count: " + errCnt)

    def test_status(self, data, fig_path):
        eccStr  = "True"   if (data["ecc_err_occ"].any() == True) else "False"
        dur     = '{:.2f}'.format(data["total_time"].max())
        errCnt  = float_to_str(data["err_cnt"].max(), 0)

        if (data["rw_ticks_ovf"].any()):
            dur = "counter overflow"

        self.text("Maximal test duration: {0} ms".format(dur))
        self.text("ECC flag was set: " + eccStr)
        self.text("Maximal error count: " + errCnt)
        self.image(fig_path, 0.8)

    def report(self, fig_path, index, dev_info, data):
        self.pdf.add_page()
        self.heading("Memory interface: {0}".format(index + 1), 18)

        self.heading("AMM interface parameters", 15)
        self.text("DATA_WIDTH = {0}".format(int(dev_info["AMM_DATA_WIDTH"])))
        self.text("ADDR_WIDTH = {0}".format(int(dev_info["AMM_ADDR_WIDTH"])))
        self.text("BURST_COUNT_WIDTH = {0}".format(int(dev_info["AMM_BURST_WIDTH"])))
        self.text("FREQ = {0} kHz".format(float_to_str(dev_info["AMM_FREQ"] / 10 ** 3, 0)))
        refrPer = dev_info["DEF_REFRESH_PERIOD"] / (dev_info["AMM_FREQ"] / 10 ** 9)
        self.text("REFRESH PERIOD = {0} ns".format(float_to_str(refrPer, 0)))
        self.pdf.ln()

        self.text("{0} errors found during full memory sequential test".format(data["seq_long"]["err_cnt"]))

        self.heading("Data flow", 15)
        self.image(fig_path + "{0}_seq_flow.png".format(index), 0.8)
        self.image(fig_path + "{0}_rand_flow.png".format(index), 0.8)
        self.heading("Sequential indexing", 13)
        self.measured_flow(data["seq"])
        self.heading("Random indexing", 13)
        self.measured_flow(data["rand"])

        self.pdf.add_page()
        self.heading("Latency - full speed", 15)
        self.image(fig_path + "{0}_seq_lat.png" .format(index), 0.8)
        self.image(fig_path + "{0}_rand_lat.png" .format(index), 0.8)
        self.heading("Sequential indexing", 13)
        self.measured_lat(data["seq"])
        self.heading("Random indexing", 13)
        self.measured_lat(data["rand"])

        self.pdf.add_page()
        self.heading("Sequential indexing", 13)
        self.image(fig_path + "{0}_seq_hist.png" .format(index), 0.8)
        self.image(fig_path + "{0}_seq_spectrogram.png" .format(index), 0.8)
        self.heading("Random indexing", 13)
        self.image(fig_path + "{0}_rand_hist.png" .format(index), 0.8)
        self.image(fig_path + "{0}_rand_spectrogram.png" .format(index), 0.8)

        self.pdf.add_page()
        self.heading("Latency - max. one simultaneous read transaction", 15)
        self.text(
            "This test is limited to only one simultaneous reading transaction. "
            "It should better describe behavior of the memory latencies "
            "because the memory driver handles just one transaction at a time, and "
            "latencies are not cumulated due to transaction overlapping.")

        self.image(fig_path + "{0}_seq_o_lat.png" .format(index), 0.8)
        self.image(fig_path + "{0}_rand_o_lat.png" .format(index), 0.8)
        self.heading("Sequential indexing", 13)
        self.measured_lat(data["seq_o"])
        self.heading("Random indexing", 13)
        self.measured_lat(data["rand_o"])

        self.pdf.add_page()
        self.heading("Sequential indexing with only one simult read", 13)
        self.image(fig_path + "{0}_seq_o_hist.png" .format(index), 0.8)
        self.image(fig_path + "{0}_seq_o_spectrogram.png" .format(index), 0.8)
        self.heading("Random indexing with only one simult read", 13)
        self.image(fig_path + "{0}_rand_o_hist.png" .format(index), 0.8)
        self.image(fig_path + "{0}_rand_o_spectrogram.png" .format(index), 0.8)

        # self.pdf.add_page()
        # self.heading("Zoom to average latencies", 13)
        # self.image(fig_path + "{0}_seq_o_lat_avg.png" .format(index), 0.8)
        # self.image(fig_path + "{0}_rand_o_lat_avg.png" .format(index), 0.8)

        self.pdf.add_page()
        self.heading("Tests with no refresh", 15)
        self.text(
            "To disable refresh the refresh period was set to maximum, "
            "which should be larger than test duration. "
            "Because refresh is not performed in a specified time, some errors should be "
            "found during the sequential indexing test. "
            "Note that EMIF IP automatically corrects single-bit errors and just raises ECC flag.\n")

        self.heading("Single test on the whole memory", 13)
        self.test_status_single(data["seq_o_no_refr_long"])

        self.heading("Multiple tests on {0} % of the memory".format(self.testScale * 100), 13)
        self.text(
            "Maximum latencies on histograms below should be much lower because "
            "memory refreshes now do not disrupt reading operations.")

        self.test_status(data["seq_o_no_refr"], 
            fig_path + "{0}_seq_o_no_refr_errs.png".format(index))

        self.pdf.add_page()
        self.heading("Sequential indexing with no refresh", 13)
        self.image(fig_path + "{0}_seq_o_no_refr_hist.png" .format(index), 0.8)
        self.image(fig_path + "{0}_seq_o_no_refr_spectrogram.png" .format(index), 0.8)
        self.heading("Random indexing with no refresh", 13)
        self.image(fig_path + "{0}_rand_o_no_refr_hist.png" .format(index), 0.8)
        self.image(fig_path + "{0}_rand_o_no_refr_spectrogram.png" .format(index), 0.8)

    def fin(self):
        self.pdf.output(self.resultFile, 'F')