/*****************************************************
common.c: program for communication with mem-tester comp
Copyright (C) 2021 CESNET z. s. p. o.
Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>

SPDX-License-Identifier: BSD-3-Clause
*****************************************************/

#include "common.h"

const unsigned RegAddr[] = {
    [CTRL_IN]               = 0x000000,
    [CTRL_OUT]              = 0x000004,
    [ERR_CNT]               = 0x000008,
    [BURST_CNT]             = 0x00000C,
    [ADDR_LIM]              = 0x000010,
    [REFRESH_PERIOD]        = 0x000014,
    [REFRESH_DUR_SUM]       = 0x000018,
    [REFRESH_DUR_MIN]       = 0x00001C,
    [REFRESH_DUR_MAX]       = 0x000020,

    [AMM_GEN_CTRL]          = 0x000040,
    [AMM_GEN_ADDR]          = 0x000044,
    [AMM_GEN_DATA]          = 0x000048,
    [AMM_GEN_BURST]         = 0x00004C,

    [PROBE_CTRL]            = 0x000050,
    [PROBE_WR_TICKS]        = 0x000054,
    [PROBE_RD_TICKS]        = 0x000058,
    [PROBE_RW_TICKS]        = 0x00005C,
    [PROBE_WR_WORDS]        = 0x000060,
    [PROBE_RD_WORDS]        = 0x000064,
    [PROBE_REQ_CNT]         = 0x000068,
    [PROBE_LATENCY_SUM_1]   = 0x00006C,
    [PROBE_LATENCY_SUM_2]   = 0x000070,
    [PROBE_LATENCY_MIN]     = 0x000074,
    [PROBE_LATENCY_MAX]     = 0x000078,
    [AMM_DATA_WIDTH_REG]    = 0x00007C,
    [AMM_ADDR_WIDTH_REG]    = 0x000080,
    [AMM_BURST_WIDTH_REG]   = 0x000084,
    [AMM_FREQ_REG]          = 0x000088,

    [MMR_CTRL]              = 0x000090,
    [MMR_ADDR]              = 0x000094,
    [MMR_DATA]              = 0x000098,
    [MMR_BURST]             = 0x00009C,
};


uint32_t ReadReg(struct nfb_comp *comp, enum Registers_e reg)
{
    return nfb_comp_read32(comp, RegAddr[reg]);
}
bool WriteReg(struct nfb_comp *comp, enum Registers_e reg, uint32_t data)
{
    uint32_t readedData;

    for (unsigned t = 0; t < REG_WRITE_CNT; t++)
    {
        nfb_comp_write32(comp, RegAddr[reg], data);

        // Ensure that data was written 
        // Also it waits for data are written
        for (unsigned i = 0; i < REG_CHECK_CNT; i++)
            if ((readedData = ReadReg(comp, reg)) == data)
                break;

        if (readedData == data)
            break;
    }

    if(REG_CHECK)
    {
        if (readedData != data)
        {
            printf("Data were not written at address: 0x%08X (req: %d, written: %d)\n", RegAddr[reg], data, readedData);
            return false;
        }
        else 
            return true;
    }
    else
        return true;
}

bool WriteReg_bit(struct nfb_comp *comp, enum Registers_e reg, unsigned bit, bool val)
{
    uint32_t data = ReadReg(comp, reg);
    if (val)
        data |= 1 << bit;
    else
        data &= ~ (1 << bit);

    return WriteReg(comp, reg, data);
}

bool ToggleBit(struct nfb_comp *comp, enum Registers_e reg, unsigned bit)
{
    bool res;
    res = WriteReg_bit(comp, reg, bit, 1);
    res &= WriteReg_bit(comp, reg, bit, 0);
    return res;
}

bool WaitForBit(struct nfb_comp *comp, enum Registers_e reg, uint32_t bit, bool reqVal, unsigned tries, unsigned delay)
{
    uint32_t data;
    for (uint32_t i = 0; i < tries; i++)
    {
        usleep(delay);
        data = ReadReg(comp, reg);
        //printf("rdy = %d", (data >> bit) & 1);
        if (((data >> bit) & 1) == reqVal)
            return true;
    }

    return false;
}

double TicksToMS(double freq_MHz, uint32_t ticks)
{
    return ticks / (freq_MHz * 1000.0); 
}

double TicksToNS(double freq_MHz, uint32_t ticks)
{
    return (ticks / (freq_MHz)) * 1000.0; 
}

double MSToDataFlow(struct DevConfig *devConfig, double time_ms, uint32_t words)
{
    return ((double) devConfig->amm_data_width * words) / time_ms * 1000;
}

void AMMHexaToMISlices(uint32_t slicesCnt, uint32_t *slices, char *data)
{
    // 4 bits = 1 char in hexa
    const unsigned TmpLen = MI_DATA_WIDTH / 4;
    char tmp[TmpLen];
    uint32_t len = strlen(data);

    for(uint32_t s = 0; s < slicesCnt; s++)
        slices[s] = 0;

    for (uint32_t t = 0; t < TmpLen; t++)
        tmp[t] = '0';

    uint32_t pos = 0;
    for (int i = len - 1; i >= 0; i--, pos++)
    {
        tmp[(TmpLen - pos - 1) % TmpLen] = data[i];

        if((pos + 1) % TmpLen == 0 && pos != 0)
        {
            slices[pos / TmpLen] = strtoul(tmp, NULL, 16);
            for (uint32_t t = 0; t < TmpLen; t++)
                tmp[t] = '0';
        }
    }

    if (len % TmpLen != 0)
        slices[len / TmpLen] = strtoul(tmp, NULL, 16);
}


void PrintTicks(struct DevConfig *devConfig, uint32_t ticks, uint32_t words)
{
    double t_ms = TicksToMS(devConfig->amm_freq, ticks);
    printf("%7u (%.4lf ms | %.4lf Gb/s)\n", ticks, t_ms, MSToDataFlow(devConfig, t_ms, words) / 1000000.0);
}

void PrintLatency(struct DevConfig *devConfig, uint32_t ticks)
{
    double t_ms = TicksToMS(devConfig->amm_freq, ticks);
    printf("%7u (%.4lf ns)\n", ticks, t_ms * 1000000.0);
}

uint32_t RandAddr(struct DevConfig *devConfig)
{
    return abs(rand()) % ((unsigned) pow(2, devConfig->amm_addr_width));
}

uint32_t RandMIData()
{
    return abs(rand()) % ((unsigned) pow(2, MI_DATA_WIDTH));
}

