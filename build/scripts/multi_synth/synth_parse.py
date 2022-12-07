# synth_parse.py
# Copyright (C) 2020 CESNET z. s. p. o.
# Author(s): Jan Kubalek <kubalek@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

import argparse
from os import system, popen
from importlib.machinery import SourceFileLoader
from glob import glob

##########
# Parsing script arguments
##########

parser = argparse.ArgumentParser()

parser.add_argument("target_dir", help="Name of target directory with subdirectories containing multi_synth outputs")
parser.add_argument("-o","--output", help="Name of file for csv output to put in the target_dir (default: out.csv)",default="out.csv")

args = parser.parse_args()

if (args.target_dir[-1]=="/"):
    args.target_dir = args.target_dir[:-1]
of_name = args.target_dir+"/"+args.output

dirs = glob(args.target_dir+"/project_*")
print(args.target_dir)
print(dirs)

quartus_syn_util = "/*.syn.rpt"
quartus_imp_util = "/*.fit.rpt"
quartus_imp_time = "/*.sta.rpt"
vivado_runs_dir  = "/*.runs"
vivado_syn       = ""
vivado_imp       = ""
#vivado_syn       = vivado_runs_dir+"/synth_1"
#vivado_imp       = vivado_runs_dir+"/impl_1"
vivado_syn_util  = vivado_syn+"/*_utilization_synth.rpt"
vivado_imp_util  = vivado_imp+"/*_utilization_placed.rpt"
vivado_imp_time  = vivado_imp+"/*_timing_summary_routed.rpt"

with open(of_name,"w") as of:
    of.write(("Combination Name;"

              "Quartus Synthesis ALMs;"
              "Quartus Synthesis Logic ALUTs;"
              "Quartus Synthesis Memory ALUTs;"
              "Quartus Synthesis Registers;"
              "Quartus Synthesis Block Memory Bits (Approximate M20Ks);"
              "Quartus Synthesis DSPs;"

              "Quartus Implementation LABs;"
              "Quartus Implementation ALMs;"
              "Quartus Implementation Logic ALUTs;"
              "Quartus Implementation Memory ALUTs;"
              "Quartus Implementation Registers;"
              "Quartus Implementation M20Ks;"
              "Quartus Implementation DSPs;"
             #"Quartus Implementation Worst Case Data Delay;"
              "Quartus Implementation Worst Case Slack;"

              "Vivado Synthesis Logic LUTs;"
              "Vivado Synthesis Memory LUTs;"
              "Vivado Synthesis Registers;"
              "Vivado Synthesis CARRYs;"
              "Vivado Synthesis BRAMs;"
              "Vivado Synthesis URAMs;"
              "Vivado Synthesis DSPs;"

              "Vivado Implementation CLBs;"
              "Vivado Implementation Logic LUTs;"
              "Vivado Implementation Memory LUTs;"
              "Vivado Implementation Registers;"
              "Vivado Implementation CARRYs;"
              "Vivado Implementation BRAMs;"
              "Vivado Implementation URAMs;"
              "Vivado Implementation DSPs;"
              "Vivado Implementation Worst Case Data Delay;"
              "Vivado Implementation Worst Case Slack;"
              "\n"
              ))
    for i,d in enumerate(dirs):
        comb_name = d.split("/")[-1]
        comb_name = comb_name.split("_")[1:]
        comb_name = "_".join(comb_name)

        # Quartus values parsing
        # synthesis
        tmp = popen("grep \"Estimate of Logic utilization (ALMs needed)\" "+d+quartus_syn_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f9")
        q_syn_alm = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"Combinational ALUT usage for logic\" "+d+quartus_syn_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f8")
        q_syn_llut = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"Memory ALUT usage                 \" "+d+quartus_syn_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f6")
        q_syn_mlut = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"Dedicated logic registers         \" "+d+quartus_syn_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f6")
        q_syn_reg = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"Total block memory bits           \" "+d+quartus_syn_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f7")
        q_syn_brambits = tmp.readline().strip().replace(",","")
        tmp.close()
        if (q_syn_brambits==""):
            q_syn_bram_aprox = ("","",)
        else:
            q_syn_bram_aprox = (str(int(q_syn_brambits)//20480),str(int(q_syn_brambits)*2//20480),)
        q_syn_bram_aprox = " ("+" - ".join(q_syn_bram_aprox)+")"

        tmp = popen("grep \"Total DSP Blocks                  \" "+d+quartus_syn_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f6")
        q_syn_dsp = tmp.readline().strip().replace(",","")
        tmp.close()

        # implementation
        tmp = popen("grep \"Combinational ALUT usage for logic\" "+d+quartus_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f8")
        q_imp_llut = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"Memory ALUT usage                 \" "+d+quartus_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f6")
        q_imp_mlut = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"Dedicated logic registers         \" "+d+quartus_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f6")
        q_imp_reg = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"Primary logic registers           \" "+d+quartus_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f9")
        q_imp_reg_proc = tmp.readline().strip().replace(",","")
        try:
            q_imp_reg_proc = float(q_imp_reg)*100/float(q_imp_reg_proc)
            q_imp_reg += " (%6.2f%%)" % q_imp_reg_proc
        except:
            pass
        tmp.close()

        tmp = popen("grep \"Total LABs: \" "+d+quartus_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f9")
        q_imp_lab = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"Total LABs: \" "+d+quartus_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f11")
        q_imp_lab_proc = tmp.readline().strip().replace(",","")
        try:
            q_imp_lab_proc = float(q_imp_lab)*100/float(q_imp_lab_proc)
            q_imp_lab += " (%6.2f%%)" % q_imp_lab_proc
        except:
            pass
        tmp.close()

        tmp = popen("grep \"Logic utilization (ALMs needed\" "+d+quartus_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f12")
        q_imp_alm = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"Logic utilization (ALMs needed\" "+d+quartus_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f14")
        q_imp_alm_proc = tmp.readline().strip().replace(",","")
        try:
            q_imp_alm_proc = float(q_imp_alm)*100/float(q_imp_alm_proc)
            q_imp_alm += " (%6.2f%%)" % q_imp_alm_proc
        except:
            pass
        tmp.close()

        tmp = popen("grep \"M20K blocks                       \" "+d+quartus_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f5")
        q_imp_bram = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"M20K blocks                       \" "+d+quartus_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f7")
        q_imp_bram_proc = tmp.readline().strip().replace(",","")
        try:
            q_imp_bram_proc = float(q_imp_bram)*100/float(q_imp_bram_proc)
            q_imp_bram += " (%6.2f%%)" % q_imp_bram_proc
        except:
            pass
        tmp.close()

        tmp = popen("grep \"DSP Blocks Needed \" "+d+quartus_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f7")
        q_imp_dsp = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"DSP Blocks Needed \" "+d+quartus_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f9")
        q_imp_dsp_proc = tmp.readline().strip().replace(",","")
        try:
            q_imp_dsp_proc = float(q_imp_dsp)*100/float(q_imp_dsp_proc)
            q_imp_dsp += " (%6.2f%%)" % q_imp_dsp_proc
        except:
            pass
        tmp.close()

        tmp = popen("grep \"Path #1: Setup slack is\" "+d+quartus_imp_time+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f8")
        q_imp_slack = tmp.readline().strip()
        tmp.close()

        #tmp = popen("grep \"Data Delay    \" "+d+quartus_imp_time+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f5")
        #q_imp_time = tmp.readline().strip()
        #tmp.close()

        # Vivado values parsing
        # synthesis
        tmp = popen("grep \"LUT as Logic  \" "+d+vivado_syn_util+" | awk '{print $6 \" (\" $12 \"%)\"}'")
        v_syn_llut = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"LUT as Memory \" "+d+vivado_syn_util+" | awk '{print $6 \" (\" $12 \"%)\"}'")
        v_syn_mlut = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"CLB Registers \" "+d+vivado_syn_util+" | awk '{print $5 \" (\" $11 \"%)\"}'")
        v_syn_reg = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"CARRY8        \" "+d+vivado_syn_util+" | awk '{print $4 \" (\" $10 \"%)\"}'")
        v_syn_carry = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"Block RAM Tile\" "+d+vivado_syn_util+" | awk '{print $6 \" (\" $12 \"%)\"}'")
        v_syn_bram = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"URAM          \" "+d+vivado_syn_util+" | awk '{print $4 \" (\" $10 \"%)\"}'")
        v_syn_uram = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"DSPs          \" "+d+vivado_syn_util+" | awk '{print $4 \" (\" $10 \"%)\"}'")
        v_syn_dsp = tmp.readline().strip().replace(",","")
        tmp.close()

        # implementation
        tmp = popen("grep \"LUT as Logic  \" "+d+vivado_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f6")
        v_imp_llut = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"LUT as Logic  \" "+d+vivado_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f10")
        v_imp_llut_proc = tmp.readline().strip().replace(",","")
        try:
            v_imp_llut_proc = float(v_imp_llut)*100/float(v_imp_llut_proc)
            v_imp_llut += " (%6.2f%%)" % v_imp_llut_proc
        except:
            pass
        tmp.close()

        tmp = popen("grep \"LUT as Memory \" "+d+vivado_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f6")
        v_imp_mlut = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"LUT as Memory \" "+d+vivado_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f10")
        v_imp_mlut_proc = tmp.readline().strip().replace(",","")
        try:
            v_imp_mlut_proc = float(v_imp_mlut)*100/float(v_imp_mlut_proc)
            v_imp_mlut += " (%6.2f%%)" % v_imp_mlut_proc
        except:
            pass
        tmp.close()

        tmp = popen("grep \"CLB Registers \" "+d+vivado_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f5")
        v_imp_reg = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"CLB Registers \" "+d+vivado_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f9")
        v_imp_reg_proc = tmp.readline().strip().replace(",","")
        try:
            v_imp_reg_proc = float(v_imp_reg)*100/float(v_imp_reg_proc)
            v_imp_reg += " (%6.2f%%)" % v_imp_reg_proc
        except:
            pass
        tmp.close()

        tmp = popen("grep \"CARRY8        \" "+d+vivado_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f4")
        v_imp_carry = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"CARRY8        \" "+d+vivado_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f8")
        v_imp_carry_proc = tmp.readline().strip().replace(",","")
        try:
            v_imp_carry_proc = float(v_imp_carry)*100/float(v_imp_carry_proc)
            v_imp_carry += " (%6.2f%%)" % v_imp_carry_proc
        except:
            pass
        tmp.close()

        tmp = popen("grep \"CLB           \" "+d+vivado_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f4")
        v_imp_clb   = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"CLB           \" "+d+vivado_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f8")
        v_imp_clb_proc = tmp.readline().strip().replace(",","")
        try:
            v_imp_clb_proc = float(v_imp_clb)*100/float(v_imp_clb_proc)
            v_imp_clb += " (%6.2f%%)" % v_imp_clb_proc
        except:
            pass
        tmp.close()

        tmp = popen("grep \"Block RAM Tile\" "+d+vivado_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f6")
        v_imp_bram = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"Block RAM Tile\" "+d+vivado_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f10")
        v_imp_bram_proc = tmp.readline().strip().replace(",","")
        try:
            v_imp_bram_proc = float(v_imp_bram)*100/float(v_imp_bram_proc)
            v_imp_bram += " (%6.2f%%)" % v_imp_bram_proc
        except:
            pass
        tmp.close()

        tmp = popen("grep \"URAM          \" "+d+vivado_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f4")
        v_imp_uram = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"URAM          \" "+d+vivado_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f8")
        v_imp_uram_proc = tmp.readline().strip().replace(",","")
        try:
            v_imp_uram_proc = float(v_imp_uram)*100/float(v_imp_uram_proc)
            v_imp_uram += " (%6.2f%%)" % v_imp_uram_proc
        except:
            pass
        tmp.close()

        tmp = popen("grep \"DSPs          \" "+d+vivado_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f4")
        v_imp_dsp = tmp.readline().strip().replace(",","")
        tmp.close()

        tmp = popen("grep \"DSPs      |\" "+d+vivado_imp_util+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f8")
        v_imp_dsp_proc = tmp.readline().strip().replace(",","")
        print(d,vivado_imp_util)
        try:
            v_imp_dsp_proc = float(v_imp_dsp)*100/float(v_imp_dsp_proc)
            v_imp_dsp += " (%6.2f%%)" % v_imp_dsp_proc
        except:
            pass
        tmp.close()

        tmp = popen("grep \"Worst Slack\" "+d+vivado_imp_time+" | sed \"s/\s\s*/ /g\" | cut -d\",\" -f2 | cut -d\" \" -f4")
        v_imp_slack = tmp.readline().strip()[:-2]
        tmp.close()

        tmp = popen("grep \"Data Path Delay\" "+d+vivado_imp_time+" | sed \"s/\s\s*/ /g\" | cut -d\" \" -f5")
        v_imp_time = tmp.readline().strip()[:-2]
        tmp.close()

        # Conecatenate to output line
        out_line = [comb_name,

                    q_syn_alm,
                    q_syn_llut,
                    q_syn_mlut,
                    q_syn_reg,
                    q_syn_brambits+q_syn_bram_aprox,
                    q_syn_dsp,

                    q_imp_lab,
                    q_imp_alm,
                    q_imp_llut,
                    q_imp_mlut,
                    q_imp_reg,
                    q_imp_bram,
                    q_imp_dsp,
                   #q_imp_time,
                    q_imp_slack,

                    v_syn_llut,
                    v_syn_mlut,
                    v_syn_reg,
                    v_syn_carry,
                    v_syn_bram,
                    v_syn_uram,
                    v_syn_dsp,

                    v_imp_clb,
                    v_imp_llut,
                    v_imp_mlut,
                    v_imp_reg,
                    v_imp_carry,
                    v_imp_bram,
                    v_imp_uram,
                    v_imp_dsp,
                    v_imp_time,
                    v_imp_slack,
                    "\n"]
        out_line = ["-" if (x=="") else x for x in out_line]
        of.write(";".join(out_line))
