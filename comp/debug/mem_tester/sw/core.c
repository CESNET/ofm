/*****************************************************
core.c: program for communication with mem-tester component
Copyright (C) 2021 CESNET z. s. p. o.
Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>

SPDX-License-Identifier: BSD-3-Clause
*****************************************************/

#include "core.h"

struct nfb_device *device;
struct nfb_comp *component;
struct DevConfig devConfig;

//const unsigned LatTestMeasCnt = 20;
//const unsigned LatTestConfuseReads = 10;    // Reads from different addresses to ensure data wont be buffered in EMIF
//const unsigned lattestburst[lat_test_burst_cnt] = { 1, 4, 16, 32, 50, 64, 127 };
//https://onlinenumbertools.com/generate-integers
const unsigned LatTestBurst[LAT_TEST_BURST_CNT] = { 
    1, 7, 13, 19, 25, 31, 37, 43, 49, 55, 61, 67, 73, 79, 85, 91, 97, 103, 109, 115, 121, 127
};


// ---------------- //
// Common functions //
// ---------------- //

void GetDevConfig(struct DevConfig *config)
{
    config->amm_data_width      = ReadReg(component, AMM_DATA_WIDTH_REG);
    config->amm_addr_width      = ReadReg(component, AMM_ADDR_WIDTH_REG);
    config->amm_burst_width     = ReadReg(component, AMM_BURST_WIDTH_REG);
    config->amm_freq            = ReadReg(component, AMM_FREQ_REG) / 1000.0;
    config->slicesCnt           = config->amm_data_width / MI_DATA_WIDTH;
}

void PrintDevConfig(struct DevConfig *config)
{
    printf("    AMM_DATA_WIDTH          = %7d\n", config->amm_data_width);
    printf("    AMM_ADDR_WIDTH          = %7d\n", config->amm_addr_width);
    printf("    AMM_BURST_CNT_WIDTH     = %7d\n", config->amm_burst_width);
    printf("    AMM_FREQ [kHz]          = %.2lf\n", config->amm_freq);
    printf("    slicesCnt               = %7d\n", config->slicesCnt);
}

void PrintDevConfigCSV(struct DevConfig *config)
{
    printf("%7d %s"     , config->amm_data_width,   CSV_DELIM);
    printf("%7d %s"     , config->amm_addr_width,   CSV_DELIM);
    printf("%7d %s"     , config->amm_burst_width,  CSV_DELIM);
    printf("%.2lf \n"   , config->amm_freq);
    //printf("%7d\n"      , config->slicesCnt);
}

void PrintDevStatus()
{
    uint32_t data;
    data = ReadReg(component, CTRL_OUT);
    printf("  test done             = %7d\n", (data >> TEST_DONE)        & 1);
    printf("  test success          = %7d\n", (data >> TEST_SUCCESS)     & 1);
    printf("  ecc error occured     = %7d\n", (data >> ECC_ERR)          & 1);
    printf("  calib success         = %7d\n", (data >> CALIB_SUCCESS)    & 1);
    printf("  calib fail            = %7d\n", (data >> CALIB_FAIL)       & 1);

    data = ReadReg(component, AMM_GEN_CTRL);
    printf("  amm ready             = %7d\n", (data >> AMM_READY)       & 1);

}

void PrintDevStatusCSV()
{
    uint32_t data;
    data = ReadReg(component, CTRL_OUT);
    printf("%7d %s", (data >> TEST_DONE)        & 1, CSV_DELIM);
    printf("%7d %s", (data >> TEST_SUCCESS)     & 1, CSV_DELIM);
    printf("%7d %s", (data >> ECC_ERR)          & 1, CSV_DELIM);
    printf("%7d %s", (data >> CALIB_SUCCESS)    & 1, CSV_DELIM);
    printf("%7d %s", (data >> CALIB_FAIL)       & 1, CSV_DELIM);

    data = ReadReg(component, AMM_GEN_CTRL);
    printf("%7d \n", (data >> AMM_READY)          & 1);
}

void PrintRegs()
{
    uint32_t data;
    printf("------------------------------------------------------------\n");
    printf("Mem-tester core:\n");

    data = ReadReg(component, CTRL_IN);
    printf("ctrl_in:\n");
    printf("  reset                 = %7d\n", (data >> RESET)           & 1);
    printf("  reset EMIF            = %7d\n", (data >> RESET_EMIF)      & 1);
    printf("  run test              = %7d\n", (data >> RUN_TEST)        & 1);
    printf("  AMM_GEN enable        = %7d\n", (data >> AMM_GEN_EN)      & 1);
    printf("  random addr en        = %7d\n", (data >> RANDOM_ADDR_EN)  & 1);
    printf("  only one simult read  = %7d\n", (data >> ONLY_ONE_SIMULT_READ)  & 1);

    printf("ctrl_out:\n");
    PrintDevStatus();

    data = ReadReg(component, ERR_CNT);
    printf("err cnt                 = %7u\n", data);
    data = ReadReg(component, BURST_CNT);
    printf("burst cnt               = %7u\n", data);
    data = ReadReg(component, ADDR_LIM);
    printf("address limit           = %7u\n", data);

    printf("Config:\n");
    PrintDevConfig(&devConfig);

    printf("------------------------------------------------------------\n");
    printf("AMM_GEN:\n");

    data = ReadReg(component, AMM_GEN_CTRL);
    printf("ctrl:\n");
    printf("  mem write             = %7d\n", (data >> MEM_WR)          & 1);
    printf("  mem read              = %7d\n", (data >> MEM_RD)          & 1);
    printf("  buff valid            = %7d\n", (data >> BUFF_VLD)        & 1);
    printf("  amm ready             = %7d\n", (data >> AMM_READY)       & 1);

    data = ReadReg(component, AMM_GEN_ADDR);
    printf("addr                    = %7u\n", data);

    data = ReadReg(component, AMM_GEN_DATA);
    printf("data                    = %7u\n", data);

    data = ReadReg(component, AMM_GEN_BURST);
    printf("burst                   = %7u\n", data);


    PrintManualBuff(component);

    struct AMMProbeData_s probeData;
    struct AMMProbeResults_s probeResults;
    AMMProbeLoadData(&probeData);
    AMMProbeCalcResults(&probeData, &probeResults);
    AMMProbePrintResults(&probeResults);

    printf("Raw CSV:\n");
    AMMProbePrintDataCSV(&probeData);
}

bool Reset(bool emif)
{
    ToggleBit(component, CTRL_IN, (emif) ? RESET_EMIF : RESET);
    if (! WaitForBit(component, AMM_GEN_CTRL, AMM_READY, 1, AMM_READY_MAX_ASKS, AMM_READY_ASK_DELAY))
    {
        printf("AMM was not rested\n");
        return false;
    }

    return true;
}

int Init(char *dev, char *compatibile, long index, bool printCompCnt)
{
    // Opening component
    device = nfb_open(dev);
    if ( ! device)
    {
        fprintf(stderr, "Can't open NFB device (%s)\n", strerror(errno));
        return 1;
    }

    int compCnt = nfb_comp_count(device, compatibile);
    if (compCnt <= 0)
    {
        fprintf(stderr, "No compatibile component found\n");
        nfb_close(device);
        return 1;
    }

    if (printCompCnt)
        printf("%d\n", compCnt);

    //printf("Found %d components\n", compCnt);

    int compOffset = nfb_comp_find(device, compatibile, index);
    component = nfb_comp_open(device, compOffset);
    if ( ! component)
    {
        fprintf(stderr, "Cant open compatibile component\n");
        nfb_close(device);
        return 1;
    }

    GetDevConfig(&devConfig);

    return 0;
}

void Finish()
{
    nfb_comp_close(component);
    nfb_close(device);
}

// ------------------- //
// AMM probe functions //
// ------------------- //

void AMMProbeLoadData(struct AMMProbeData_s *data)
{
    data->errOcc            = ! ((ReadReg(component, CTRL_OUT) >> TEST_SUCCESS) & 1);
    data->errCnt            = ReadReg(component, ERR_CNT);
    data->ctrlReg           = ReadReg(component, PROBE_CTRL);
    data->writeTicks        = ReadReg(component, PROBE_WR_TICKS);
    data->readTicks         = ReadReg(component, PROBE_RD_TICKS);
    data->totalTicks        = ReadReg(component, PROBE_RW_TICKS);
    data->writeWords        = ReadReg(component, PROBE_WR_WORDS);
    data->readWords         = ReadReg(component, PROBE_RD_WORDS);
    data->reqCnt            = ReadReg(component, PROBE_REQ_CNT);
    data->latencySum        = ReadReg(component, PROBE_LATENCY_SUM);
    data->latencyMin        = ReadReg(component, PROBE_LATENCY_MIN);
    data->latencyMax        = ReadReg(component, PROBE_LATENCY_MAX);
}

void AMMProbeClearResults(struct AMMProbeResults_s *data)
{
    data->errOcc           = 0;
    data->burst            = 0;
    data->writeTime_ms     = 0;
    data->readTime_ms      = 0;
    data->totalTime_ms     = 0;
    data->writeFlow_bs     = 0;
    data->readFlow_bs      = 0;
    data->totalFlow_bs     = 0;
    data->writeWords       = 0;
    data->readWords        = 0;
    data->reqCnt           = 0;
    data->avgLatency_ns    = 0;
    data->minLatency_ns    = DBL_MAX;
    data->maxLatency_ns    = 0;
}

void AMMProbeCalcResults(struct AMMProbeData_s *data, struct AMMProbeResults_s *res)
{
    // TODO:
    // errOcc
    // burst
    res->errOcc             = data->errOcc;
    res->errCnt             = data->errCnt;

    res->writeTime_ms       = TicksToMS(devConfig.amm_freq, data->writeTicks);
    res->readTime_ms        = TicksToMS(devConfig.amm_freq, data->readTicks);
    res->totalTime_ms       = TicksToMS(devConfig.amm_freq, data->totalTicks);

    res->writeFlow_bs       = MSToDataFlow(&devConfig, res->writeTime_ms, data->writeWords);
    res->readFlow_bs        = MSToDataFlow(&devConfig, res->readTime_ms , data->readWords);
    res->totalFlow_bs       = MSToDataFlow(&devConfig, res->totalTime_ms, data->writeWords + data->writeWords);     //TODO

    res->writeWords         = data->writeWords;
    res->readWords          = data->readWords;
    res->reqCnt             = data->reqCnt;

    res->avgLatency_ns      = TicksToNS(devConfig.amm_freq, data->latencySum) / res->reqCnt;
    res->minLatency_ns      = TicksToNS(devConfig.amm_freq, data->latencyMin);
    res->maxLatency_ns      = TicksToNS(devConfig.amm_freq, data->latencyMax);
}

void AMMProbeAddResults(struct AMMProbeData_s *data, struct AMMProbeResults_s *res)
{
    struct AMMProbeResults_s tmp;
    AMMProbeCalcResults(data, &tmp);

    res->errOcc           |= tmp.errOcc;
    res->errCnt           += tmp.errCnt;

    res->writeTime_ms     += tmp.writeTime_ms;
    res->readTime_ms      += tmp.readTime_ms;
    res->totalTime_ms     += tmp.totalTime_ms;
    res->writeFlow_bs     += tmp.writeFlow_bs;
    res->readFlow_bs      += tmp.readFlow_bs;
    res->totalFlow_bs     += tmp.totalFlow_bs;
    res->writeWords       += tmp.writeWords;
    res->readWords        += tmp.readWords;
    res->reqCnt           += tmp.reqCnt;
    res->avgLatency_ns    += tmp.avgLatency_ns;
    res->minLatency_ns     = (res->minLatency_ns < tmp.minLatency_ns) ? res->minLatency_ns : tmp.minLatency_ns;
    res->maxLatency_ns     = (res->maxLatency_ns > tmp.maxLatency_ns) ? res->maxLatency_ns : tmp.maxLatency_ns;
}

void AMMProbeAvgResults(struct AMMProbeResults_s *res, unsigned resCnt)
{
    res->writeTime_ms     /= resCnt;
    res->readTime_ms      /= resCnt;
    res->totalTime_ms     /= resCnt;
    res->writeFlow_bs     /= resCnt;
    res->readFlow_bs      /= resCnt;
    res->totalFlow_bs     /= resCnt;
    res->writeWords       /= resCnt;
    res->readWords        /= resCnt;
    res->reqCnt           /= resCnt;
    res->avgLatency_ns    /= resCnt;
}

void AMMProbePrintResults(struct AMMProbeResults_s *data)
{
    printf("------------------------------------------------------------\n");
    printf("AMM probe:\n");

    printf("    err occ                 = %u\n", data->errOcc);
    printf("    err cnt                 = %u\n", data->errCnt);
    printf("    burst count             = %u\n", data->burst);
    printf("\n");
    printf("    write time [ms]         = %.4lf\n", data->writeTime_ms);
    printf("    read  time [ms]         = %.4lf\n", data->readTime_ms);
    printf("    total time [ms]         = %.4lf\n", data->totalTime_ms);

    printf("\n");
    printf("    write flow [Gb/s]       = %.4lf\n", data->writeFlow_bs / 1000000000.0);
    printf("    read  flow [Gb/s]       = %.4lf\n", data->readFlow_bs  / 1000000000.0);
    printf("    total flow [Gb/s]       = %.4lf\n", data->totalFlow_bs / 1000000000.0);

    printf("\n");
    printf("    words written           = %7u\n", data->writeWords);
    printf("    words read              = %7u\n", data->readWords);
    printf("    request made            = %7u\n", data->reqCnt);

    printf("\n");
    printf("    latency avg [ns]        = %.4lf\n", data->avgLatency_ns);
    printf("    latency min [ns]        = %.4lf\n", data->minLatency_ns);
    printf("    latency max [ns]        = %.4lf\n", data->maxLatency_ns);

    if (data->errOcc)
        printf("Err occured\n");
 
    if (data->writeWords != data->readWords)
        printf("Warning, readed word cnt do not match written word cnt\n");

    //uint32_t burst_cnt = ReadReg(component, BURST_CNT);
    //if (data->readWords != data->reqCnt * burst_cnt)
    //    printf("Warning, requested and received word cnts do not match\n");
}

void AMMProbePrintResultsCSV(struct AMMProbeResults_s *data)
{
    printf("%u  %s ", data->errCnt          , CSV_DELIM);
    //printf("%u  %s ", data->burst           , CSV_DELIM);
    //printf("%lf %s ", data->writeTime_ms    , CSV_DELIM);
    //printf("%lf %s ", data->readTime_ms     , CSV_DELIM);
    //printf("%lf %s ", data->totalTime_ms    , CSV_DELIM);
    printf("%lf %s ", data->writeFlow_bs    , CSV_DELIM);
    printf("%lf %s ", data->readFlow_bs     , CSV_DELIM);
    printf("%lf %s ", data->totalFlow_bs    , CSV_DELIM);
    printf("%u  %s ", data->writeWords      , CSV_DELIM);
    printf("%u  %s ", data->readWords       , CSV_DELIM);
    printf("%u  %s ", data->reqCnt          , CSV_DELIM);
    printf("%lf %s ", data->minLatency_ns   , CSV_DELIM);
    printf("%lf %s ", data->maxLatency_ns   , CSV_DELIM);
    printf("%lf \n" , data->avgLatency_ns);
}

//void AMMProbePrintData(struct AMMProbeData_s *data)
//{
//    printf("------------------------------------------------------------\n");
//    printf("AMM probe:\n");
// 
//    printf("ctrl:\n");
//    printf("  reset                 = %7d\n", (data->ctrlReg >> PROBE_RESET)         & 1);
//    printf("  to first              = %7d\n", (data->ctrlReg >> LATENCY_TO_FIRST)    & 1);
//    printf("  write ticks overflow  = %7d\n", (data->ctrlReg >> WR_TICKS_OVF)        & 1);
//    printf("  read ticks overflow   = %7d\n", (data->ctrlReg >> RD_TICKS_OVF)        & 1);
//    printf("  r/w ticks overflow    = %7d\n", (data->ctrlReg >> RW_TICKS_OVF)        & 1);
//    printf("  write words overflow  = %7d\n", (data->ctrlReg >> WR_WORDS_OVF)        & 1);
//    printf("  read words overflow   = %7d\n", (data->ctrlReg >> RD_WORDS_OVF)        & 1);
//    printf("  req words overflow    = %7d\n", (data->ctrlReg >> REQ_CNT_OVF)         & 1);
//    printf("  latency tick overflow = %7d\n", (data->ctrlReg >> LATENCY_TICKS_OVF)   & 1);
//    printf("  latency cnters ovf    = %7d\n", (data->ctrlReg >> LATENCY_CNTERS_OVF)  & 1);
// 
//    printf("write ticks             = ");   PrintTicks(&devConfig, data->writeTicks, data->writeWords);
//    printf("read ticks              = ");   PrintTicks(&devConfig, data->readTicks , data->readWords);
//    printf("total ticks             = ");   PrintTicks(&devConfig, data->totalTicks, data->writeWords + data->readWords);   //TODO
//    printf("words written           = %7u\n", data->writeWords);
//    printf("words read              = %7u\n", data->readWords);
//    printf("request made            = %7u\n", data->reqCnt);
//    printf("latency sum ticks       = %7u\n", data->latencySum);
//    printf("latency avg ticks       = ");   PrintLatency(&devConfig, (double) data->latencySum / data->reqCnt);
//    printf("latency min ticks       = ");   PrintLatency(&devConfig, data->latencyMin);
//    printf("latency max ticks       = ");   PrintLatency(&devConfig, data->latencyMax);
// 
//    //uint32_t burst_cnt = ReadReg(component, BURST_CNT);
// 
//    if (data->writeWords != data->readWords)
//        printf("Warning, readed word cnt do not match written word cnt\n");
//    //if (data->readWords != data->reqCnt * burst_cnt)
//    //    printf("Warning, requested and received word cnts do not match\n");
//}

void AMMProbePrintDataCSV(struct AMMProbeData_s *data)
{
    uint32_t errCnt = ReadReg(component, ERR_CNT);

    printf("%7u %s ", errCnt          , CSV_DELIM);
    //printf("%7u %s ", data->ctrlReg   , CSV_DELIM);
    printf("%7u %s ", data->writeTicks, CSV_DELIM);
    printf("%7u %s ", data->readTicks , CSV_DELIM);
    printf("%7u %s ", data->totalTicks, CSV_DELIM);
    printf("%7u %s ", data->writeWords, CSV_DELIM);
    printf("%7u %s ", data->readWords , CSV_DELIM);
    printf("%7u %s ", data->reqCnt    , CSV_DELIM);
    printf("%7u %s ", data->latencySum, CSV_DELIM);
    printf("%7u %s ", data->latencyMin, CSV_DELIM);
    printf("%7u \n", data->latencyMax);
}

// ----------------- //
// AMM gen functions //
// ----------------- //

void PrintManualBuff()
{
    uint32_t prevAddr = ReadReg(component, AMM_GEN_ADDR);
    uint32_t burst_cnt = 0;

    burst_cnt = ReadReg(component, AMM_GEN_BURST);

    printf("manual data (%d bursts):\n", burst_cnt);
    for(unsigned b = 0; b < burst_cnt; b++)
    {
        printf("0x");
        for(int s = devConfig.slicesCnt - 1; s >= 0; s--)
        {
            WriteReg(component, AMM_GEN_ADDR, b * devConfig.slicesCnt + s);
            printf("%08X", ReadReg(component, AMM_GEN_DATA));
        }
        printf("\n");
    }

    WriteReg(component, AMM_GEN_ADDR, prevAddr);  // Restore address
}

void FillManualBuff(long burst, char *data)
{
    uint32_t slicedData[devConfig.slicesCnt];
    AMMHexaToMISlices(devConfig.slicesCnt, slicedData, data);

    uint32_t prevAddr = ReadReg(component, AMM_GEN_ADDR);
    for(uint32_t s = 0; s < devConfig.slicesCnt; s++)
    {
        WriteReg(component, AMM_GEN_ADDR, burst * devConfig.slicesCnt + s);
        WriteReg(component, AMM_GEN_DATA, slicedData[s]);
    }
    WriteReg(component, AMM_GEN_ADDR, prevAddr);  // Restore address
}

void WriteManualBuff()
{
    WriteReg_bit(component, CTRL_IN, AMM_GEN_EN, 1);
    ToggleBit(component, AMM_GEN_CTRL, MEM_WR);
    WriteReg_bit(component, CTRL_IN, AMM_GEN_EN, 0);
}

void ReadManualBuff()
{
    WriteReg_bit(component, CTRL_IN, AMM_GEN_EN, 1);
    ToggleBit(component, AMM_GEN_CTRL, MEM_RD);
    WriteReg_bit(component, CTRL_IN, AMM_GEN_EN, 0);
}

void AMMGenSetAddr(long addr)
{
    WriteReg(component, AMM_GEN_ADDR, addr);
}

void AMMGenSetBurst(long burst)
{
    WriteReg(component, AMM_GEN_BURST, burst);
}


// ---------------------- //
// Test related functions //
// ---------------------- //

void PrintTestResult()
{
    uint32_t errCnt = ReadReg(component, ERR_CNT);
    if (errCnt == 0)
        printf("No errors found during test\n");
    else
        printf("Found %d wrong words during test\n", errCnt);

    struct AMMProbeData_s probeData;
    struct AMMProbeResults_s    probeResults;
    AMMProbeLoadData(&probeData);
    //AMMProbePrintData(&probeData);
    AMMProbeCalcResults(&probeData, &probeResults);
    AMMProbePrintResults(&probeResults);
    printf("Raw CSV:\n");
    AMMProbePrintDataCSV(&probeData);
}

bool RunTest_intern(bool onlyCSV)
{
    ToggleBit(component, CTRL_IN, RUN_TEST);

    if (! WaitForBit(component, CTRL_OUT, TEST_DONE, 1, TEST_MAX_ASKS, TEST_ASK_DELAY))
    {
        printf("Test was not finished in time\n");
        return false;
    }

    if (onlyCSV)
    {
        struct AMMProbeData_s       probeData;
        struct AMMProbeResults_s    probeResults;

        AMMProbeLoadData(&probeData);
        AMMProbeCalcResults(&probeData, &probeResults);
        AMMProbePrintResultsCSV(&probeResults);
    }
    else
    {
        PrintTestResult(component);
    }

    return true;
}

uint32_t GetAddLim(uint32_t burst, uint32_t maxAddr)
{
    //uint32_t maxAddr = pow(2, devConfig.amm_addr_width);

    uint32_t addrLim = 0;
    while (addrLim < maxAddr - 2 * burst)
        addrLim += burst;

    return addrLim;
}

bool RunTest(struct TestParams_s *testParams)
{
    if (! Reset(false))
        return false;

    // Set test parameters
    //WriteReg(component, ADDR_LIM, (unsigned) pow(2, devConfig.amm_addr_width) - pow(2, devConfig.amm_burst_width)); // testParams->burstCnt);
    WriteReg(component, ADDR_LIM, 
        GetAddLim(testParams->burstCnt, 
        pow(2, devConfig.amm_addr_width) * testParams->addrLimScale));
    WriteReg(component, BURST_CNT, testParams->burstCnt);
    WriteReg_bit(component, PROBE_CTRL, LATENCY_TO_FIRST, testParams->latencyToFirst);
    WriteReg_bit(component, CTRL_IN, ONLY_ONE_SIMULT_READ, testParams->onlyOneSimultRead);

    // Select test type
    bool testTypeMatch = false;
    if (strcmp(testParams->testType, TEST_SEQ) == 0 || strcmp(testParams->testType, TEST_ALL) == 0)
    {
        if ( ! testParams->onlyCSV)
            printf("Running sequential test ...\n");

        testTypeMatch = true;
        WriteReg_bit(component, CTRL_IN, RANDOM_ADDR_EN, 0);
        // TODO Handle err
        RunTest_intern(testParams->onlyCSV);
    }
    if (strcmp(testParams->testType, TEST_RAND) == 0 || strcmp(testParams->testType, TEST_ALL) == 0)
    {
        if ( ! testParams->onlyCSV)
            printf("Running random indexing test ...\n");

        testTypeMatch = true;
        WriteReg_bit(component, CTRL_IN, RANDOM_ADDR_EN, 1);
        RunTest_intern(testParams->onlyCSV);
    }
    if (strcmp(testParams->testType, TEST_LAT_SEQ) == 0 || strcmp(testParams->testType, TEST_ALL) == 0)
    {
        if ( ! testParams->onlyCSV)
            printf("Running latency test ...\n");

        testTypeMatch = true;
        RunLatTest_intern(false);
    }
    if (strcmp(testParams->testType, TEST_LAT_RAND) == 0 || strcmp(testParams->testType, TEST_ALL) == 0)
    {
        if ( ! testParams->onlyCSV)
            printf("Running latency test ...\n");

        testTypeMatch = true;
        RunLatTest_intern(true);
    }

    return testTypeMatch;
}

void SetRandomAMMData(uint32_t burstCnt)
{
    for (unsigned d = 0; d < burstCnt; d ++)
    {
        for(uint32_t s = 0; s < devConfig.slicesCnt; s++)
        {
            WriteReg(component, AMM_GEN_ADDR, d * devConfig.slicesCnt + s);
            WriteReg(component, AMM_GEN_DATA, RandMIData());
        }
    }

}

unsigned CmpRandomAMMData(uint32_t burstCnt)
{
    unsigned errCnt = 0;

    for (unsigned d = 0; d < burstCnt; d ++)
    {
        for(uint32_t s = 0; s < devConfig.slicesCnt; s++)
        {
            WriteReg(component, AMM_GEN_ADDR, d * devConfig.slicesCnt + s);
            uint32_t data = ReadReg(component, AMM_GEN_DATA);

            if (data != RandMIData())
                errCnt++;
        }
    }

    return errCnt;
}

bool RunLatTest_intern(bool rand)
{
    struct AMMProbeResults_s avgProbeResults[LAT_TEST_BURST_CNT];
    WriteReg_bit(component, CTRL_IN, AMM_GEN_EN, 1);
    //WriteReg_bit(component, PROBE_CTRL, LATENCY_TO_FIRST, 0);

    for (unsigned b = 0; b < LAT_TEST_BURST_CNT; b ++)
    {
        uint32_t burstCnt = LatTestBurst[b];

        AMMProbeClearResults(&avgProbeResults[b]);
        avgProbeResults[b].burst = burstCnt;
        WriteReg(component, AMM_GEN_BURST, burstCnt);

        // Write random data
        srand(LAT_TEST_SEED);
        uint32_t addr = 0;
        for (unsigned i = 0; i < LAT_TEST_ADDR_CNT; i ++)
        {
            if (rand)
                addr = RandAddr(&devConfig);
            else
                addr += burstCnt;

            SetRandomAMMData(burstCnt);
            WriteReg(component, AMM_GEN_ADDR, addr);
            ToggleBit(component, AMM_GEN_CTRL, MEM_WR);

            //printf("Write %d\n", i);
            //PrintManualBuff();

            //usleep(1000);
        }

        // Read and check random data
        addr = 0;
        srand(LAT_TEST_SEED);
        for (unsigned i = 0; i < LAT_TEST_ADDR_CNT; i ++)
        {
            if (rand)
                addr = RandAddr(&devConfig);
            else
                addr += burstCnt;

            ToggleBit(component, PROBE_CTRL, PROBE_RESET);
            WriteReg(component, AMM_GEN_ADDR, addr);
            ToggleBit(component, AMM_GEN_CTRL, MEM_RD);
            if (! WaitForBit(component, AMM_GEN_CTRL, BUFF_VLD, 1, AMM_READY_MAX_ASKS, AMM_READY_ASK_DELAY))
            {
                printf("BUFF VLD wait error");
                return false;
            }

            //printf("Check %d\n", i);
            //PrintManualBuff();

            unsigned errCnt = CmpRandomAMMData(burstCnt);

            if (errCnt)
                printf("%d errors found during test\n", errCnt);

            struct AMMProbeData_s probeData;
            AMMProbeLoadData(&probeData);
            //AMMProbePrintData(&probeData);

            if (probeData.readWords != burstCnt)
                printf("%d words readed (requested %d)\n", probeData.readWords, burstCnt);
            if (probeData.reqCnt != 1)
                printf("%d request made (requested %d)\n", probeData.reqCnt, 1);

            AMMProbeAddResults(&probeData, &avgProbeResults[b]);
        }

        AMMProbeAvgResults(&avgProbeResults[b], LAT_TEST_ADDR_CNT);
        //AMMProbePrintResults(&avgProbeResults[b]);
    }

    for (unsigned b = 0; b < LAT_TEST_BURST_CNT; b ++)
        AMMProbePrintResultsCSV(&avgProbeResults[b]);

    WriteReg_bit(component, CTRL_IN, AMM_GEN_EN, 0);
    return true;
}

/*
// Confuse writes and reads - to ensure data wont be buffered in EMIF
void ConfuseEMIF(uint32_t burstCnt)
{
    for (unsigned c = 0; c < LatTestConfuseReads; c ++)
    {
        // generate random data
        for (unsigned d = 0; d < burstCnt; d ++)
        {
            for(uint32_t s = 0; s < devConfig.slicesCnt; s++)
            {
                WriteReg(component, AMM_GEN_ADDR, d * devConfig.slicesCnt + s);
                WriteReg(component, AMM_GEN_DATA, RandMIData());
            }
        }

        WriteReg(component, AMM_GEN_ADDR, RandAddr(&devConfig));
        ToggleBit(component, AMM_GEN_CTRL, MEM_WR);
    }

    for (unsigned c = 0; c < LatTestConfuseReads; c ++)
    {
        WriteReg(component, AMM_GEN_ADDR, RandAddr(&devConfig));
        ToggleBit(component, AMM_GEN_CTRL, MEM_RD);
    }
}

bool RunLatTest_intern(bool confuse, bool rand)
{
    struct AMMProbeResults_s avgProbeResults[LAT_TEST_BURST_CNT];
    WriteReg_bit(component, CTRL_IN, AMM_GEN_EN, 1);
    //WriteReg_bit(component, PROBE_CTRL, LATENCY_TO_FIRST, 0);

    for (unsigned b = 0; b < LAT_TEST_BURST_CNT; b ++)
    {
        uint32_t burstCnt = LatTestBurst[b];
        uint32_t addr = 0;

        AMMProbeClearResults(&avgProbeResults[b]);
        avgProbeResults[b].burst = burstCnt;
        WriteReg(component, AMM_GEN_BURST, burstCnt);

        if (rand)
        {
            for (unsigned i = 0; i < LatTestMeasCnt; i ++)
            {
                addr = RandAddr(&devConfig);

                // generate random data
                for (unsigned d = 0; d < burstCnt; d ++)
                {
                    for(uint32_t s = 0; s < devConfig.slicesCnt; s++)
                    {
                        WriteReg(component, AMM_GEN_ADDR, d * devConfig.slicesCnt + s);
                        WriteReg(component, AMM_GEN_DATA, d * devConfig.slicesCnt + s);    // TODO - create random data
                    }
                }

                // Write test data
                WriteReg(component, AMM_GEN_ADDR, addr);
                ToggleBit(component, AMM_GEN_CTRL, MEM_WR);

                if (confuse)
                    ConfuseEMIF(burstCnt);    // Can overwite correct data!

                usleep(1000);

                // Correct read
                ToggleBit(component, PROBE_CTRL, PROBE_RESET);
                WriteReg(component, AMM_GEN_ADDR, addr);
                ToggleBit(component, AMM_GEN_CTRL, MEM_RD);
                if (! WaitForBit(component, AMM_GEN_CTRL, BUFF_VLD, 1, AMM_READY_MAX_ASKS, AMM_READY_ASK_DELAY))
                {
                    printf("BUFF VLD wait error");
                    return false;
                }

                // Check data
                unsigned errCnt = 0;
                for (unsigned d = 0; d < burstCnt; d ++)
                {
                    for(uint32_t s = 0; s < devConfig.slicesCnt; s++)
                    {
                        uint32_t data;
                        WriteReg(component, AMM_GEN_ADDR, d * devConfig.slicesCnt + s);
                        data = ReadReg(component, AMM_GEN_DATA);
                        if (data != d * devConfig.slicesCnt + s)
                            errCnt ++;
                    }
                }

                if (errCnt)
                    printf("%d errors found during test\n", errCnt);

                //PrintManualBuff(component);
                //PrintTestResult(component);

                struct AMMProbeData_s probeData;
                AMMProbeLoadData(&probeData);
                //AMMProbePrintData(&probeData);

                if (probeData.readWords != burstCnt)
                    printf("%d words readed (requested %d)\n", probeData.readWords, burstCnt);
                if (probeData.reqCnt != 1)
                    printf("%d request made (requested %d)\n", probeData.reqCnt, 1);

                AMMProbeAddResults(&probeData, &avgProbeResults[b]);
            }
        }
        else
        {
            //TODO - Make it better

            for (unsigned i = 0; i < LatTestMeasCnt; i ++, addr += burstCnt)
            {
                // generate random data
                for (unsigned d = 0; d < burstCnt; d ++)
                {
                    for(uint32_t s = 0; s < devConfig.slicesCnt; s++)
                    {
                        WriteReg(component, AMM_GEN_ADDR, d * devConfig.slicesCnt + s);
                        WriteReg(component, AMM_GEN_DATA, d * devConfig.slicesCnt + s);    // TODO - create random data
                    }
                }

                // Write test data
                WriteReg(component, AMM_GEN_ADDR, addr);
                ToggleBit(component, AMM_GEN_CTRL, MEM_WR);
            }

            usleep(1000);
            addr = 0;

            for (unsigned i = 0; i < LatTestMeasCnt; i ++, addr += burstCnt)
            {
                ToggleBit(component, PROBE_CTRL, PROBE_RESET);
                WriteReg(component, AMM_GEN_ADDR, addr);
                ToggleBit(component, AMM_GEN_CTRL, MEM_RD);
                if (! WaitForBit(component, AMM_GEN_CTRL, BUFF_VLD, 1, AMM_READY_MAX_ASKS, AMM_READY_ASK_DELAY))
                {
                    printf("BUFF VLD wait error");
                    return false;
                }

                // Check data
                unsigned errCnt = 0;
                for (unsigned d = 0; d < burstCnt; d ++)
                {
                    for(uint32_t s = 0; s < devConfig.slicesCnt; s++)
                    {
                        uint32_t data;
                        WriteReg(component, AMM_GEN_ADDR, d * devConfig.slicesCnt + s);
                        data = ReadReg(component, AMM_GEN_DATA);
                        if (data != d * devConfig.slicesCnt + s)
                            errCnt ++;
                    }
                }

                if (errCnt)
                    printf("%d errors found during test\n", errCnt);

                //PrintManualBuff(component);
                //PrintTestResult(component);

                struct AMMProbeData_s probeData;
                AMMProbeLoadData(&probeData);
                //AMMProbePrintData(&probeData);

                if (probeData.readWords != burstCnt)
                    printf("%d words readed (requested %d)\n", probeData.readWords, burstCnt);
                if (probeData.reqCnt != 1)
                    printf("%d request made (requested %d)\n", probeData.reqCnt, 1);

                AMMProbeAddResults(&probeData, &avgProbeResults[b]);
            } 
        }

        AMMProbeAvgResults(&avgProbeResults[b], LatTestMeasCnt);
        //AMMProbePrintResults(&avgProbeResults[b]);
    }

    for (unsigned b = 0; b < LAT_TEST_BURST_CNT; b ++)
        AMMProbePrintResultsCSV(&avgProbeResults[b]);

    WriteReg_bit(component, CTRL_IN, AMM_GEN_EN, 0);
    return true;
}
*/