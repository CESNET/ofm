/*****************************************************
core.h: program for communication with mem-tester comp
Copyright (C) 2021 CESNET z. s. p. o.
Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>

SPDX-License-Identifier: BSD-3-Clause
*****************************************************/

#ifndef CORE_MEM_TESTER
#define CORE_MEM_TESTER

#include "common.h"

#define DEFAULT_BURST_CNT 4

#define AMM_READY_MAX_ASKS  1000     // Max times sw will ask for amm ready
#define AMM_READY_ASK_DELAY 10000   // Amm ready ask delay [us]

#define TEST_MAX_ASKS  100      // Max times sw will ask for test result
#define TEST_ASK_DELAY 50000   // Test result ask delay [us]

#define TEST_ALL       "all"
#define TEST_SEQ       "seq"
#define TEST_RAND      "rand"
#define TEST_LAT_SEQ   "latSeq"
#define TEST_LAT_RAND  "latRand"

#define CSV_DELIM       ","

#define LAT_TEST_BURST_CNT 22
#define LAT_TEST_ADDR_CNT  10      // Addresses for each burst during latency test
#define LAT_TEST_SEED      7        // Seed for generating random data


// ---------------- //
// Common functions //
// ---------------- //

void GetDevConfig(struct DevConfig *config);
void PrintDevConfig(struct DevConfig *config);
void PrintDevConfigCSV(struct DevConfig *config);
void PrintDevStatus();
void PrintDevStatusCSV();
void PrintRegs();
bool Reset(bool emif);
int Init(char *dev, char *compatibile, long index, bool printCompCnt);
void Finish();


// ------------------- //
// AMM probe functions //
// ------------------- //

void AMMProbeLoadData(struct AMMProbeData_s *data);
void AMMProbeClearResults(struct AMMProbeResults_s *data);
void AMMProbeCalcResults(struct AMMProbeData_s *data, struct AMMProbeResults_s *res);
void AMMProbeAddResults(struct AMMProbeData_s *data, struct AMMProbeResults_s *res);
void AMMProbeAvgResults(struct AMMProbeResults_s *res, unsigned resCnt);
void AMMProbePrintResults(struct AMMProbeResults_s *data);
void AMMProbePrintResultsCSV(struct AMMProbeResults_s *data);
//void AMMProbePrintData(struct AMMProbeData_s *data);
void AMMProbePrintDataCSV(struct AMMProbeData_s *data);


// ----------------- //
// AMM gen functions //
// ----------------- //

void PrintManualBuff();
void FillManualBuff(long burst, char *data);
void WriteManualBuff();
void ReadManualBuff();
void AMMGenSetAddr(long addr);
void AMMGenSetBurst(long burst);

// ---------------------- //
// Test related functions //
// ---------------------- //

void PrintTestResult();
bool RunTest_intern(bool onlyCSV);
void SetRandomAMMData(uint32_t burstCnt);
unsigned CmpRandomAMMData(uint32_t burstCnt);
bool RunLatTest_intern(bool rand);
bool RunTest(struct TestParams_s *testParams);


#endif