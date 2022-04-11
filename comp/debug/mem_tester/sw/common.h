/*****************************************************
common.h: program for communication with mem-tester comp
Copyright (C) 2021 CESNET z. s. p. o.
Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>

SPDX-License-Identifier: BSD-3-Clause
*****************************************************/

#ifndef COMMON_MEM_TESTER
#define COMMON_MEM_TESTER

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <inttypes.h>
#include <err.h>
#include <unistd.h>
#include <string.h>
#include <stdbool.h>
#include <math.h>
#include <float.h>      //DBL_MAX
#include <time.h>

#include <libfdt.h>
#include <nfb/nfb.h>
#include <nfb/ndp.h>

#include <netcope/nccommon.h>
#include <netcope/eth.h>


#define REG_CHECK     false
#define REG_CHECK_CNT 1
#define REG_WRITE_CNT 1

#define MI_DATA_WIDTH   32

// -------------- //
// Support macros //
// -------------- //

#define ERR_GOTO(cond, toGo, code, ...)                 \
    do{                                                 \
        if(!(cond))                                     \
        {                                               \
            code = -1;                                  \
            fprintf(stderr,  __VA_ARGS__);              \
            fprintf(stderr,  "\n");                     \
            goto toGo;                                  \
        }                                               \
    }while(0)  

#define SWAP(a, b)      \
    do{                 \
        a ^= b;         \
        b ^= a;         \
        a ^= b;         \
    }while(0)


// --------------- //
// Support structs //
// --------------- //

struct DevConfig
{
    uint32_t amm_data_width;
    uint32_t amm_addr_width;
    uint32_t amm_burst_width;
    double   amm_freq;  //MHz
    uint32_t slicesCnt;
};

struct AMMProbeData_s
{
    uint32_t ctrlReg;
    bool     errOcc;
    uint32_t errCnt;
    uint32_t writeTicks;
    uint32_t readTicks;
    uint32_t totalTicks;
    uint32_t writeWords;
    uint32_t readWords;
    uint32_t reqCnt;
    uint32_t latencySum;
    uint32_t latencyMin;
    uint32_t latencyMax;
};

struct AMMProbeResults_s
{
    bool        errOcc;
    unsigned    errCnt;
    unsigned    burst;

    double      writeTime_ms;
    double      readTime_ms;
    double      totalTime_ms;

    double      writeFlow_bs;
    double      readFlow_bs;
    double      totalFlow_bs;

    uint32_t    writeWords;
    uint32_t    readWords;
    uint32_t    reqCnt;

    double      avgLatency_ns; 
    double      minLatency_ns; 
    double      maxLatency_ns; 
};

struct TestParams_s
{
    bool latencyToFirst;    // Measure latency to first AMM word [dafault: to last]
    bool onlyCSV;
    bool onlyOneSimultRead;
    char *testType;
    long burstCnt;
    double addrLimScale;
};

// -------------------- //
// Mem-tester adressess //
// -------------------- //

enum Registers_e
{
    CTRL_IN,
    CTRL_OUT,
    ERR_CNT,
    BURST_CNT,
    ADDR_LIM,

    AMM_GEN_CTRL,
    AMM_GEN_ADDR,
    AMM_GEN_DATA,
    AMM_GEN_BURST,

    PROBE_CTRL,
    PROBE_WR_TICKS,
    PROBE_RD_TICKS,
    PROBE_RW_TICKS,
    PROBE_WR_WORDS,
    PROBE_RD_WORDS,
    PROBE_REQ_CNT,
    PROBE_LATENCY_SUM,
    PROBE_LATENCY_MIN,
    PROBE_LATENCY_MAX,
    AMM_DATA_WIDTH_REG,
    AMM_ADDR_WIDTH_REG,
    AMM_BURST_WIDTH_REG,
    AMM_FREQ_REG,

    REG_CNT
};
 
 // Bits
enum CtrlIn_e
{
    RESET,
    RESET_EMIF,
    RUN_TEST,
    AMM_GEN_EN,
    RANDOM_ADDR_EN,
    ONLY_ONE_SIMULT_READ,
};

enum CtrlOut_e
{
    TEST_DONE,
    TEST_SUCCESS,
    ECC_ERR,
    CALIB_SUCCESS,
    CALIB_FAIL,
};

enum AMM_GEN_Ctrl_e
{
    MEM_WR,
    MEM_RD,

    BUFF_VLD,
    AMM_READY,
};

enum AMM_PROBE_Ctrl_e
{
    PROBE_RESET,
    LATENCY_TO_FIRST,
    WR_TICKS_OVF,
    RD_TICKS_OVF,
    RW_TICKS_OVF,
    WR_WORDS_OVF,
    RD_WORDS_OVF,
    REQ_CNT_OVF,
    LATENCY_TICKS_OVF,
    LATENCY_CNTERS_OVF,
};


// ----------------------- //
// Communication functions //
// ----------------------- //

uint32_t ReadReg(struct nfb_comp *comp, enum Registers_e reg);
bool WriteReg(struct nfb_comp *comp, enum Registers_e reg, uint32_t data);
bool WriteReg_bit(struct nfb_comp *comp, enum Registers_e reg, unsigned bit, bool val);
bool ToggleBit(struct nfb_comp *comp, enum Registers_e reg, unsigned bit);
bool WaitForBit(struct nfb_comp *comp, enum Registers_e reg, uint32_t bit, bool reqVal, unsigned tries, unsigned delay);


// -------------------- //
// Conversion functions //
// -------------------- //

double TicksToMS(double freq_MHz, uint32_t ticks);
double TicksToNS(double freq_MHz, uint32_t ticks);
double MSToDataFlow(struct DevConfig *devConfig, double time_ms, uint32_t words);
void AMMHexaToMISlices(uint32_t slicesCnt, uint32_t *slices, char *data);


// --------------- //
// Other functions //
// --------------- //

void PrintTicks(struct DevConfig *devConfig, uint32_t ticks, uint32_t words);
void PrintLatency(struct DevConfig *devConfig, uint32_t ticks);
uint32_t RandAddr(struct DevConfig *devConfig);
uint32_t RandMIData();

#endif